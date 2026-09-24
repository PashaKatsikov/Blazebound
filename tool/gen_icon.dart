import 'dart:io';

import 'package:image/image.dart' as img;

/// Converts the Blazebound source icon (icon2_blazebound.jpg) into the PNGs
/// consumed by flutter_launcher_icons:
///   • assets/generated/app_icon.png            — 1024 legacy / mask base
///   • assets/generated/app_icon_foreground.png — full-bleed adaptive fg
///
/// The source art is a centred joker on its own busy background, so it is
/// used edge-to-edge (the adaptive mask crops the corners; the face stays
/// well inside the 66% safe zone).
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

  final img.Image base = img.copyResize(
    decoded,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );

  Directory('assets/generated').createSync(recursive: true);
  final List<int> pngBytes = img.encodePng(base);
  File('assets/generated/app_icon.png').writeAsBytesSync(pngBytes);
  File('assets/generated/app_icon_foreground.png').writeAsBytesSync(pngBytes);

  stdout.writeln('Icons generated: '
      '${base.width}x${base.height} -> assets/generated/');
}
