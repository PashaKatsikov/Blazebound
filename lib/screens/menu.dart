import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';
import '../profile.dart';
import '../sfx.dart';
import 'howto.dart';
import 'kit.dart';
import 'options.dart';
import 'run_pick.dart';
import 'shop.dart';
import 'stash.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Vault.read(context);
      if (!p.tutorialDone) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HowtoScreen(first: true)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vault = Vault.of(context);
    return Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgTent,
        dim: 0.38,
        child: SafeArea(
          child: Stack(
            children: [
              const SparkleField(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 118,
                            child: Image.asset(
                              Paths.logo,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('FIRE. CHAOS. VICTORY.', style: titleStyle(13, color: Dye.gold, space: 1.2)),
                          const SizedBox(height: 4),
                          Text(
                            'A deadly circus awaits.',
                            style: bodyStyle(14, color: Dye.cream.withValues(alpha: 0.8)),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: SliceView(slice: Slices.joker, height: 200),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: EmberChip(amount: vault.ember, compact: true),
                          ),
                          const SizedBox(height: 8),
                          GoldFrame(
                            pad: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircusBtn(
                                  label: 'PLAY',
                                  accent: true,
                                  height: 42,
                                  icon: const Icon(Icons.local_fire_department, color: Dye.goldHi, size: 20),
                                  onTap: () {
                                    Sfx.I.menuOpen();
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RunPickScreen()));
                                  },
                                ),
                                const SizedBox(height: 6),
                                CircusBtn(
                                  label: 'COLLECTION',
                                  height: 42,
                                  icon: SliceView(slice: Slices.flame, height: 20),
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StashScreen())),
                                ),
                                const SizedBox(height: 6),
                                CircusBtn(
                                  label: 'UPGRADES',
                                  height: 42,
                                  icon: SliceView(slice: Slices.altar, height: 20),
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen())),
                                ),
                                const SizedBox(height: 6),
                                CircusBtn(
                                  label: 'SETTINGS',
                                  height: 42,
                                  icon: const Icon(Icons.tune, color: Dye.goldHi, size: 20),
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OptionsScreen())),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KitScreen())),
                                  child: Text('COIN LOADOUT', style: bodyStyle(12, color: Dye.gold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
