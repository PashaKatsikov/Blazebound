import 'dart:math';
import 'dart:ui';

import '../profile.dart';
import '../sfx.dart';
import 'defs.dart';

enum CoinPhase { fly, stuck, yank, done }
enum FightEnd { none, win, lose }

class Foe {
  Foe(this.kind, this.p, this.hp) : maxHp = hp, r = breeds[kind]!.r;
  final Breed kind;
  Offset p;
  Offset v = Offset.zero;
  double hp;
  final double maxHp;
  final double r;
  bool dead = false;
  double face = 1;
  double wind = 0;
  double cool = Random().nextDouble() * 0.8;
  double burn = 0;
  double burnDps = 0;
  double flash = 0;
  double zig = 0;
  double aim = 0;
  bool shieldUp = true;
  double spawnWait = 0;
}

class Shot {
  Shot(this.p, this.v, this.dmg);
  Offset p;
  Offset v;
  double dmg;
  double life = 2.4;
}

class Disk {
  Disk(this.p, this.tgt, this.kind);
  Offset p;
  Foe? tgt;
  CoinPhase phase = CoinPhase.fly;
  CoinKind kind;
  double spin = 0;
  double amp = 1;
  double orbit = Random().nextDouble() * pi * 2;
  final Set<int> cleaved = {};
  int pierceLeft = 0;
  bool popped = false;
}

class Puddle {
  Puddle(this.p, this.r, this.life);
  Offset p;
  double r;
  double life;
}

class Circus {
  Circus(this.vault, this.plan, this.actIndex) : rng = Random() {
    final act = plan.acts[actIndex];
    props = act.props;
    bg = act.bg;
    title = act.title;
    kind = act.kind;
    maxHp = 100 * vault.hpMul;
    hp = maxHp;
    maxDisks = 3 + vault.extraCoins;
    throwDmg = 20 * vault.throwMul;
    recallDmg = 30 * vault.recallMul;
    spd = 195 * vault.spdMul;
    recallCdMax = 5;
    burnSec = 3;
    pierce = vault.kit == CoinKind.piercer ? 2 : 0;
    kit = vault.kit;
    p = const Offset(640, 445);
    p = _slide(p, 18);
    hurtI = 1.8;
    _queue.addAll(act.roster);
    if (kind == FightKind.boss) {
      _queue.removeWhere((e) => e == Breed.boss);
      foes.add(Foe(Breed.boss, const Offset(640, 360), breeds[Breed.boss]!.hp * plan.hpMul));
    }
    _spill(kind == FightKind.boss ? 0 : min(kind == FightKind.regular && actIndex == 0 ? 3 : 4, _queue.length));
  }

  final Profile vault;
  final RunPlan plan;
  final int actIndex;
  final Random rng;

  late final List<RoomProp> props;
  late final String bg;
  late String title;
  late final FightKind kind;

  late Offset p;
  Offset stick = Offset.zero;
  double face = 1;
  late double hp;
  late final double maxHp;
  double hurtI = 0;
  double flash = 0;

  late double throwDmg;
  late double recallDmg;
  late double spd;
  late int maxDisks;
  late double recallCdMax;
  late double burnSec;
  late int pierce;
  late CoinKind kit;

  final List<Foe> foes = [];
  final List<Breed> _queue = [];
  final List<Disk> disks = [];
  final List<Shot> shots = [];
  final List<Puddle> puddles = [];

  final Set<Boon> boons = {};
  double recallCd = 0;
  int throws = 0;
  int chainNow = 0;
  int bestChain = 0;
  int kills = 0;
  double clock = 0;
  double banner = 1.6;
  double shake = 0;
  double bossTimer = 0;
  int bossPhase = 1;
  double spawnGate = 0.4;
  FightEnd end = FightEnd.none;
  bool paused = false;
  int emberBank = 0;
  bool fastWin = true;

  int get liveDisks {
    var n = 0;
    for (final d in disks) {
      if (d.phase != CoinPhase.done) n++;
    }
    return n;
  }

  void applyBoons(Set<Boon> fromRun) {
    boons
      ..clear()
      ..addAll(fromRun);
    throwDmg = 20 * vault.throwMul * (boons.contains(Boon.hotCoin) ? 1.2 : 1);
    recallDmg = 30 * vault.recallMul * (boons.contains(Boon.heavyReturn) ? 1.25 : 1);
    recallCdMax = 5 * (boons.contains(Boon.fastRecall) ? 0.85 : 1);
    burnSec = 3 * (boons.contains(Boon.longBurn) ? 1.3 : 1);
    pierce = (vault.kit == CoinKind.piercer ? 2 : 0) + (boons.contains(Boon.piercingReturn) ? 1 : 0);
  }

  void _spill(int n) {
    for (var i = 0; i < n && _queue.isNotEmpty; i++) {
      final b = _queue.removeAt(0);
      final t = rng.nextDouble() * pi * 2;
      var pos = edgePoint(t, inset: 36 + rng.nextDouble() * 24);
      pos = _slide(pos, breeds[b]!.r);
      if ((pos - p).distance < 70) {
        pos = edgePoint(t + pi, inset: 48);
        pos = _slide(pos, breeds[b]!.r);
      }
      final f = Foe(b, pos, breeds[b]!.hp * plan.hpMul);
      f.spawnWait = 0.12 * i;
      foes.add(f);
    }
  }

  Foe? nearest(Offset at, {double max = 9999, Foe? skip}) {
    Foe? best;
    var bestD = max * max;
    for (final e in foes) {
      if (e.dead || e.spawnWait > 0 || identical(e, skip)) continue;
      final d = (e.p - at).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = e;
      }
    }
    return best;
  }

  bool tossAt(Foe? raw) {
    if (end != FightEnd.none || liveDisks >= maxDisks) return false;
    final e = raw ?? nearest(p, max: 420);
    if (e == null) return false;
    if ((e.p - p).distance > 430) return false;
    _loose(e);
    throws++;
    if (boons.contains(Boon.twinCoin) && throws % 3 == 0) {
      final extra = nearest(p, max: 430, skip: e);
      if (extra != null && liveDisks < maxDisks) _loose(extra);
    }
    Sfx.I.throwCoin();
    return true;
  }

  void _loose(Foe e) {
    final d = Disk(p + Offset(0, -18), e, kit);
    disks.add(d);
  }

  bool pullBack() {
    if (end != FightEnd.none) return false;
    if (recallCd > 0) return false;
    final live = disks.where((d) => d.phase == CoinPhase.fly || d.phase == CoinPhase.stuck).toList();
    if (live.isEmpty) return false;
    for (final d in live) {
      d.phase = CoinPhase.yank;
      d.tgt = null;
      d.cleaved.clear();
      d.pierceLeft = 5 + pierce;
      d.popped = false;
    }
    recallCd = recallCdMax;
    chainNow = 0;
    shake = 4;
    Sfx.I.recall();
    Sfx.I.ability();
    return true;
  }

  void tapWorld(Offset w) {
    final e = nearest(w, max: 96) ?? nearest(p, max: 430);
    tossAt(e);
  }

  void tick(double dt) {
    if (paused || end != FightEnd.none) return;
    if (dt > 0.05) dt = 0.05;
    clock += dt;
    if (banner > 0) banner -= dt;
    if (recallCd > 0) recallCd -= dt;
    if (hurtI > 0) hurtI -= dt;
    if (flash > 0) flash -= dt;
    if (shake > 0) shake -= dt * 28;

    _moveSelf(dt);
    if (banner <= 0.15) {
      _foes(dt);
      _shots(dt);
      _burn(dt);
      _boss(dt);
      _puddles(dt);
      _refill(dt);
    }
    _disks(dt);
    _checkEnd();
  }

  void _moveSelf(double dt) {
    if (stick.distance > 0.08) {
      final n = stick.distance > 1 ? stick / stick.distance : stick;
      var np = p + n * spd * dt;
      np = clampRing(np, pad: 22);
      np = _slide(np, 18);
      if (n.dx.abs() > 0.12) face = n.dx > 0 ? 1 : -1;
      p = np;
    }
  }

  Offset _slide(Offset want, double rad) {
    var cur = want;
    for (final o in props) {
      if (o.spec.blockR <= 0) continue;
      final d = cur - o.p;
      final need = rad + o.spec.blockR;
      if (d.distanceSquared < need * need && d.distance > 0.001) {
        cur = o.p + d / d.distance * need;
      }
    }
    return clampRing(cur, pad: 22);
  }

  void _foes(double dt) {
    for (final e in foes) {
      if (e.dead) continue;
      if (e.spawnWait > 0) {
        e.spawnWait -= dt;
        continue;
      }
      if (e.flash > 0) e.flash -= dt;
      e.cool -= dt;
      final st = breeds[e.kind]!;
      final toP = p - e.p;
      final dist = toP.distance;
      e.aim = atan2(toP.dy, toP.dx);
      if (toP.dx.abs() > 4) e.face = toP.dx > 0 ? 1 : -1;

      var dest = p;
      if (e.kind == Breed.acrobat) {
        e.zig += dt * 3.2;
        final side = Offset(-toP.dy, toP.dx);
        final sn = side.distance == 0 ? Offset.zero : side / side.distance;
        dest = p + sn * (70 + 40 * sin(e.zig));
      } else if (e.kind == Breed.masker) {
        e.zig += dt * 2.4;
        dest = p + Offset(cos(e.zig) * 80, sin(e.zig * 1.7) * 40);
      } else if (e.kind == Breed.thrower) {
        if (dist < 200) {
          dest = e.p - toP / (dist + 0.01) * 40;
        } else {
          dest = p;
        }
        if (e.cool <= 0 && dist < 360 && dist > 90) {
          e.cool = 2.15;
          final dir = toP / (dist + 0.01);
          shots.add(Shot(e.p, dir * 210, 12 * plan.dmgMul));
        }
      }

      if (e.kind == Breed.shield) {
        e.shieldUp = true;
      }

      if (e.wind > 0) {
        e.wind -= dt;
        if (e.wind <= 0 && dist < st.reach + 16) {
          _hurt(st.touch * plan.dmgMul, e.p);
        }
        continue;
      }

      if (dist < st.reach && e.kind != Breed.thrower && e.cool <= 0) {
        e.wind = e.kind == Breed.boss ? 0.55 : 0.34;
        e.cool = e.kind == Breed.boss ? 1.05 : 0.9;
        continue;
      }

      final goal = dest - e.p;
      final gd = goal.distance;
      if (gd > 2) {
        var step = goal / gd * st.spd * dt;
        if (actIndex == 0 && kind == FightKind.regular) step *= 0.78;
        if (e.kind == Breed.boss && bossPhase >= 3) step *= 1.22;
        var np = e.p + step;
        np = clampRing(np, pad: 20);
        np = _slide(np, e.r);
        e.v = np - e.p;
        e.p = np;
      }
    }
    _separate();
  }

  void _separate() {
    for (var i = 0; i < foes.length; i++) {
      final a = foes[i];
      if (a.dead || a.spawnWait > 0) continue;
      for (var j = i + 1; j < foes.length; j++) {
        final b = foes[j];
        if (b.dead || b.spawnWait > 0) continue;
        final d = a.p - b.p;
        final need = a.r + b.r - 6;
        if (d.distanceSquared > 0.01 && d.distanceSquared < need * need) {
          final n = d / d.distance;
          final push = (need - d.distance) * 0.5;
          a.p = clampRing(a.p + n * push, pad: 20);
          b.p = clampRing(b.p - n * push, pad: 20);
        }
      }
    }
  }

  void _disks(double dt) {
    const fly = 430.0;
    const home = 540.0;
    for (final d in disks) {
      d.spin += dt * 10;
      if (d.phase == CoinPhase.fly) {
        final e = d.tgt;
        if (e == null || e.dead) {
          d.phase = CoinPhase.yank;
          continue;
        }
        final t = e.p + const Offset(0, -22) - d.p;
        final dist = t.distance;
        if (dist < 18) {
          _stick(d, e);
        } else {
          d.p += t / dist * fly * dt;
          _ampCheck(d);
        }
      } else if (d.phase == CoinPhase.stuck) {
        final e = d.tgt;
        if (e == null || e.dead) {
          d.phase = CoinPhase.yank;
          continue;
        }
        d.orbit += dt * 3.2;
        d.p = e.p + Offset(cos(d.orbit) * 22, sin(d.orbit) * 12 - 20);
      } else if (d.phase == CoinPhase.yank) {
        final t = p + const Offset(0, -16) - d.p;
        final dist = t.distance;
        if (dist < 16) {
          d.phase = CoinPhase.done;
          if (kit == CoinKind.burst && !d.popped) {
            d.popped = true;
            _burstHit(d.p, 22 * vault.specMul * d.amp);
          }
          continue;
        }
        final step = t / dist * home * dt;
        final prev = d.p;
        d.p += step;
        _ampCheck(d);
        _cleave(d, prev, d.p);
      }
    }
    disks.removeWhere((d) => d.phase == CoinPhase.done);
  }

  void _stick(Disk d, Foe e) {
    if (e.kind == Breed.shield && e.shieldUp && _front(e, d.p)) {
      _hitFoe(e, throwDmg * 0.35 * d.amp, false);
      d.phase = CoinPhase.yank;
      d.tgt = null;
      d.pierceLeft = 0;
      return;
    }
    d.phase = CoinPhase.stuck;
    d.tgt = e;
    _hitFoe(e, throwDmg * d.amp, true);
    Sfx.I.hit();
  }

  bool _front(Foe e, Offset from) {
    final incoming = from - e.p;
    final face = Offset(e.face, 0);
    if (incoming.distance == 0) return true;
    final dot = (incoming / incoming.distance).dx * face.dx;
    return dot > 0.15;
  }

  void _cleave(Disk d, Offset a, Offset b) {
    for (var i = 0; i < foes.length; i++) {
      final e = foes[i];
      if (e.dead || e.spawnWait > 0) continue;
      if (d.cleaved.contains(i)) continue;
      if (_segHit(a, b, e.p, e.r + 10)) {
        if (d.pierceLeft <= 0) continue;
        d.cleaved.add(i);
        d.pierceLeft--;
        chainNow++;
        if (chainNow > bestChain) bestChain = chainNow;
        var dmg = recallDmg * d.amp;
        if (boons.contains(Boon.emberChain) && chainNow >= 3) {
          dmg *= 1 + 0.10 * (chainNow ~/ 3);
        }
        if (e.kind == Breed.shield && e.shieldUp && _front(e, a)) {
          // coming from behind the travel line still counts as recall angle
          if (_front(e, p)) dmg *= 0.45;
        }
        _hitFoe(e, dmg, true);
        if (kit == CoinKind.chain) {
          final n = nearest(e.p, max: 130, skip: e);
          if (n != null) _hitFoe(n, dmg * 0.35 * vault.specMul, false);
        }
        Sfx.I.chain();
        if (chainNow > 4) shake = 4;
      }
    }
  }

  bool _segHit(Offset a, Offset b, Offset c, double r) {
    final ab = b - a;
    final t = ((c - a).dx * ab.dx + (c - a).dy * ab.dy) / (ab.distanceSquared + 0.0001);
    final k = t.clamp(0.0, 1.0);
    final proj = a + ab * k;
    return (proj - c).distanceSquared <= r * r;
  }

  void _ampCheck(Disk d) {
    final wild = boons.contains(Boon.wildCircus) ? 1.25 : 1;
    for (final o in props) {
      if (!o.spec.amp && o.spec.kind != PropKind.target) continue;
      final reach = o.spec.kind == PropKind.ring ? 44.0 : 32.0;
      if ((d.p - o.p).distance >= reach) continue;
      final next = 1.35 * wild;
      if (d.amp < next) {
        d.amp = next;
        Sfx.I.ring();
      }
    }
  }

  void _hitFoe(Foe e, double raw, bool burn) {
    var dmg = raw;
    if (e.kind == Breed.fireClown) dmg *= 0.62;
    e.hp -= dmg;
    e.flash = 0.08;
    if (burn) {
      e.burn = max(e.burn, burnSec);
      e.burnDps = 4 * vault.throwMul;
    }
    if (e.hp <= 0 && !e.dead) _kill(e);
  }

  void _kill(Foe e) {
    e.dead = true;
    e.hp = 0;
    kills++;
    Sfx.I.kill();
    shake = max(shake, 3);
    var pay = switch (e.kind) {
      Breed.boss => rng.nextInt(41) + 80,
      Breed.heavy || Breed.shield || Breed.bruiser => rng.nextInt(7) + 6,
      _ => rng.nextInt(5) + 3,
    };
    if (kind == FightKind.elite) pay += 2;
    emberBank += pay;
    for (final d in disks) {
      if (d.tgt == e) {
        d.tgt = null;
        d.phase = CoinPhase.yank;
      }
    }
  }

  void _burstHit(Offset at, double dmg) {
    Sfx.I.ring();
    for (final e in foes) {
      if (e.dead) continue;
      if ((e.p - at).distance < 78) _hitFoe(e, dmg, true);
    }
  }

  void _burn(double dt) {
    for (final e in foes) {
      if (e.dead || e.burn <= 0) continue;
      e.burn -= dt;
      e.hp -= e.burnDps * dt;
      if (e.hp <= 0) _kill(e);
    }
  }

  void _shots(double dt) {
    for (final s in shots) {
      s.p += s.v * dt;
      s.life -= dt;
      if ((s.p - p).distance < 20) {
        _hurt(s.dmg, s.p);
        s.life = 0;
      }
    }
    shots.removeWhere((s) => s.life <= 0 || !insideRing(s.p, pad: -20));
  }

  void _boss(double dt) {
    if (kind != FightKind.boss) return;
    Foe? b;
    for (final e in foes) {
      if (e.kind == Breed.boss) {
        b = e;
        break;
      }
    }
    if (b == null || b.dead) return;
    final ratio = b.hp / b.maxHp;
    final phase = ratio > 0.6 ? 1 : ratio > 0.3 ? 2 : 3;
    if (phase != bossPhase) {
      bossPhase = phase;
      Sfx.I.boss();
      banner = 1.2;
      title = phase == 2 ? 'THE RING TIGHTENS' : 'FINAL ACT';
    }
    bossTimer += dt;
    final gap = phase == 1 ? 7.5 : phase == 2 ? 5.6 : 4.2;
    if (bossTimer >= gap) {
      bossTimer = 0;
      if (phase >= 2) {
        puddles.add(Puddle(clampRing(p + Offset(rng.nextDouble() * 80 - 40, rng.nextDouble() * 60 - 20)), 54, 5));
        puddles.add(Puddle(edgePoint(rng.nextDouble() * pi * 2, inset: 90), 48, 5));
        Sfx.I.ring();
      }
      if (phase >= 2 && _queue.length + foes.where((e) => !e.dead && e.kind != Breed.boss).length < 4) {
        _queue.add(phase >= 3 ? Breed.thrower : Breed.fighter);
        _spill(1);
      }
      if (phase >= 3) {
        _hurt(8 * plan.dmgMul, b.p);
        shake = 4;
      }
    }
  }

  void _puddles(double dt) {
    for (final z in puddles) {
      z.life -= dt;
      if ((p - z.p).distance < z.r - 8) {
        _hurt(11 * plan.dmgMul, z.p);
      }
    }
    puddles.removeWhere((z) => z.life <= 0);
  }

  void _hurt(double dmg, Offset from) {
    if (end != FightEnd.none) return;
    if (hurtI > 0) return;
    hp -= dmg;
    hurtI = 0.72;
    flash = 0.1;
    shake = max(shake, 3);
    Sfx.I.hit();
    final push = p - from;
    if (push.distance > 1) {
      p = clampRing(p + push / push.distance * 18, pad: 22);
    }
    if (hp <= 0) {
      hp = 0;
      end = FightEnd.lose;
      Sfx.I.lose();
    }
  }

  void _refill(double dt) {
    spawnGate -= dt;
    if (spawnGate > 0) return;
    if (_queue.isEmpty) return;
    final alive = foes.where((e) => !e.dead).length;
    final cap = kind == FightKind.boss ? 5 : 7;
    if (alive < cap) {
      _spill(kind == FightKind.regular ? 2 : 1);
      spawnGate = 2.3;
    }
  }

  void _checkEnd() {
    if (end != FightEnd.none) return;
    if (kind == FightKind.boss) {
      final bossDead = foes.any((e) => e.kind == Breed.boss && e.dead);
      if (!bossDead) return;
    } else {
      final living = foes.where((e) => !e.dead).isEmpty && _queue.isEmpty;
      if (!living) return;
    }
    end = FightEnd.win;
    if (clock > 38) fastWin = false;
    Sfx.I.win();
  }

  int payout() {
    var base = switch (kind) {
      FightKind.regular => rng.nextInt(11) + 10,
      FightKind.elite => rng.nextInt(21) + 30,
      FightKind.boss => rng.nextInt(41) + 80,
    };
    var mul = 1.0;
    if (bestChain >= 3) mul += min(0.5, 0.08 * bestChain);
    if (fastWin && end == FightEnd.win) mul += 0.25;
    if (hp / maxHp > 0.7 && end == FightEnd.win) mul += 0.05;
    return (base * mul).round();
  }
}
