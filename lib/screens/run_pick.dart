import 'package:flutter/material.dart';

import '../art.dart';
import '../game/defs.dart';
import '../look.dart';
import '../profile.dart';
import '../sfx.dart';
import 'fight.dart';
import 'howto.dart';

class RunPickScreen extends StatelessWidget {
  const RunPickScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgMain,
        dim: 0.5,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const BackChip(),
                    const Spacer(),
                    Text('RUN SELECTION', style: titleStyle(20, space: 0.8)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HowtoScreen())),
                      icon: const Icon(Icons.help_outline, color: Dye.goldHi),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _card(context, Heat.normal, Slices.fighter, Dye.gold)),
                      const SizedBox(width: 12),
                      Expanded(child: _card(context, Heat.hard, Slices.bruiser, Dye.ember)),
                      const SizedBox(width: 12),
                      Expanded(child: _card(context, Heat.nightmare, Slices.ringmaster, Dye.blood)),
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

  Widget _card(BuildContext context, Heat heat, Slice art, Color tint) {
    final dummy = RunPlan(heat, const []);
    return GoldFrame(
      fill: Dye.panelSolid,
      child: Column(
        children: [
          Text(dummy.label, style: titleStyle(18, color: tint, space: 0.8)),
          const SizedBox(height: 6),
          Expanded(child: SliceView(slice: art)),
          const SizedBox(height: 8),
          Text(dummy.tag, textAlign: TextAlign.center, style: bodyStyle(12, color: Dye.cream.withValues(alpha: 0.85))),
          const SizedBox(height: 10),
          CircusBtn(
            label: 'ENTER',
            accent: heat != Heat.normal,
            onTap: () {
              Sfx.I.confirm();
              Sfx.I.start();
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => FightScreen(heat: heat),
              ));
            },
          ),
        ],
      ),
    );
  }
}
