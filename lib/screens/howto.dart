import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';
import '../profile.dart';

class HowtoScreen extends StatefulWidget {
  const HowtoScreen({super.key, this.first = false});

  final bool first;

  @override
  State<HowtoScreen> createState() => _HowtoScreenState();
}

class _HowtoScreenState extends State<HowtoScreen> {
  final _page = PageController();
  int _i = 0;

  static const _copy = [
    ('MOVE', 'Drag anywhere on the arena. Keep space between you and the pack — recall lines love a crowded path.'),
    ('THROW', 'Tap a foe to pin a fire coin. You only get a handful live at once. Spend them on the right bodies.'),
    ('FIRE RECALL', 'Hit RECALL when coins sit behind a line of enemies. Returning gold cuts through everyone on the way home.'),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgMain,
        dim: 0.55,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    if (!widget.first) const BackChip(),
                    const Spacer(),
                    Text('HOW TO PLAY', style: titleStyle(18, space: 0.8)),
                    const Spacer(),
                    const SizedBox(width: 72),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _page,
                    onPageChanged: (v) => setState(() => _i = v),
                    itemCount: 3,
                    itemBuilder: (_, i) {
                      final art = i == 0
                          ? Slices.joker
                          : i == 1
                              ? Slices.flame
                              : Slices.ring;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: GoldFrame(
                          child: Row(
                            children: [
                              SliceView(slice: art, width: 180),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_copy[i].$1, style: titleStyle(22, color: Dye.goldHi, space: 0.8)),
                                    const SizedBox(height: 10),
                                    Text(_copy[i].$2, style: bodyStyle(15)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Container(
                      width: i == _i ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _i ? Dye.ember : Dye.gold.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 220,
                  child: CircusBtn(
                    label: _i == 2 ? 'ENTER THE TENT' : 'NEXT',
                    accent: true,
                    onTap: () {
                      if (_i < 2) {
                        _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                      } else {
                        Vault.read(context).setFlag('tut', true);
                        Navigator.of(context).pop();
                      }
                    },
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
