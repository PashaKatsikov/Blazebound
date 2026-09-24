import 'dart:io';

import 'package:image/image.dart' as img;

/// Converts the Blazebound source icon (icon2_blazebound.jpg) into the PNGs
/// consumed by flutter_launcher_icons:
///   • assets/generated/app_icon.png            — 1024 legacy / mask base
///   • assets/generated/app_icon_foreground.png — adaptive foreground, art
///     scaled to 74dp inside the 108dp adaptive layer on a transparent
///     canvas (so the joker sits fully inside the circular mask safe zone).
const double _canvasDp = 108;
const double _artDp = 74;
const int _canvasPx = 1024;

void main() {
  const String src = 'assets/Blazebound_additional_assets/icon2_blazebound.jpg';
  final File file = File(src);
  if (!file.existsSync()) {
    stderr.writeln('Source icon not found: $src');
    exit(1);
  }

  final img.Image? decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Failed to decode source image.');
    exit(1);
  }

  // Legacy / mask base: full-bleed square.
  final img.Image base = img.copyResize(
    decoded,
    width: _canvasPx,
    height: _canvasPx,
    interpolation: img.Interpolation.cubic,
  );
  Directory('assets/generated').createSync(recursive: true);
  File('assets/generated/app_icon.png').writeAsBytesSync(img.encodePng(base));

  // Adaptive foreground: art at 74dp within a 108dp transparent canvas.
  final int artPx = (_canvasPx * (_artDp / _canvasDp)).round();
  final img.Image art = img.copyResize(
    decoded,
    width: artPx,
    height: artPx,
    interpolation: img.Interpolation.cubic,
  );
  final img.Image fg = img.Image(
    width: _canvasPx,
    height: _canvasPx,
    numChannels: 4,
  );
  // Fully transparent background.
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  final int offset = ((_canvasPx - artPx) / 2).round();
  img.compositeImage(fg, art, dstX: offset, dstY: offset);
  File('assets/generated/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Icons generated: legacy ${_canvasPx}px full-bleed, '
      'adaptive fg ${artPx}px (${_artDp}dp) centred in ${_canvasPx}px canvas.');
}
