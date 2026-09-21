import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';
import '../profile.dart';
import 'kit.dart';

class StashScreen extends StatelessWidget {
  const StashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = Vault.of(context);
    return Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgFire,
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
                    Text('COIN COLLECTION', style: titleStyle(18, space: 0.7)),
                    const Spacer(),
                    CircusBtn(
                      label: 'EQUIP',
                      wide: false,
                      height: 40,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KitScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: CoinKind.values.map((k) {
                      final open = vault.owned(k);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GoldFrame(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Opacity(
                                    opacity: open ? 1 : 0.28,
                                    child: SliceView(slice: k.slice),
                                  ),
                                ),
                                Text(k.title, style: titleStyle(13, color: open ? Dye.goldHi : Dye.cream)),
                                const SizedBox(height: 4),
                                Text(
                                  open ? k.blurb : _lockText(k),
                                  textAlign: TextAlign.center,
                                  style: bodyStyle(11, color: Dye.cream.withValues(alpha: 0.75)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  open ? (vault.kit == k ? 'EQUIPPED' : 'OWNED') : 'LOCKED',
                                  style: titleStyle(11, color: open ? Dye.ember : Dye.blood, space: 1),
                                ),
                              ],
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

  String _lockText(CoinKind k) {
    return switch (k) {
      CoinKind.flame => k.blurb,
      CoinKind.piercer => 'Finish any run to mint this coin.',
      CoinKind.burst => 'Topple the Ringmaster once.',
      CoinKind.chain => 'Land a 4-hit Fire Chain, or survive 3 runs.',
    };
  }
}
