import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../art.dart';
import '../game/defs.dart';
import '../game/paint.dart';
import '../game/sim.dart';
import '../look.dart';
import '../profile.dart';
import '../sfx.dart';
import 'boon.dart';
import 'lose.dart';
import 'menu.dart';
import 'win.dart';

class FightScreen extends StatefulWidget {
  const FightScreen({super.key, required this.heat});

  final Heat heat;

  @override
  State<FightScreen> createState() => _FightScreenState();
}

class _FightScreenState extends State<FightScreen> with SingleTickerProviderStateMixin {
  late final Ticker _tick;
  late RunPlan _plan;
  late Circus _ring;
  late Profile _vault;
  final _boons = <Boon>{};
  int _act = 0;
  int _purse = 0;
  int _best = 0;
  Duration _last = Duration.zero;
  Size _view = Size.zero;
  int? _pid;
  Offset? _origin;
  Offset? _now;
  bool _busy = false;
  bool _pause = false;
  final _board = ValueNotifier<int>(0);
  final _hudN = ValueNotifier<int>(0);
  double _hudAcc = 0;

  bool _blocked(Offset p) {
    final s = _view;
    if (s == Size.zero) return false;
    if (p.dy < 70) return true;
    if (p.dx > s.width - 210 && p.dy > s.height - 130) return true;
    if (p.dx < 180 && p.dy > s.height - 86) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _vault = Vault.read(context);
    _plan = buildRun(widget.heat, Random());
    _bootAct();
    _tick = createTicker(_step)..start();
  }

  @override
  void dispose() {
    _tick.dispose();
    _board.dispose();
    _hudN.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _bootAct() {
    _ring = Circus(_vault, _plan, _act)..applyBoons(_boons);
    if (_ring.kind == FightKind.boss) Sfx.I.boss();
    _last = Duration.zero;
  }

  void _step(Duration elapsed) {
    if (!_tick.isActive) return;
    var dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 0.05) dt = 0.05;
    _ring.paused = _pause || _busy;
    _ring.tick(dt);
    if (_ring.end != FightEnd.none && !_busy) {
      _wrap();
      return;
    }
    if (!mounted) return;
    if (!_pause) _board.value++;
    _hudAcc += dt;
    if (_hudAcc >= 0.12) {
      _hudAcc = 0;
      _hudN.value++;
    }
  }

  Future<void> _wrap() async {
    if (_busy) return;
    _busy = true;
    _ring.paused = true;
    _tick.stop();
    final pay = _ring.payout();
    _purse += pay;
    if (_ring.bestChain > _best) _best = _ring.bestChain;
    _vault.addEmber(pay);

    if (_ring.end == FightEnd.lose) {
      _vault.noteRun(won: false, chain: _best);
      if (!mounted) return;
      await Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => LoseScreen(
          ember: pay,
          onRetry: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => FightScreen(heat: widget.heat),
            ));
          },
          onMenu: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MenuScreen()),
              (r) => false,
            );
          },
        ),
      ));
      return;
    }

    final last = _act >= _plan.acts.length - 1;
    if (last) {
      _vault.noteRun(won: true, chain: _best);
      if (!mounted) return;
      await Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, _, _) => WinScreen(
          ember: _purse,
          chain: _best,
          onContinue: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MenuScreen()),
              (r) => false,
            );
          },
        ),
      ));
      return;
    }

    Sfx.I.chest();
    Sfx.I.portal();
    if (!mounted) return;
    final pick = await Navigator.of(context).push<Boon>(MaterialPageRoute(
      builder: (_) => BoonScreen(choices: rollBoons(Random(), _boons), ember: pay, chest: true),
    ));
    if (pick != null) _boons.add(pick);
    if (!mounted) return;
    _act++;
    _bootAct();
    _busy = false;
    _pause = false;
    _last = Duration.zero;
    _tick.start();
  }

  void _onDown(PointerDownEvent e) {
    if (_pause || _busy) return;
    if (_blocked(e.localPosition)) return;
    _pid = e.pointer;
    _origin = e.localPosition;
    _now = e.localPosition;
    _board.value++;
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pid) return;
    _now = e.localPosition;
    final d = _now! - _origin!;
    if (d.distance > 14) {
      _ring.stick = Offset(d.dx / 80, d.dy / 80);
    }
  }

  void _onUp(PointerEvent e) {
    if (e.pointer != _pid) return;
    final d = (_now ?? e.localPosition) - (_origin ?? e.localPosition);
    if (d.distance < 14 && _view != Size.zero) {
      final cam = Cam.cover(_view);
      _ring.tapWorld(cam.toWorld(e.localPosition));
    }
    _ring.stick = Offset.zero;
    _pid = null;
    _origin = null;
    _now = null;
    _board.value++;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        setState(() => _pause = !_pause);
      },
      child: Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          _view = Size(box.maxWidth, box.maxHeight);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onUp,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: _board,
                  builder: (_, t, _) => CustomPaint(
                    painter: RingPainter(_ring, t.toDouble(), padA: _origin, padB: _now),
                    isComplex: true,
                    willChange: true,
                    child: const SizedBox.expand(),
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _hudN,
                  builder: (_, _, _) => _hud(),
                ),
                if (_pause) _pauseLayer(),
              ],
            ),
          );
        },
      ),
    ),
    );
  }

  Widget _hud() {
    final pad = MediaQuery.of(context).padding;
    return IgnorePointer(
      ignoring: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10 + pad.left, 8 + pad.top, 10 + pad.right, 8 + pad.bottom),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: GoldFrame(
                radius: 12,
                glow: false,
                pad: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliceView(slice: Slices.joker, height: 34),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('JOKER', style: titleStyle(10, space: 1)),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (_ring.hp / _ring.maxHp).clamp(0, 1),
                              minHeight: 8,
                              backgroundColor: const Color(0xFF2A0A10),
                              color: Color.lerp(Dye.blood, const Color(0xFF3DDC7A), _ring.hp / _ring.maxHp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: GoldFrame(
                radius: 12,
                glow: false,
                pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_ring.title, style: titleStyle(13, space: 0.6)),
                    Text('${_act + 1}/${_plan.acts.length}  ·  ${_plan.label}', style: bodyStyle(10, color: Dye.gold)),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmberChip(amount: _vault.ember, compact: true),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Sfx.I.menuOpen();
                      setState(() => _pause = true);
                    },
                    child: GoldFrame(
                      radius: 12,
                      glow: false,
                      pad: const EdgeInsets.all(8),
                      child: const Icon(Icons.pause, color: Dye.goldHi, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: GoldFrame(
                radius: 12,
                glow: false,
                pad: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_ring.maxDisks, (i) {
                    final on = i < _ring.liveDisks;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: on ? 1 : 0.28,
                        child: SliceView(slice: _vault.kit.slice, height: 22),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _roundBtn(
                    label: 'THROW',
                    ready: _ring.liveDisks < _ring.maxDisks,
                    fill: 1,
                    onTap: () => _ring.tossAt(null),
                  ),
                  const SizedBox(width: 10),
                  _roundBtn(
                    label: 'RECALL',
                    ready: _ring.recallCd <= 0 && _ring.liveDisks > 0,
                    fill: _ring.recallCd <= 0 ? 1 : 1 - (_ring.recallCd / _ring.recallCdMax).clamp(0, 1),
                    onTap: () => _ring.pullBack(),
                    big: true,
                  ),
                ],
              ),
            ),
            if (_ring.chainNow >= 2)
              Align(
                alignment: const Alignment(0, -0.62),
                child: Text('FIRE CHAIN x${_ring.chainNow}', style: titleStyle(16, color: Dye.ember, space: 0.8)),
              ),
            if (_ring.banner > 0) _banner(),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn({
    required String label,
    required bool ready,
    required double fill,
    required VoidCallback onTap,
    bool big = false,
  }) {
    final s = big ? 86.0 : 68.0;
    return GestureDetector(
      onTap: ready ? onTap : null,
      child: SizedBox(
        width: s,
        height: s,
        child: GoldFrame(
          radius: s / 2,
          glow: false,
          pad: const EdgeInsets.all(6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: fill,
                strokeWidth: 4,
                color: ready ? Dye.ember : Dye.goldLo,
                backgroundColor: const Color(0xFF2A0A10),
              ),
              Text(label, textAlign: TextAlign.center, style: titleStyle(big ? 11 : 9, space: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner() {
    final elite = _ring.kind == FightKind.elite;
    final boss = _ring.kind == FightKind.boss;
    if (!elite && !boss && _ring.banner < 0.8) return const SizedBox.shrink();
    final text = boss
        ? (_ring.bossPhase > 1 ? _ring.title : 'INFERNO RINGMASTER')
        : elite
            ? 'ELITE BATTLE'
            : _ring.title;
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: _ring.banner.clamp(0, 1),
          child: GoldFrame(
            pad: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Text(text, style: titleStyle(22, color: Dye.goldHi, space: 0.8)),
          ),
        ),
      ),
    );
  }

  Widget _pauseLayer() {
    return Positioned.fill(
      child: ColoredBox(
      color: Colors.black54,
      child: Center(
        child: SizedBox(
          width: 360,
          child: GoldFrame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PAUSED', style: titleStyle(22, space: 0.8)),
                const SizedBox(height: 12),
                CircusBtn(
                  label: 'RESUME',
                  accent: true,
                  onTap: () {
                    Sfx.I.menuClose();
                    setState(() => _pause = false);
                  },
                ),
                const SizedBox(height: 8),
                CircusBtn(
                  label: 'MAIN MENU',
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MenuScreen()),
                      (r) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
