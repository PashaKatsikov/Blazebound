import 'package:flutter/material.dart';

import '../../art.dart';
import '../../look.dart';
import '../config/relay_config.dart';
import '../wire/alert_channel.dart';
import '../wire/beacon_keystore.dart';
import 'portal_stage.dart';

/// One-shot push opt-in promo shown before the portal (only when
/// `keystore.shouldInvitePermission` is true — first time, or after
/// the snooze window expired).
///
/// Styled to match the Blazebound circus/fire aesthetic. Both Accept
/// and Skip render as real buttons (see gray_part_pitfalls.md §12).
class PermissionStage extends StatefulWidget {
  const PermissionStage({
    super.key,
    required this.keystore,
    required this.alerts,
    required this.destinationUrl,
  });

  final BeaconKeystore keystore;
  final AlertChannel alerts;
  final String destinationUrl;

  @override
  State<PermissionStage> createState() => _PermissionStageState();
}

class _PermissionStageState extends State<PermissionStage> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bool granted = await widget.alerts.askPermission();
    if (!granted) {
      await widget.keystore.writePermissionSnoozeUntil(_snoozeTarget());
    }
    if (mounted) _forward();
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.keystore.writePermissionSnoozeUntil(_snoozeTarget());
    if (mounted) _forward();
  }

  int _snoozeTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      RelayConfig.permissionSnoozeSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PortalStage(
          url: widget.destinationUrl,
          keystore: widget.keystore,
          alerts: widget.alerts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double panelW =
        landscape ? size.width * 0.66 : size.width * 0.88;

    return Scaffold(
      backgroundColor: Dye.abyss,
      body: ArenaBackdrop(
        asset: landscape ? Paths.loadH : Paths.loadV,
        dim: 0.6,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const SparkleField(),
            Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: panelW.clamp(280, 600)),
                  child: GoldFrame(
                    radius: 18,
                    pad: EdgeInsets.symmetric(
                      horizontal: landscape ? 28 : 22,
                      vertical: landscape ? 22 : 26,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.notifications_active_rounded,
                            color: Dye.gold, size: 44),
                        const SizedBox(height: 14),
                        Text(
                          'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS',
                          textAlign: TextAlign.center,
                          style: titleStyle(landscape ? 18 : 20, space: 0.4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Stay tuned for special offers and rewards',
                          textAlign: TextAlign.center,
                          style: bodyStyle(14, color: Dye.cream),
                        ),
                        SizedBox(height: landscape ? 20 : 26),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: CircusBtn(
                                label: 'ALLOW',
                                accent: true,
                                height: 50,
                                onTap: _busy ? null : _accept,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: CircusBtn(
                                label: 'SKIP',
                                accent: false,
                                height: 50,
                                onTap: _busy ? null : _skip,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }
}
