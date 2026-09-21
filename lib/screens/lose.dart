import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';

class LoseScreen extends StatelessWidget {
  const LoseScreen({
    super.key,
    required this.ember,
    required this.onRetry,
    required this.onMenu,
  });

  final int ember;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onMenu();
      },
      child: Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgFire,
        dim: 0.55,
        child: SafeArea(
          child: Center(
            child: SizedBox(
              width: 520,
              child: GoldFrame(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliceView(slice: Slices.joker, height: 110),
                    const SizedBox(height: 4),
                    Text('DEFEAT', style: titleStyle(32, color: Dye.ember, space: 0.8)),
                    const SizedBox(height: 4),
                    Text('The show goes on...', style: bodyStyle(14, color: Dye.goldHi)),
                    const SizedBox(height: 10),
                    EmberChip(amount: ember),
                    const SizedBox(height: 16),
                    CircusBtn(label: 'TRY AGAIN', accent: true, onTap: onRetry),
                    const SizedBox(height: 8),
                    CircusBtn(label: 'MAIN MENU', onTap: onMenu),
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
