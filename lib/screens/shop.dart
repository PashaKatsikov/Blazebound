import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';
import '../profile.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = Vault.of(context);
    return Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgTent,
        dim: 0.52,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const BackChip(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('PERMANENT UPGRADES', style: titleStyle(18, space: 0.7)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    EmberChip(amount: vault.ember),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      SliceView(slice: Slices.altar, width: 160),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.05,
                          ),
                          itemCount: shopLines.length,
                          itemBuilder: (_, i) => _line(context, vault, shopLines[i]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, Profile vault, StatLine line) {
    final lv = vault.lvOf(line.id);
    final maxed = lv >= line.maxLv;
    final cost = vault.price(line);
    return GoldFrame(
      pad: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(line.label, style: titleStyle(13, space: 0.6)),
                Text(line.hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(10, color: Dye.cream.withValues(alpha: 0.7))),
                const SizedBox(height: 4),
                FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: _pips(lv, line.maxLv)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: maxed
                ? null
                : () {
                    final ok = vault.buy(line);
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Need $cost Ember Coins.', style: bodyStyle(13)),
                        backgroundColor: Dye.wine,
                      ));
                    }
                  },
            child: GoldFrame(
              radius: 10,
              pad: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!maxed) SliceView(slice: Slices.ember, height: 18),
                  if (!maxed) const SizedBox(width: 4),
                  Text(maxed ? 'MAX' : '$cost', style: titleStyle(12, color: Dye.goldHi, space: 0.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pips(int lv, int max) {
    return Row(
      children: List.generate(max, (i) {
        return Container(
          width: 10,
          height: 6,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: i < lv ? Dye.ember : const Color(0xFF3A1618),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Dye.gold.withValues(alpha: 0.5), width: 0.6),
          ),
        );
      }),
    );
  }
}
