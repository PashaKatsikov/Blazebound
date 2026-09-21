import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class Paths {
  static const extra = 'assets/Blazebound_additional_assets';
  static const play = 'assets/Blazebound_gameplay_assets';
  static const snd = 'assets/Blazebound_sounds_assets';

  static const logo = '$extra/Game_Name.webp';
  static const loadH = '$extra/Horizontal_Loading_Screen.webp';
  static const loadV = '$extra/Vertical_Loading_Screen.webp';
  static const icon = '$extra/Icon.png';

  // Sheets came labeled backwards for the two leads. Use the pictures, not the names.
  static const joker = '$play/Inferno_Ringmaster_asset.webp';
  static const ringmaster = '$play/Blazebound_Joker_asset.webp';

  static const foesA = '$play/Circus_Enemies_Set_1_asset.webp';
  static const foesB = '$play/Circus_Enemies_Set_2_asset.webp';
  static const flameCoin = '$play/Basic_Fire_Coin_asset.webp';
  static const specials = '$play/Special_Coins_Set_asset.webp';
  static const ember = '$play/Ember_Coin_asset.webp';
  static const ring = '$play/Fire_Ring_asset.webp';
  static const barrel = '$play/Circus_Barrel_asset.webp';
  static const torch = '$play/Circus_Torch_asset.webp';
  static const target = '$play/Metal_Target_asset.webp';
  static const pedestal = '$play/Fire_Pedestal_asset.webp';
  static const rope = '$play/Circus_Rope_asset.webp';
  static const altar = '$play/Fire_Upgrade_Altar_asset.webp';
  static const portal = '$play/Arena_Portal_asset.webp';
  static const chest = '$play/Reward_Chest_asset.webp';
  static const columns = '$play/Circus_Columns_Set_asset.webp';
  static const wood = '$play/Wooden_Structures_Set_asset.webp';
  static const flags = '$play/Circus_Flags_Set_asset.webp';
  static const lamps = '$play/Decorative_Lanterns_Set_asset.webp';

  static const bgMain = '$play/Main_Circus_Arena_Background_asset.webp';
  static const bgFire = '$play/Fire_Circus_Arena_Background_asset.webp';
  static const bgBoss = '$play/Boss_Arena_Background_asset.webp';
  static const bgTent = '$play/Circus_Tent_Background_asset.webp';

  static const pictures = <String>[
    logo, loadH, loadV,
    joker, ringmaster, foesA, foesB,
    flameCoin, specials, ember,
    ring, barrel, torch, target, pedestal, rope, altar, portal, chest,
    columns, wood, flags, lamps,
    bgMain, bgFire, bgBoss, bgTent,
  ];
}

class Slice {
  const Slice(this.path, this.src);
  final String path;
  final ui.Rect src;

  @override
  bool operator ==(Object other) => other is Slice && other.path == path && other.src == src;

  @override
  int get hashCode => Object.hash(path, src);
}

class Slices {
  static const joker = Slice(Paths.joker, ui.Rect.fromLTWH(570, 10, 430, 654));
  static const ringmaster = Slice(Paths.ringmaster, ui.Rect.fromLTWH(475, 14, 595, 644));

  static const fighter = Slice(Paths.foesA, ui.Rect.fromLTWH(27, 78, 333, 521));
  static const bruiser = Slice(Paths.foesA, ui.Rect.fromLTWH(409, 24, 363, 548));
  static const acrobat = Slice(Paths.foesA, ui.Rect.fromLTWH(814, 24, 371, 516));
  static const masker = Slice(Paths.foesA, ui.Rect.fromLTWH(1206, 73, 314, 556));

  static const fireClown = Slice(Paths.foesB, ui.Rect.fromLTWH(90, 98, 241, 473));
  static const shield = Slice(Paths.foesB, ui.Rect.fromLTWH(389, 110, 335, 429));
  static const thrower = Slice(Paths.foesB, ui.Rect.fromLTWH(843, 124, 267, 439));
  static const heavy = Slice(Paths.foesB, ui.Rect.fromLTWH(1153, 161, 350, 400));

  static const flame = Slice(Paths.flameCoin, ui.Rect.fromLTWH(443, 25, 665, 603));
  static const piercer = Slice(Paths.specials, ui.Rect.fromLTWH(80, 106, 431, 437));
  static const burst = Slice(Paths.specials, ui.Rect.fromLTWH(568, 105, 430, 440));
  static const chain = Slice(Paths.specials, ui.Rect.fromLTWH(1062, 110, 427, 434));
  static const ember = Slice(Paths.ember, ui.Rect.fromLTWH(485, 65, 604, 534));

  static const ring = Slice(Paths.ring, ui.Rect.fromLTWH(490, 27, 604, 616));
  static const barrel = Slice(Paths.barrel, ui.Rect.fromLTWH(556, 15, 464, 629));
  static const torch = Slice(Paths.torch, ui.Rect.fromLTWH(511, 27, 597, 623));
  static const target = Slice(Paths.target, ui.Rect.fromLTWH(509, 20, 537, 605));
  static const pedestal = Slice(Paths.pedestal, ui.Rect.fromLTWH(495, 16, 593, 640));
  static const rope = Slice(Paths.rope, ui.Rect.fromLTWH(265, 33, 1030, 588));
  static const altar = Slice(Paths.altar, ui.Rect.fromLTWH(490, 23, 603, 620));
  static const portal = Slice(Paths.portal, ui.Rect.fromLTWH(486, 10, 612, 654));
  static const chest = Slice(Paths.chest, ui.Rect.fromLTWH(484, 11, 611, 641));

  static const col0 = Slice(Paths.columns, ui.Rect.fromLTWH(92, 25, 241, 599));
  static const col1 = Slice(Paths.columns, ui.Rect.fromLTWH(493, 32, 208, 592));
  static const col2 = Slice(Paths.columns, ui.Rect.fromLTWH(854, 26, 211, 606));
  static const col3 = Slice(Paths.columns, ui.Rect.fromLTWH(1245, 30, 234, 602));

  static const wood0 = Slice(Paths.wood, ui.Rect.fromLTWH(36, 180, 365, 349));
  static const wood1 = Slice(Paths.wood, ui.Rect.fromLTWH(446, 116, 308, 425));
  static const wood2 = Slice(Paths.wood, ui.Rect.fromLTWH(777, 180, 337, 362));
  static const wood3 = Slice(Paths.wood, ui.Rect.fromLTWH(1195, 60, 326, 490));

  static const flag0 = Slice(Paths.flags, ui.Rect.fromLTWH(61, 133, 348, 386));
  static const flag1 = Slice(Paths.flags, ui.Rect.fromLTWH(456, 132, 350, 393));
  static const flag2 = Slice(Paths.flags, ui.Rect.fromLTWH(823, 113, 327, 404));
  static const flag3 = Slice(Paths.flags, ui.Rect.fromLTWH(1191, 100, 351, 414));

  static const lamp0 = Slice(Paths.lamps, ui.Rect.fromLTWH(144, 176, 230, 390));
  static const lamp1 = Slice(Paths.lamps, ui.Rect.fromLTWH(589, 38, 340, 558));
  static const lamp2 = Slice(Paths.lamps, ui.Rect.fromLTWH(1182, 107, 303, 486));
}

class Art {
  Art._();
  static final Art I = Art._();

  final Map<String, ui.Image> _img = {};
  final Map<Slice, ui.Rect> _src = {};
  bool ready = false;

  ui.Image? img(String path) => _img[path];

  /// Slice coords are authored for 1584-wide sheets. Map them if the sheet was downscaled.
  ui.Rect src(Slice slice) {
    final hit = _src[slice];
    if (hit != null) return hit;
    final pic = _img[slice.path];
    if (pic == null) return slice.src;
    final k = pic.width / 1584.0;
    final mapped = k > 0.98
        ? slice.src
        : ui.Rect.fromLTWH(
            slice.src.left * k,
            slice.src.top * k,
            slice.src.width * k,
            slice.src.height * k,
          );
    _src[slice] = mapped;
    return mapped;
  }

  Future<void> load(void Function(double) onProg) async {
    final list = Paths.pictures;
    for (var i = 0; i < list.length; i++) {
      final path = list[i];
      try {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List();
        final wide = path.contains('Background') || path.contains('Loading');
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: wide ? 1280 : 960,
        );
        final frame = await codec.getNextFrame();
        _img[path] = frame.image;
      } catch (_) {}
      onProg((i + 1) / list.length);
    }
    ready = true;
  }
}
