import 'dart:math';

import 'package:blazebound/art.dart';
import 'package:blazebound/game/defs.dart';
import 'package:blazebound/game/sim.dart';
import 'package:blazebound/profile.dart';
import 'package:blazebound/sfx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    Sfx.I.live = false;
    Sfx.I.shake = false;
  });

  Profile vault() => Profile();

  test('normal run has 4 acts and ends on the boss', () {
    final plan = buildRun(Heat.normal, Random(1));
    expect(plan.acts.length, 4);
    expect(plan.acts.last.kind, FightKind.boss);
    expect(plan.acts.where((a) => a.kind == FightKind.elite).length, 1);
  });

  test('hard and nightmare add extra rings', () {
    expect(buildRun(Heat.hard, Random(2)).acts.length, 5);
    expect(buildRun(Heat.nightmare, Random(3)).acts.length, 5);
    expect(buildRun(Heat.nightmare, Random(3)).acts.where((a) => a.kind == FightKind.elite).length, 2);
  });

  test('boss phase change does not throw', () {
    final plan = RunPlan(Heat.normal, [
      Act(
        kind: FightKind.boss,
        bg: Paths.bgBoss,
        title: 'INFERNO RINGMASTER',
        roster: const [Breed.boss],
        props: const [],
      ),
    ]);
    final ring = Circus(vault(), plan, 0);
    ring.banner = 0;
    final boss = ring.foes.firstWhere((e) => e.kind == Breed.boss);
    expect(ring.bossPhase, 1);
    boss.hp = boss.maxHp * 0.5;
    expect(() => ring.tick(0.016), returnsNormally);
    expect(ring.bossPhase, 2);
    expect(ring.title, isNot(equals('INFERNO RINGMASTER')));
    ring.banner = 0;
    boss.hp = boss.maxHp * 0.2;
    expect(() => ring.tick(0.016), returnsNormally);
    expect(ring.bossPhase, 3);
  });

  test('throw pins a coin and recall yanks it back', () {
    final plan = buildRun(Heat.normal, Random(4));
    final ring = Circus(vault(), plan, 0);
    expect(ring.foes.where((e) => !e.dead), isNotEmpty);
    final foe = ring.foes.firstWhere((e) => !e.dead);
    expect(ring.tossAt(foe), isTrue);
    for (var i = 0; i < 90; i++) {
      ring.tick(0.016);
    }
    expect(ring.disks.any((d) => d.phase == CoinPhase.stuck || d.phase == CoinPhase.fly), isTrue);
    expect(ring.pullBack(), isTrue);
    expect(ring.disks.any((d) => d.phase == CoinPhase.yank), isTrue);
    for (var i = 0; i < 180; i++) {
      ring.tick(0.016);
    }
    expect(ring.disks.where((d) => d.phase != CoinPhase.done), isEmpty);
  });

  test('payout stays in the design band', () {
    final plan = buildRun(Heat.normal, Random(5));
    final ring = Circus(vault(), plan, 0);
    ring.end = FightEnd.win;
    ring.bestChain = 4;
    ring.fastWin = true;
    final pay = ring.payout();
    expect(pay, greaterThanOrEqualTo(10));
    expect(pay, lessThanOrEqualTo(40));
  });

  test('killing the last regular foe wins the ring', () {
    final plan = RunPlan(Heat.normal, [
      Act(
        kind: FightKind.regular,
        bg: Paths.bgMain,
        title: 'MAIN RING',
        roster: const [Breed.fighter],
        props: const [],
      ),
    ]);
    final ring = Circus(vault(), plan, 0);
    expect(ring.foes.length, 1);
    ring.foes.first.hp = 1;
    ring.tossAt(ring.foes.first);
    for (var i = 0; i < 200; i++) {
      ring.tick(0.016);
      if (ring.end != FightEnd.none) break;
    }
    expect(ring.end, FightEnd.win);
  });

  test('player death ends the fight', () {
    final plan = buildRun(Heat.normal, Random(8));
    final ring = Circus(vault(), plan, 0);
    ring.hp = 1;
    ring.banner = 0;
    ring.hurtI = 0;
    final foe = ring.foes.first;
    foe.p = ring.p;
    foe.spawnWait = 0;
    for (var i = 0; i < 200; i++) {
      ring.tick(0.016);
      if (ring.end == FightEnd.lose) break;
    }
    expect(ring.end, FightEnd.lose);
  });

  test('boon roll always offers three distinct picks', () {
    final picks = rollBoons(Random(9), {});
    expect(picks.length, 3);
    expect(picks.toSet().length, 3);
  });

  test('opening banner keeps the first ring from instantly killing a standing player', () {
    final plan = buildRun(Heat.normal, Random(21));
    final ring = Circus(vault(), plan, 0);
    for (var i = 0; i < 200; i++) {
      ring.tick(0.016);
    }
    expect(ring.end, FightEnd.none);
    expect(ring.hp, greaterThan(40));
  });

  test('player spawn is not sitting inside a blocking prop', () {
    final plan = buildRun(Heat.normal, Random(11));
    for (var i = 0; i < plan.acts.length; i++) {
      final ring = Circus(vault(), plan, i);
      for (final o in ring.props) {
        if (o.spec.blockR <= 0) continue;
        expect((ring.p - o.p).distance, greaterThan(o.spec.blockR + 10));
      }
    }
  });
}
