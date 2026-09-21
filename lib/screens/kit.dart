import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';
import '../profile.dart';

class KitScreen extends StatelessWidget {
  const KitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = Vault.of(context);
    return Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgMain,
        dim: 0.5,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const BackChip(),
                    const Spacer(),
                    Text('COIN TYPE', style: titleStyle(18, space: 0.7)),
                    const Spacer(),
                    const SizedBox(width: 72),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: CoinKind.values.map((k) {
                      final open = vault.owned(k);
                      final on = vault.kit == k;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GestureDetector(
                            onTap: open ? () => vault.equip(k) : null,
                            child: GoldFrame(
                              glow: on,
                              child: Column(
                                children: [
                                  Expanded(child: Opacity(opacity: open ? 1 : 0.25, child: SliceView(slice: k.slice))),
                                  Text(k.title, style: titleStyle(14, color: on ? Dye.goldHi : Dye.cream)),
                                  const SizedBox(height: 4),
                                  Text(k.blurb, textAlign: TextAlign.center, style: bodyStyle(11)),
                                  const SizedBox(height: 8),
                                  CircusBtn(
                                    label: !open ? 'LOCKED' : on ? 'SELECTED' : 'SELECT',
                                    accent: on,
                                    height: 42,
                  onTap: open ? () => vault.equip(k) : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
