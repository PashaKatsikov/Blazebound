import 'package:flutter/material.dart';

import '../../art.dart';
import '../../look.dart';

/// Shown whenever the relay pipeline concludes "no network".
///
/// Retry rebuilds the caller-supplied route through `pushReplacement`.
/// The pipeline is idempotent by design — the coordinator's in-flight
/// cache clears on completion, so Retry runs the full boot flow fresh
/// (attribution -> probe -> verdict).
///
/// Styled to match the Blazebound circus/fire aesthetic (no external
/// webp background art required — see .cursor rules: custom screens).
class OfflineStage extends StatefulWidget {
  const OfflineStage({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<OfflineStage> createState() => _OfflineStageState();
}

class _OfflineStageState extends State<OfflineStage> {
  bool _spinning = false;

  Future<void> _retry() async {
    if (_spinning) return;
    setState(() => _spinning = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double panelW =
        landscape ? size.width * 0.62 : size.width * 0.86;

    return Scaffold(
      backgroundColor: Dye.abyss,
      body: ArenaBackdrop(
        asset: landscape ? Paths.loadH : Paths.loadV,
        dim: 0.62,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const SparkleField(),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: panelW.clamp(260, 560)),
                  child: GoldFrame(
                    radius: 18,
                    pad: EdgeInsets.symmetric(
                      horizontal: landscape ? 26 : 22,
                      vertical: landscape ? 22 : 26,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.wifi_off_rounded,
                            color: Dye.ember, size: 44),
                        const SizedBox(height: 14),
                        Text(
                          'NO INTERNET CONNECTION',
                          textAlign: TextAlign.center,
                          style: titleStyle(landscape ? 20 : 22, space: 0.6),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Check your connection and try again',
                          textAlign: TextAlign.center,
                          style: bodyStyle(14, color: Dye.cream),
                        ),
                        SizedBox(height: landscape ? 20 : 24),
                        SizedBox(
                          width: landscape ? panelW * 0.42 : panelW * 0.6,
                          child: _spinning
                              ? const Center(
                                  child: SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Dye.ember),
                                    ),
                                  ),
                                )
                              : CircusBtn(
                                  label: 'RETRY',
                                  accent: true,
                                  icon: const Icon(Icons.refresh_rounded,
                                      color: Dye.goldHi, size: 20),
                                  onTap: _retry,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
