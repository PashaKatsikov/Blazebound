import 'dart:math';
import 'dart:ui';

import '../art.dart';
import '../profile.dart';

enum Breed {
  fighter,
  bruiser,
  acrobat,
  masker,
  fireClown,
  shield,
  thrower,
  heavy,
  boss,
}

enum PropKind { ring, barrel, torch, target, pedestal, rope, column, wood, flag, lamp, portal }

enum Boon {
  hotCoin,
  heavyReturn,
  twinCoin,
  longBurn,
  wildCircus,
  fastRecall,
  piercingReturn,
  emberChain,
}

enum FightKind { regular, elite, boss }

class BreedStat {
  const BreedStat({
    required this.hp,
    required this.spd,
    required this.touch,
    required this.reach,
    required this.r,
    required this.draw,
    required this.h,
    required this.w,
  });

  final double hp;
  final double spd;
  final double touch;
  final double reach;
  final double r;
  final Slice draw;
  final double h;
  final double w;
}

const breeds = <Breed, BreedStat>{
  Breed.fighter: BreedStat(hp: 70, spd: 84, touch: 7, reach: 34, r: 22, draw: Slices.fighter, h: 86, w: 58),
  Breed.bruiser: BreedStat(hp: 160, spd: 56, touch: 13, reach: 40, r: 28, draw: Slices.bruiser, h: 92, w: 68),
  Breed.acrobat: BreedStat(hp: 55, spd: 132, touch: 6, reach: 30, r: 18, draw: Slices.acrobat, h: 84, w: 62),
  Breed.masker: BreedStat(hp: 85, spd: 100, touch: 12, reach: 34, r: 20, draw: Slices.masker, h: 88, w: 54),
  Breed.fireClown: BreedStat(hp: 110, spd: 88, touch: 13, reach: 34, r: 20, draw: Slices.fireClown, h: 88, w: 50),
  Breed.shield: BreedStat(hp: 140, spd: 70, touch: 14, reach: 38, r: 24, draw: Slices.shield, h: 86, w: 66),
  Breed.thrower: BreedStat(hp: 75, spd: 80, touch: 8, reach: 26, r: 20, draw: Slices.thrower, h: 84, w: 52),
  Breed.heavy: BreedStat(hp: 240, spd: 46, touch: 20, reach: 42, r: 32, draw: Slices.heavy, h: 90, w: 78),
  Breed.boss: BreedStat(hp: 980, spd: 72, touch: 22, reach: 50, r: 36, draw: Slices.ringmaster, h: 132, w: 96),
};

class BoonInfo {
  const BoonInfo(this.boon, this.title, this.blurb, this.rare);
  final Boon boon;
  final String title;
  final String blurb;
  final bool rare;
}

const boonBook = <BoonInfo>[
  BoonInfo(Boon.hotCoin, 'Hot Coin', 'Fire coins hit 20% harder.', false),
  BoonInfo(Boon.heavyReturn, 'Heavy Return', 'Recall strikes deal 25% more.', false),
  BoonInfo(Boon.twinCoin, 'Twin Coin', 'Every third throw looses a second coin.', true),
  BoonInfo(Boon.longBurn, 'Long Burn', 'Burning lasts 30% longer.', false),
  BoonInfo(Boon.wildCircus, 'Wild Circus', 'Rings and pedestals empower coins 25% more.', false),
  BoonInfo(Boon.fastRecall, 'Fast Recall', 'Fire Recall cools 15% faster.', false),
  BoonInfo(Boon.piercingReturn, 'Piercing Return', 'Returning coins pierce +1 target.', true),
  BoonInfo(Boon.emberChain, 'Ember Chain', 'Every 3 chain hits raise chain damage 10%.', true),
];

class PropSpec {
  const PropSpec(this.kind, this.slice, this.w, this.h, this.blockR, {this.amp = false});
  final PropKind kind;
  final Slice slice;
  final double w;
  final double h;
  final double blockR;
  final bool amp;
}

class RoomProp {
  RoomProp(this.spec, this.p);
  final PropSpec spec;
  Offset p;
}

class Act {
  Act({
    required this.kind,
    required this.bg,
    required this.title,
    required this.roster,
    required this.props,
  });

  final FightKind kind;
  final String bg;
  final String title;
  final List<Breed> roster;
  final List<RoomProp> props;
}

class RunPlan {
  RunPlan(this.heat, this.acts);
  final Heat heat;
  final List<Act> acts;

  double get hpMul => switch (heat) {
        Heat.normal => 1,
        Heat.hard => 1.35,
        Heat.nightmare => 1.72,
      };

  double get dmgMul => switch (heat) {
        Heat.normal => 1,
        Heat.hard => 1.18,
        Heat.nightmare => 1.4,
      };

  String get label => switch (heat) {
        Heat.normal => 'NORMAL',
        Heat.hard => 'HARD',
        Heat.nightmare => 'NIGHTMARE',
      };

  String get tag => switch (heat) {
        Heat.normal => 'Face the circus.',
        Heat.hard => 'Greater rewards. Crueler rings.',
        Heat.nightmare => 'The tent forgets mercy.',
      };
}

const worldW = 1280.0;
const worldH = 720.0;
const ringC = Offset(640, 418);
const ringRx = 402.0;
const ringRy = 214.0;

bool insideRing(Offset p, {double pad = 0}) {
  final nx = (p.dx - ringC.dx) / (ringRx - pad);
  final ny = (p.dy - ringC.dy) / (ringRy - pad);
  return nx * nx + ny * ny <= 1;
}

Offset clampRing(Offset p, {double pad = 18}) {
  final nx = (p.dx - ringC.dx) / (ringRx - pad);
  final ny = (p.dy - ringC.dy) / (ringRy - pad);
  final m = nx * nx + ny * ny;
  if (m <= 1) return p;
  final s = 1 / sqrt(m);
  return Offset(ringC.dx + nx * s * (ringRx - pad), ringC.dy + ny * s * (ringRy - pad));
}

Offset edgePoint(double t, {double inset = 36}) {
  return Offset(
    ringC.dx + cos(t) * (ringRx - inset),
    ringC.dy + sin(t) * (ringRy - inset),
  );
}

RunPlan buildRun(Heat heat, Random rng) {
  List<RoomProp> dress(int mood) {
    final out = <RoomProp>[];
    void add(PropSpec s, Offset p) => out.add(RoomProp(s, p));

    const ring = PropSpec(PropKind.ring, Slices.ring, 92, 88, 0, amp: true);
    const barrel = PropSpec(PropKind.barrel, Slices.barrel, 48, 58, 22);
    const torch = PropSpec(PropKind.torch, Slices.torch, 36, 58, 0, amp: true);
    const target = PropSpec(PropKind.target, Slices.target, 58, 52, 10);
    const ped = PropSpec(PropKind.pedestal, Slices.pedestal, 70, 58, 24, amp: true);
    const rope = PropSpec(PropKind.rope, Slices.rope, 140, 48, 0);
    const colA = PropSpec(PropKind.column, Slices.col0, 36, 78, 16);
    const colB = PropSpec(PropKind.column, Slices.col2, 36, 78, 16);
    const wood = PropSpec(PropKind.wood, Slices.wood1, 54, 48, 18);
    const flagA = PropSpec(PropKind.flag, Slices.flag0, 40, 48, 0);
    const flagB = PropSpec(PropKind.flag, Slices.flag3, 42, 50, 0);
    const lamp = PropSpec(PropKind.lamp, Slices.lamp1, 34, 48, 0);
    const portal = PropSpec(PropKind.portal, Slices.portal, 96, 72, 0);

    if (mood == 0) {
      add(ring, const Offset(860, 360));
      add(barrel, const Offset(430, 470));
      add(barrel, const Offset(880, 500));
      add(torch, const Offset(360, 330));
      add(torch, const Offset(930, 300));
      add(target, const Offset(640, 300));
      add(flagA, const Offset(300, 250));
      add(flagB, const Offset(980, 250));
      add(rope, const Offset(640, 560));
    } else if (mood == 1) {
      add(ring, const Offset(430, 380));
      add(ring, const Offset(860, 400));
      add(ped, const Offset(520, 520));
      add(torch, const Offset(500, 300));
      add(torch, const Offset(780, 300));
      add(lamp, const Offset(340, 460));
      add(lamp, const Offset(960, 460));
    } else if (mood == 2) {
      add(colA, const Offset(400, 360));
      add(colB, const Offset(880, 360));
      add(wood, const Offset(640, 320));
      add(barrel, const Offset(500, 500));
      add(target, const Offset(820, 500));
      add(ring, const Offset(640, 460));
      add(flagA, const Offset(320, 280));
    } else {
      add(ped, const Offset(420, 500));
      add(ped, const Offset(860, 500));
      add(torch, const Offset(340, 340));
      add(torch, const Offset(940, 340));
      add(ring, const Offset(500, 330));
      add(portal, const Offset(640, 240));
    }
    return out;
  }

  Breed pick(List<Breed> pool) => pool[rng.nextInt(pool.length)];

  List<Breed> pack(int n, List<Breed> core, [List<Breed> extra = const []]) {
    final list = <Breed>[];
    for (var i = 0; i < n; i++) {
      final pool = (i > n * 0.55 && extra.isNotEmpty) ? extra : core;
      list.add(pick(pool));
    }
    return list;
  }

  final acts = <Act>[];
  if (heat == Heat.normal) {
    acts.add(Act(
      kind: FightKind.regular,
      bg: Paths.bgMain,
      title: 'MAIN RING',
      roster: pack(6, const [Breed.fighter, Breed.acrobat]),
      props: dress(0),
    ));
    acts.add(Act(
      kind: FightKind.regular,
      bg: Paths.bgFire,
      title: 'EMBER FLOOR',
      roster: pack(8, const [Breed.fighter, Breed.acrobat, Breed.masker], const [Breed.bruiser]),
      props: dress(1),
    ));
    acts.add(Act(
      kind: FightKind.elite,
      bg: Paths.bgTent,
      title: 'ELITE RING',
      roster: [
        Breed.shield,
        Breed.thrower,
        Breed.bruiser,
        Breed.bruiser,
        ...pack(5, const [Breed.fighter, Breed.masker, Breed.acrobat]),
      ],
      props: dress(2),
    ));
  } else if (heat == Heat.hard) {
    acts.add(Act(
      kind: FightKind.regular,
      bg: Paths.bgMain,
      title: 'MAIN RING',
      roster: pack(7, const [Breed.fighter, Breed.acrobat, Breed.masker]),
      props: dress(0),
    ));
    acts.add(Act(
      kind: FightKind.regular,
      bg: Paths.bgFire,
      title: 'EMBER FLOOR',
      roster: pack(9, const [Breed.fighter, Breed.bruiser, Breed.masker], const [Breed.fireClown]),
      props: dress(1),
    ));
    acts.add(Act(
      kind: FightKind.regular,
      bg: Paths.bgTent,
      title: 'SIDE TENT',
      roster: pack(10, const [Breed.acrobat, Breed.masker, Breed.bruiser], const [Breed.thrower, Breed.shield]),
      props: dress(2),
    ));
    acts.add(Act(
      kind: FightKind.elite,
      bg: Paths.bgFire,
      title: 'ELITE RING',
      roster: [
        Breed.shield,
        Breed.shield,
        Breed.thrower,
        Breed.heavy,
        ...pack(6, const [Breed.fireClown, Breed.bruiser, Breed.acrobat]),
      ],
      props: dress(1),
    ));
  } else {
    acts.add(Act(
      kind: FightKind.regular,
      bg: Paths.bgMain,
      title: 'MAIN RING',
      roster: pack(8, const [Breed.fighter, Breed.acrobat, Breed.masker, Breed.fireClown]),
      props: dress(0),
    ));
    acts.add(Act(
      kind: FightKind.regular,
      bg: Paths.bgFire,
      title: 'EMBER FLOOR',
      roster: pack(10, const [Breed.bruiser, Breed.fireClown, Breed.masker], const [Breed.heavy, Breed.thrower]),
      props: dress(1),
    ));
    acts.add(Act(
      kind: FightKind.elite,
      bg: Paths.bgTent,
      title: 'ELITE RING',
      roster: [
        Breed.shield,
        Breed.thrower,
        Breed.heavy,
        ...pack(8, const [Breed.fireClown, Breed.acrobat, Breed.bruiser]),
      ],
      props: dress(2),
    ));
    acts.add(Act(
      kind: FightKind.elite,
      bg: Paths.bgFire,
      title: 'SECOND TRIAL',
      roster: [
        Breed.shield,
        Breed.shield,
        Breed.thrower,
        Breed.thrower,
        Breed.heavy,
        ...pack(7, const [Breed.fireClown, Breed.masker, Breed.bruiser]),
      ],
      props: dress(1),
    ));
  }

  acts.add(Act(
    kind: FightKind.boss,
    bg: Paths.bgBoss,
    title: 'INFERNO RINGMASTER',
    roster: [Breed.boss],
    props: dress(3),
  ));
  return RunPlan(heat, acts);
}

List<Boon> rollBoons(Random rng, Set<Boon> owned) {
  final bag = <Boon>[];
  for (final b in boonBook) {
    if (owned.contains(b.boon) && rng.nextDouble() < 0.55) continue;
    final n = b.rare ? 2 : 5;
    for (var i = 0; i < n; i++) {
      bag.add(b.boon);
    }
  }
  final pick = <Boon>[];
  while (pick.length < 3 && bag.isNotEmpty) {
    final i = rng.nextInt(bag.length);
    final v = bag[i];
    bag.removeWhere((e) => e == v);
    if (pick.contains(v)) continue;
    pick.add(v);
  }
  while (pick.length < 3) {
    final leftover = Boon.values.where((e) => !pick.contains(e)).toList();
    if (leftover.isEmpty) break;
    pick.add(leftover[rng.nextInt(leftover.length)]);
  }
  return pick;
}

BoonInfo infoOf(Boon b) => boonBook.firstWhere((e) => e.boon == b);
