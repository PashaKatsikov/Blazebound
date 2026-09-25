import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Converts the Blazebound source icon (icon3_blazebound.png) into the PNGs
/// consumed by flutter_launcher_icons:
///   • assets/icon_src/bb_launch_icon.png      — 1024 legacy / mask base
///   • assets/icon_src/bb_launch_fg.png         — adaptive foreground.
///
/// The foreground stays full-bleed (adaptive XML inset 0dp). The jester is
/// scaled just enough to sit inside the circular launcher mask, and the
/// outer pixels are clamped outward so the mask shows no empty ring.
const int _canvasPx = 1024;

void main() {
  const String src = 'assets/marquee_art/icon3_blazebound.png';
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

  // Legacy / mask base: full-bleed square. Crop the center if the
  // source is not already square so the jester is not stretched.
  final int side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final img.Image square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final img.Image resized = img.copyResize(
    square,
    width: _canvasPx,
    height: _canvasPx,
    interpolation: img.Interpolation.cubic,
  );
  final double scale = _subjectScale(resized);
  final img.Image base = _bleed(resized, scale);
  stdout.writeln('Subject scale ${scale.toStringAsFixed(3)} (edge-bleed to fill the mask)');
  Directory('assets/icon_src').createSync(recursive: true);
  final List<int> png = img.encodePng(base);
  File('assets/icon_src/bb_launch_icon.png').writeAsBytesSync(png);
  // Full-bleed foreground; adaptive XML inset is 0dp.
  File('assets/icon_src/bb_launch_fg.png').writeAsBytesSync(png);

  // flutter_launcher_icons rewrites ic_launcher.png only. The legacy
  // round mipmaps are written here so the previous artwork cannot linger.
  const Map<String, int> roundPx = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  const String res = 'android/app/src/main/res';
  for (final MapEntry<String, int> bucket in roundPx.entries) {
    final img.Image round = _circle(base, bucket.value);
    File('$res/${bucket.key}/ic_launcher_round.png')
        .writeAsBytesSync(img.encodePng(round));
  }

  stdout.writeln('Icons generated: ${_canvasPx}px full-bleed '
      '(legacy + adaptive foreground) from $src '
      '(${decoded.width}x${decoded.height})');
}

/// Scale that pulls the jester (hat, outstretched hand, fruit) inside the
/// circular mask. Corner sparks are allowed to be clipped.
double _subjectScale(img.Image src) {
  final int n = src.width;
  final double cx = (n - 1) / 2;
  final double cy = (n - 1) / 2;
  final double radius = n / 2;
  double maxD = 0;

  bool subject(int x, int y) {
    final img.Pixel p = src.getPixel(x, y);
    final double lum = p.r * 0.2126 + p.g * 0.7152 + p.b * 0.0722;
    if (lum < 110) return false;
    final double nx = x / n;
    final double ny = y / n;
    final bool hat = ny < 0.30 && nx > 0.12 && nx < 0.88;
    final bool hand = nx < 0.22 && ny > 0.32 && ny < 0.72;
    final bool fruit = ny > 0.72 && nx > 0.18 && nx < 0.90;
    return hat || hand || fruit;
  }

  for (int y = 0; y < n; y += 2) {
    for (int x = 0; x < n; x += 2) {
      if (!subject(x, y)) continue;
      final double dx = x - cx;
      final double dy = y - cy;
      final double d = math.sqrt(dx * dx + dy * dy);
      if (d > maxD) maxD = d;
    }
  }
  if (maxD <= radius) return 1;
  // 3% inside the circle so the hat bells are not flush with the mask.
  return (radius * 0.97) / maxD;
}

/// Draws [src] at [scale], centered, and repeats the outer pixels so the
/// canvas stays full-bleed.
img.Image _bleed(img.Image src, double scale) {
  if (scale >= 0.999) return src;
  final int n = src.width;
  final int inner = math.max(1, (n * scale).round());
  final img.Image scaled = img.copyResize(
    src,
    width: inner,
    height: inner,
    interpolation: img.Interpolation.cubic,
  );
  final int ox = (n - inner) ~/ 2;
  final int oy = (n - inner) ~/ 2;
  final img.Image out = img.Image(width: n, height: n, numChannels: 4);
  for (int y = 0; y < n; y++) {
    final int sy = (y - oy).clamp(0, inner - 1);
    for (int x = 0; x < n; x++) {
      final int sx = (x - ox).clamp(0, inner - 1);
      out.setPixel(x, y, scaled.getPixel(sx, sy));
    }
  }
  return out;
}

img.Image _circle(img.Image src, int size) {
  final img.Image resized = img.copyResize(
    src,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );
  final img.Image out = img.Image(width: size, height: size, numChannels: 4);
  final double radius = size / 2;
  final double cx = radius - 0.5;
  final double cy = radius - 0.5;
  final double r2 = radius * radius;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final double dx = x - cx;
      final double dy = y - cy;
      if (dx * dx + dy * dy <= r2) {
        out.setPixel(x, y, resized.getPixel(x, y));
      }
    }
  }
  return out;
}
