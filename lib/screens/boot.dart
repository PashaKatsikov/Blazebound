import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art.dart';
import '../look.dart';
import '../midway/brief/midway_brief.dart';
import '../midway/outcome/arrival.dart';
import '../midway/midway_coordinator.dart';
import '../midway/booth/offline_booth.dart';
import '../midway/booth/permission_booth.dart';
import '../midway/booth/portal_booth.dart';
import '../midway/rigging/push_channel.dart';
import '../midway/rigging/keybox.dart';
import '../midway/rigging/reach_probe.dart';
import 'menu.dart';

// ============================================================
// BOOT SCREEN — loading art + progress, then relay routing
// ============================================================
// The visual (background art, sparkles, status caption, gold progress
// frame) is unchanged from the original Blazebound loader. Only the
// progress SOURCE changed: the bar now tracks the relay decision, and,
// on the native-game branch, the game-art warmup.
//
//   • decision phase  → bar 0.04 .. 0.60  (MidwayCoordinator.decide)
//   • game-art phase  → bar 0.60 .. 1.00  (Art.I.load, game branch only)
//
// The bar never freezes at 100% before the route is actually pushed.
// ============================================================

class BootScreen extends StatefulWidget {
  const BootScreen({
    super.key,
    required this.coordinator,
    required this.keystore,
    required this.alerts,
  });

  final MidwayCoordinator coordinator;
  final KeyBox keystore;
  final PushChannel alerts;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  static const double _hold = 0.90;

  double _p = 0;
  double _ceiling = 0.08;
  bool _loader = false;
  bool _landed = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _armTick() {
    _tick ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || _p >= _ceiling) return;
      setState(() {
        final double step = math.max(0.004, (_ceiling - _p) * 0.08);
        _p = math.min(_ceiling, _p + step);
      });
    });
  }

  void _checkpoint(double value) {
    final double next = (value * _hold).clamp(0.08, _hold);
    if (next > _ceiling) _ceiling = next;
  }

  Future<void> _fillAndGo(Widget next) async {
    _ceiling = 1;
    while (mounted && _p < 0.995) {
      setState(() {
        _p = math.min(1, _p + math.max(0.02, (1 - _p) * 0.28));
      });
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (!mounted) return;
    setState(() => _p = 1);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    _tick?.cancel();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => next,
      transitionDuration: const Duration(milliseconds: 450),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  void _goOffline() {
    if (!mounted || _landed) return;
    _landed = true;
    _tick?.cancel();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => _offline(),
      transitionDuration: Duration.zero,
    ));
  }

  Future<void> _drive() async {
    final bool gameWithoutNet = !MidwayBrief.credentialsReady ||
        widget.keystore.route == RouteState.native;
    if (!gameWithoutNet && !await ReachProbe().canDialOut()) {
      _goOffline();
      return;
    }
    if (!mounted || _landed) return;
    setState(() => _loader = true);
    _armTick();

    final Arrival outcome = await widget.coordinator.decide(
      onProgress: _checkpoint,
    );
    if (!mounted || _landed) return;

    if (outcome is OfflineArrival) {
      _goOffline();
      return;
    }

    _landed = true;
    final Widget next = switch (outcome) {
      GameArrival() => await _buildGameLanding(),
      PortalArrival(url: final String url) => _buildPortalLanding(url),
      OfflineArrival() => _offline(),
    };
    if (!mounted) return;
    await _fillAndGo(next);
  }

  Future<Widget> _buildGameLanding() async {
    if (!Art.I.ready) {
      await Art.I.load((double v) => _checkpoint(0.55 + v * 0.45));
    } else {
      _checkpoint(1);
    }
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return const MenuScreen();
  }

  Widget _buildPortalLanding(String url) {
    _checkpoint(1);
    if (widget.keystore.shouldInvitePermission) {
      return PermissionBooth(
        keystore: widget.keystore,
        alerts: widget.alerts,
        destinationUrl: url,
      );
    }
    return PortalBooth(
      url: url,
      keystore: widget.keystore,
      alerts: widget.alerts,
    );
  }

  Widget _offline() {
    return OfflineBooth(
      onRetryBuild: (_) => BootScreen(
        coordinator: widget.coordinator,
        keystore: widget.keystore,
        alerts: widget.alerts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loader) {
      return const Scaffold(backgroundColor: Dye.abyss);
    }
    final bool tall = MediaQuery.of(context).orientation == Orientation.portrait;
    final int percent = (_p * 100).round().clamp(0, 100);
    return Scaffold(
      backgroundColor: Dye.abyss,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: Image.asset(tall ? Paths.loadV : Paths.loadH, fit: BoxFit.cover)),
          const SparkleField(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 0, 28, tall ? 48 : 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xF0140208),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Dye.gold, width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Text('$percent%', style: titleStyle(20, color: Dye.goldHi)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GoldFrame(
                    radius: 10,
                    pad: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _p.clamp(0, 1),
                        minHeight: 10,
                        backgroundColor: const Color(0xFF2A0A10),
                        color: Dye.ember,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
