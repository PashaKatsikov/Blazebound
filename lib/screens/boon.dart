import 'package:flutter/material.dart';

import '../art.dart';
import '../game/defs.dart';
import '../look.dart';
import '../sfx.dart';

class BoonScreen extends StatelessWidget {
  const BoonScreen({
    super.key,
    required this.choices,
    required this.ember,
    required this.chest,
  });

  final List<Boon> choices;
  final int ember;
  final bool chest;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgTent,
        dim: 0.5,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                Text('CHOOSE YOUR POWER', style: titleStyle(22, color: Dye.goldHi, space: 0.8)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Arena purse  ', style: bodyStyle(13)),
                    EmberChip(amount: ember, compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      SliceView(slice: Slices.chest, width: 150),
                      const SizedBox(width: 8),
                      ...choices.map((b) {
                        final info = infoOf(b);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: GoldFrame(
                              child: Column(
                                children: [
                                  Text(info.rare ? 'RARE' : 'BOON', style: titleStyle(11, color: info.rare ? Dye.ember : Dye.gold, space: 0.8)),
                                  Expanded(child: SliceView(slice: _art(b))),
                                  Text(info.title, style: titleStyle(14, space: 0.8)),
                                  const SizedBox(height: 4),
                                  Text(info.blurb, textAlign: TextAlign.center, style: bodyStyle(12)),
                                  const SizedBox(height: 8),
                                  CircusBtn(
                                    label: 'TAKE',
                                    accent: true,
                                    height: 42,
                                    onTap: () {
                                      Sfx.I.pick();
                                      Navigator.of(context).pop(b);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Slice _art(Boon b) {
    return switch (b) {
      Boon.hotCoin || Boon.heavyReturn => Slices.flame,
      Boon.twinCoin => Slices.ember,
      Boon.longBurn || Boon.wildCircus => Slices.ring,
      Boon.fastRecall => Slices.altar,
      Boon.piercingReturn => Slices.piercer,
      Boon.emberChain => Slices.chain,
    };
  }
}
