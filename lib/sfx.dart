import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class Sfx {
  Sfx._();
  static final Sfx I = Sfx._();

  bool live = true;
  bool shake = true;

  AudioPlayer? _one;
  int _cool = 0;
  int _buzzAt = 0;

  AudioPlayer get _p {
    return _one ??= AudioPlayer()
      ..setPlayerMode(PlayerMode.lowLatency)
      ..setReleaseMode(ReleaseMode.stop);
  }

  void _go(String file, {int gap = 90}) {
    if (!live) return;
    final t = DateTime.now().millisecondsSinceEpoch;
    if (t - _cool < gap) return;
    _cool = t;
    _p.play(AssetSource('Blazebound_sounds_assets/$file')).catchError((_) {});
  }

  void buzz([int kind = 0]) {
    if (!shake) return;
    final t = DateTime.now().millisecondsSinceEpoch;
    if (t - _buzzAt < 120) return;
    _buzzAt = t;
    switch (kind) {
      case 1:
        HapticFeedback.mediumImpact();
      case 2:
        HapticFeedback.heavyImpact();
      default:
        HapticFeedback.selectionClick();
    }
  }

  void click() {
    buzz();
    _go('Button_Click_asset.mp3', gap: 40);
  }

  void confirm() {
    buzz(1);
    _go('Button_Confirm_asset.mp3', gap: 40);
  }

  void back() => _go('Button_Back_asset.mp3', gap: 40);

  void menuOpen() => _go('Menu_Open_asset.mp3', gap: 40);
  void menuClose() => _go('Menu_Close_asset.mp3', gap: 40);

  void throwCoin() {
    buzz();
    _go('Coin_Throw_asset.mp3');
  }

  void hit() {
    buzz(1);
    _go('Coin_Hit_asset.mp3', gap: 130);
  }

  void recall() {
    buzz(2);
    _go('Coin_Recall_asset.mp3', gap: 150);
  }

  void chain() => _go('Fire_Ignition_asset.mp3', gap: 160);
  void kill() => _go('Enemy_Defeat_asset.mp3', gap: 140);
  void ring() => _go('Fire_Ring_Interaction_asset.mp3', gap: 180);
  void ability() => _go('Ability_Activated_asset.mp3', gap: 180);
  void boss() => _go('Boss_Appears_asset.mp3', gap: 400);
  void start() => _go('Level_Start_asset.mp3', gap: 200);
  void win() => _go('Level_Complete_asset.mp3', gap: 300);
  void lose() => _go('Level_Failed_asset.mp3', gap: 300);
  void reward() => _go('Reward_Received_asset.mp3', gap: 120);
  void pick() => _go('Upgrade_Selected_asset.mp3', gap: 80);
  void chest() => _go('Chest_Open_asset.mp3', gap: 200);
  void portal() => _go('Portal_Activate_asset.mp3', gap: 200);
}
