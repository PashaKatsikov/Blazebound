import 'dart:math';

import 'package:flutter/material.dart';

import 'art.dart';
import 'sfx.dart';

class Dye {
  static const abyss = Color(0xFF140208);
  static const wine = Color(0xFF3B0C14);
  static const velvet = Color(0xFF5C1320);
  static const blood = Color(0xFF9B2233);
  static const gold = Color(0xFFE6B34A);
  static const goldHi = Color(0xFFFFE39A);
  static const goldLo = Color(0xFF8A5A18);
  static const ember = Color(0xFFFF6A21);
  static const flame = Color(0xFFFFB347);
  static const cream = Color(0xFFF6E7C8);
  static const ink = Color(0xFF1A0A10);
  static const panel = Color(0xCC16060C);
  static const panelSolid = Color(0xFF1C0A12);
}

TextStyle titleStyle(double size, {Color? color, double space = 0.4}) {
  return TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    letterSpacing: space,
    height: 1.05,
    color: color ?? Dye.cream,
    shadows: const [
      Shadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 2)),
      Shadow(color: Color(0x66FF6A21), blurRadius: 14),
    ],
  );
}

TextStyle bodyStyle(double size, {Color? color, FontWeight w = FontWeight.w600}) {
  return TextStyle(
    fontSize: size,
    fontWeight: w,
    letterSpacing: 0.3,
    height: 1.25,
    color: color ?? Dye.cream,
    shadows: const [Shadow(color: Color(0x88000000), blurRadius: 4)],
  );
}

class GoldFrame extends StatelessWidget {
  const GoldFrame({
    super.key,
    required this.child,
    this.radius = 16,
    this.pad = const EdgeInsets.all(14),
    this.fill,
    this.glow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsets pad;
  final Color? fill;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: Dye.gold.withValues(alpha: 0.18),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Dye.goldHi, Dye.gold, Dye.goldLo, Dye.gold],
        ),
      ),
      padding: const EdgeInsets.all(2.2),
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 1.5),
          color: fill ?? Dye.panel,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (fill ?? Dye.panelSolid).withValues(alpha: 0.96),
              const Color(0xF20C0408),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class CircusBtn extends StatelessWidget {
  const CircusBtn({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.wide = true,
    this.accent = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? icon;
  final bool wide;
  final bool accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                Sfx.I.click();
                onTap!();
              },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: height,
          width: wide ? double.infinity : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: accent
                  ? const [Color(0xFFD24A1C), Color(0xFF8B1A14), Color(0xFF5A0E10)]
                  : const [Color(0xFF7A1A24), Color(0xFF4A1018), Color(0xFF2A0A10)],
            ),
            border: Border.all(color: Dye.gold.withValues(alpha: 0.85), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: (accent ? Dye.ember : Dye.gold).withValues(alpha: 0.22),
                blurRadius: 10,
              ),
            ],
          ),
          child: Opacity(
            opacity: onTap == null ? 0.45 : 1,
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 10)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle(15, space: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class EmberChip extends StatelessWidget {
  const EmberChip({super.key, required this.amount, this.compact = false});

  final int amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 34.0 : 40.0;
    return GoldFrame(
      radius: 20,
      pad: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliceView(slice: Slices.ember, height: h - 6),
          const SizedBox(width: 6),
          Text('$amount', style: titleStyle(compact ? 14 : 16, color: Dye.goldHi, space: 0.4)),
        ],
      ),
    );
  }
}

class BackChip extends StatelessWidget {
  const BackChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.I.back();
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: GoldFrame(
        radius: 12,
        pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_left, color: Dye.goldHi, size: 20),
            Text('BACK', style: titleStyle(13, space: 0.8)),
          ],
        ),
      ),
    );
  }
}

class ArenaBackdrop extends StatelessWidget {
  const ArenaBackdrop({super.key, required this.asset, this.dim = 0.45, this.child});

  final String asset;
  final double dim;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: Image.asset(asset, fit: BoxFit.cover)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: dim * 0.7),
                  Colors.black.withValues(alpha: dim),
                  const Color(0xCC0A0206),
                ],
              ),
            ),
          ),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

class SliceView extends StatelessWidget {
  const SliceView({
    super.key,
    required this.slice,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final Slice slice;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final aspect = slice.src.width / slice.src.height;
    if (width != null || height != null) {
      final dest = _contain(width, height, aspect);
      return SizedBox(
        width: width ?? dest.width,
        height: height ?? dest.height,
        child: Center(
          child: CustomPaint(
            size: dest,
            painter: _SlicePainter(slice),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final dest = _containIn(box.maxWidth, box.maxHeight, aspect);
        return Center(
          child: CustomPaint(
            size: dest,
            painter: _SlicePainter(slice),
          ),
        );
      },
    );
  }
}

Size _contain(double? width, double? height, double aspect) {
  if (width != null && height != null) {
    if (width / height > aspect) return Size(height * aspect, height);
    return Size(width, width / aspect);
  }
  if (width != null) return Size(width, width / aspect);
  if (height != null) return Size(height * aspect, height);
  return Size(48, 48 / aspect);
}

Size _containIn(double maxW, double maxH, double aspect) {
  final hasW = maxW.isFinite;
  final hasH = maxH.isFinite;
  if (hasW && hasH) {
    if (maxW / maxH > aspect) return Size(maxH * aspect, maxH);
    return Size(maxW, maxW / aspect);
  }
  if (hasW) return Size(maxW, maxW / aspect);
  if (hasH) return Size(maxH * aspect, maxH);
  return Size(48, 48 / aspect);
}

class _SlicePainter extends CustomPainter {
  _SlicePainter(this.slice);

  final Slice slice;

  @override
  void paint(Canvas canvas, Size size) {
    final img = Art.I.img(slice.path);
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Art.I.src(slice),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _SlicePainter old) => old.slice != slice;
}

class SparkleField extends StatefulWidget {
  const SparkleField({super.key});

  @override
  State<SparkleField> createState() => _SparkleFieldState();
}

class _SparkleFieldState extends State<SparkleField> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rng = Random(7);
  late final List<_Dot> _dots;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _dots = List.generate(18, (_) {
      return _Dot(_rng.nextDouble(), _rng.nextDouble(), 1.2 + _rng.nextDouble() * 2.4, _rng.nextDouble());
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return CustomPaint(painter: _SparklePainter(_dots, _c.value), size: Size.infinite);
      },
    );
  }
}

class _Dot {
  _Dot(this.x, this.y, this.r, this.phase);
  final double x, y, r, phase;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.dots, this.t);
  final List<_Dot> dots;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (final d in dots) {
      final a = 0.15 + 0.45 * (0.5 + 0.5 * sin((t + d.phase) * pi * 2));
      p.color = Dye.goldHi.withValues(alpha: a);
      canvas.drawCircle(Offset(d.x * size.width, d.y * size.height), d.r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}
