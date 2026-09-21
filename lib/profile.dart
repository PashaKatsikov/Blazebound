import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'art.dart';
import 'sfx.dart';

enum Heat { normal, hard, nightmare }

enum CoinKind { flame, piercer, burst, chain }

extension CoinLook on CoinKind {
  Slice get slice => switch (this) {
        CoinKind.flame => Slices.flame,
        CoinKind.piercer => Slices.piercer,
        CoinKind.burst => Slices.burst,
        CoinKind.chain => Slices.chain,
      };

  String get title => switch (this) {
        CoinKind.flame => 'Flame Coin',
        CoinKind.piercer => 'Piercer Coin',
        CoinKind.burst => 'Burst Coin',
        CoinKind.chain => 'Chain Coin',
      };

  String get blurb => switch (this) {
        CoinKind.flame => 'A balanced fire coin. Reliable throw, honest recall.',
        CoinKind.piercer => 'Returning coins punch through one extra body.',
        CoinKind.burst => 'After a recall, each coin pops a short fire pulse.',
        CoinKind.chain => 'Hits can splash a cut of damage onto a neighbour.',
      };
}

class StatLine {
  const StatLine({
    required this.id,
    required this.label,
    required this.hint,
    required this.cost0,
    required this.maxLv,
  });

  final String id;
  final String label;
  final String hint;
  final int cost0;
  final int maxLv;
}

const shopLines = <StatLine>[
  StatLine(id: 'dmg', label: 'Coin Damage', hint: '+8% throw damage / rank', cost0: 200, maxLv: 10),
  StatLine(id: 'coins', label: 'Max Coins', hint: '+1 active coin / rank', cost0: 150, maxLv: 3),
  StatLine(id: 'hp', label: 'Health', hint: '+10% max health / rank', cost0: 200, maxLv: 10),
  StatLine(id: 'spd', label: 'Move Speed', hint: '+4% movement / rank', cost0: 100, maxLv: 8),
  StatLine(id: 'recall', label: 'Recall Force', hint: '+8% Fire Recall damage / rank', cost0: 180, maxLv: 10),
  StatLine(id: 'spec', label: 'Special Coins', hint: '+6% special coin effect / rank', cost0: 220, maxLv: 8),
];

class Profile extends ChangeNotifier {
  int ember = 0;
  int lvDmg = 0;
  int lvCoins = 0;
  int lvHp = 0;
  int lvSpd = 0;
  int lvRecall = 0;
  int lvSpec = 0;
  CoinKind kit = CoinKind.flame;
  bool sfxOn = true;
  bool musicOn = true;
  bool rumble = true;
  bool tutorialDone = false;
  int runs = 0;
  int bosses = 0;
  int bestChain = 0;
  final Set<CoinKind> unlocked = {CoinKind.flame};

  double get throwMul => 1 + lvDmg * 0.08;
  int get extraCoins => lvCoins;
  double get hpMul => 1 + lvHp * 0.10;
  double get spdMul => 1 + lvSpd * 0.04;
  double get recallMul => 1 + lvRecall * 0.08;
  double get specMul => 1 + lvSpec * 0.06;

  int lvOf(String id) => switch (id) {
        'dmg' => lvDmg,
        'coins' => lvCoins,
        'hp' => lvHp,
        'spd' => lvSpd,
        'recall' => lvRecall,
        'spec' => lvSpec,
        _ => 0,
      };

  int price(StatLine line) => (line.cost0 * (1 + lvOf(line.id) * 0.65)).round();

  bool get canUnlockPiercer => runs >= 1;
  bool get canUnlockBurst => bosses >= 1;
  bool get canUnlockChain => bestChain >= 4 || runs >= 3;

  bool owned(CoinKind k) => unlocked.contains(k);

  SharedPreferences? _p;

  Future<void> boot() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
    ember = p.getInt('ember') ?? 40;
    lvDmg = p.getInt('lvDmg') ?? 0;
    lvCoins = p.getInt('lvCoins') ?? 0;
    lvHp = p.getInt('lvHp') ?? 0;
    lvSpd = p.getInt('lvSpd') ?? 0;
    lvRecall = p.getInt('lvRecall') ?? 0;
    lvSpec = p.getInt('lvSpec') ?? 0;
    kit = CoinKind.values[((p.getInt('kit') ?? 0).clamp(0, CoinKind.values.length - 1))];
    sfxOn = p.getBool('sfx') ?? true;
    musicOn = p.getBool('music') ?? true;
    rumble = p.getBool('rumble') ?? true;
    tutorialDone = p.getBool('tut') ?? false;
    runs = p.getInt('runs') ?? 0;
    bosses = p.getInt('bosses') ?? 0;
    bestChain = p.getInt('chain') ?? 0;
    final raw = p.getStringList('unlock') ?? ['flame'];
    unlocked
      ..clear()
      ..addAll(raw.map((s) => CoinKind.values.firstWhere((k) => k.name == s, orElse: () => CoinKind.flame)));
    if (!unlocked.contains(CoinKind.flame)) unlocked.add(CoinKind.flame);
    if (!unlocked.contains(kit)) kit = CoinKind.flame;
    Sfx.I.live = sfxOn;
    Sfx.I.shake = rumble;
    notifyListeners();
  }

  Future<void> flush() async {
    final p = _p;
    if (p == null) return;
    await p.setInt('ember', ember);
    await p.setInt('lvDmg', lvDmg);
    await p.setInt('lvCoins', lvCoins);
    await p.setInt('lvHp', lvHp);
    await p.setInt('lvSpd', lvSpd);
    await p.setInt('lvRecall', lvRecall);
    await p.setInt('lvSpec', lvSpec);
    await p.setInt('kit', kit.index);
    await p.setBool('sfx', sfxOn);
    await p.setBool('music', musicOn);
    await p.setBool('rumble', rumble);
    await p.setBool('tut', tutorialDone);
    await p.setInt('runs', runs);
    await p.setInt('bosses', bosses);
    await p.setInt('chain', bestChain);
    await p.setStringList('unlock', unlocked.map((e) => e.name).toList());
  }

  void _touch() {
    notifyListeners();
    flush();
  }

  bool buy(StatLine line) {
    final lv = lvOf(line.id);
    if (lv >= line.maxLv) return false;
    final c = price(line);
    if (ember < c) return false;
    ember -= c;
    switch (line.id) {
      case 'dmg':
        lvDmg++;
      case 'coins':
        lvCoins++;
      case 'hp':
        lvHp++;
      case 'spd':
        lvSpd++;
      case 'recall':
        lvRecall++;
      case 'spec':
        lvSpec++;
    }
    Sfx.I.pick();
    _touch();
    return true;
  }

  void addEmber(int n) {
    if (n <= 0) return;
    ember += n;
    _touch();
  }

  void equip(CoinKind k) {
    if (!owned(k)) return;
    kit = k;
    Sfx.I.confirm();
    _touch();
  }

  void tryUnlocks() {
    var dirty = false;
    if (canUnlockPiercer && unlocked.add(CoinKind.piercer)) dirty = true;
    if (canUnlockBurst && unlocked.add(CoinKind.burst)) dirty = true;
    if (canUnlockChain && unlocked.add(CoinKind.chain)) dirty = true;
    if (dirty) _touch();
  }

  void noteRun({required bool won, required int chain}) {
    runs++;
    if (won) bosses++;
    if (chain > bestChain) bestChain = chain;
    tryUnlocks();
    _touch();
  }

  void setFlag(String k, bool v) {
    switch (k) {
      case 'sfx':
        sfxOn = v;
      case 'music':
        musicOn = v;
      case 'rumble':
        rumble = v;
      case 'tut':
        tutorialDone = v;
    }
    Sfx.I.live = sfxOn;
    Sfx.I.shake = rumble;
    _touch();
  }
}

class Vault extends InheritedNotifier<Profile> {
  const Vault({super.key, required Profile profile, required super.child})
      : super(notifier: profile);

  static Profile of(BuildContext context) {
    final v = context.dependOnInheritedWidgetOfExactType<Vault>();
    assert(v != null, 'Vault missing');
    return v!.notifier!;
  }

  static Profile read(BuildContext context) {
    final v = context.getInheritedWidgetOfExactType<Vault>();
    return v!.notifier!;
  }
}
