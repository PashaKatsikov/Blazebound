import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';
import '../profile.dart';
import '../midway/brief/policy_links.dart';
import 'howto.dart';
import 'web_doc.dart';

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = Vault.of(context);
    return Scaffold(
      body: ArenaBackdrop(
        asset: Paths.bgBoss,
        dim: 0.55,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const BackChip(),
                    const Spacer(),
                    Text('SETTINGS', style: titleStyle(20, space: 0.8)),
                    const Spacer(),
                    const SizedBox(width: 72),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: GoldFrame(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _tog('Sound', vault.sfxOn, (v) => vault.setFlag('sfx', v)),
                              _tog('Music', vault.musicOn, (v) => vault.setFlag('music', v)),
                              _tog('Vibration', vault.rumble, (v) => vault.setFlag('rumble', v)),
                              const Spacer(),
                              Text('Language', style: bodyStyle(12, color: Dye.gold)),
                              const SizedBox(height: 4),
                              Text('English', style: titleStyle(16, space: 1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GoldFrame(
                          child: Column(
                            children: [
                              CircusBtn(
                                label: 'HOW TO PLAY',
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HowtoScreen())),
                              ),
                              const SizedBox(height: 10),
                              CircusBtn(
                                label: 'PRIVACY POLICY',
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const WebDocScreen(
                                    title: 'PRIVACY POLICY',
                                    url: policyUrl,
                                    bleach: true,
                                  ),
                                )),
                              ),
                              const SizedBox(height: 10),
                              CircusBtn(
                                label: 'SUPPORT',
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const WebDocScreen(
                                    title: 'SUPPORT',
                                    url: helpUrl,
                                  ),
                                )),
                              ),
                              const Spacer(),
                              Text('Blazebound 1.0.0', style: bodyStyle(11, color: Dye.cream.withValues(alpha: 0.6))),
                            ],
                          ),
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

  Widget _tog(String label, bool on, ValueChanged<bool> set) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: titleStyle(16, space: 0.8))),
          Switch(
            value: on,
            onChanged: set,
            activeThumbColor: Dye.goldHi,
            activeTrackColor: Dye.blood,
          ),
        ],
      ),
    );
  }
}
