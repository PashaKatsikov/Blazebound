import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';
import '../sfx.dart';

class WinScreen extends StatelessWidget {
  const WinScreen({
    super.key,
    required this.ember,
    required this.chain,
    required this.onContinue,
  });

  final int ember;
  final int chain;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onContinue();
      },
      child: Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgBoss,
        dim: 0.48,
        child: SafeArea(
          child: Center(
            child: SizedBox(
              width: 520,
              child: GoldFrame(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliceView(slice: Slices.chest, height: 90),
                    const SizedBox(height: 6),
                    Text('VICTORY!', style: titleStyle(34, color: Dye.goldHi, space: 1.0)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        EmberChip(amount: ember),
                        const SizedBox(width: 12),
                        GoldFrame(
                          radius: 16,
                          pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text('x$chain chain', style: titleStyle(14, space: 0.6)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CircusBtn(
                      label: 'CONTINUE',
                      accent: true,
                      onTap: () {
                        Sfx.I.reward();
                        onContinue();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
