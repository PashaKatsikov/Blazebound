import 'dart:io';

import 'package:image/image.dart' as img;

/// Converts the Blazebound source icon (icon2_blazebound.jpg) into the PNGs
/// consumed by flutter_launcher_icons:
///   • assets/icon_src/bb_launch_icon.png      — 1024 legacy / mask base
///   • assets/icon_src/bb_launch_fg.png         — adaptive foreground.
///
/// The foreground is FULL-BLEED: flutter_launcher_icons emits the adaptive
/// layer with `android:inset="16%"`, and 16% inset on a 108dp layer leaves
/// ~74dp of visible art — exactly the requested adaptive size. Pre-insetting
/// the PNG here as well would double-shrink it, so we do NOT.
const int _canvasPx = 1024;

void main() {
  const String src = 'assets/marquee_art/icon2_blazebound.jpg';
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
  Directory('assets/icon_src').createSync(recursive: true);
  final List<int> png = img.encodePng(base);
  File('assets/icon_src/bb_launch_icon.png').writeAsBytesSync(png);
  // Full-bleed foreground; the adaptive XML's 16% inset yields ~74dp visible.
  File('assets/icon_src/bb_launch_fg.png').writeAsBytesSync(png);

  stdout.writeln('Icons generated: ${_canvasPx}px full-bleed '
      '(legacy + adaptive foreground) from $src');
}
