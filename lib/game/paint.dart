import 'dart:math';

import 'package:flutter/material.dart';

import '../art.dart';
import '../look.dart';
import '../profile.dart';
import 'defs.dart';
import 'sim.dart';

class Cam {
  Cam.cover(Size view) {
    scale = max(view.width / worldW, view.height / worldH);
    origin = Offset((view.width - worldW * scale) / 2, (view.height - worldH * scale) / 2);
  }

  late final double scale;
  late final Offset origin;

  Offset toScreen(Offset w) => origin + w * scale;
  Offset toWorld(Offset s) => (s - origin) / scale;
}

final _imgPaint = Paint()..filterQuality = FilterQuality.none;
final _fill = Paint()..isAntiAlias = false;
final _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2
  ..isAntiAlias = false;

Size _camSize = Size.zero;
late Cam _cam;

Cam _camFor(Size size) {
  if (size != _camSize) {
    _camSize = size;
    _cam = Cam.cover(size);
  }
  return _cam;
}

class RingPainter extends CustomPainter {
  RingPainter(this.g, this.t, {this.padA, this.padB});

  final Circus g;
  final double t;
  final Offset? padA;
  final Offset? padB;

  @override
  void paint(Canvas canvas, Size size) {
    final cam = _camFor(size);
    if (g.shake > 0) {
      canvas.save();
      canvas.translate(sin(g.clock * 42) * g.shake * 0.28, 0);
    }

    final bg = Art.I.img(g.bg);
    if (bg != null) {
      final src = Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble());
      final scale = max(size.width / src.width, size.height / src.height);
      final dw = src.width * scale;
      final dh = src.height * scale;
      canvas.drawImageRect(
        bg,
        src,
        Rect.fromLTWH((size.width - dw) / 2, (size.height - dh) / 2, dw, dh),
        _imgPaint,
      );
    } else {
      _fill.color = Dye.abyss;
      canvas.drawRect(Offset.zero & size, _fill);
    }

    canvas.save();
    canvas.translate(cam.origin.dx, cam.origin.dy);
    canvas.scale(cam.scale);

    for (final o in g.props) {
      _sprite(canvas, o.spec.slice, o.p, o.spec.w, o.spec.h, 1);
    }
    for (final e in g.foes) {
      if (!e.dead) _foe(canvas, e);
    }
    _joker(canvas);
    for (final d in g.disks) {
      _coin(canvas, d);
    }
    for (final z in g.puddles) {
      _fill.color = const Color(0x66FF4A12);
      canvas.drawCircle(z.p, z.r, _fill);
    }
    for (final s in g.shots) {
      _fill.color = const Color(0xFFFF7A1A);
      canvas.drawCircle(s.p, 8, _fill);
    }

    canvas.restore();
    if (g.shake > 0) canvas.restore();

    if (g.flash > 0) {
      _fill.color = const Color(0x28FF2208);
      canvas.drawRect(Offset.zero & size, _fill);
    }

    final a = padA;
    final b = padB;
    if (a != null && b != null) {
      final d = b - a;
      final capped = d.distance > 54 ? d / d.distance * 54 : d;
      _fill.color = const Color(0x33FFE39A);
      canvas.drawCircle(a, 54, _fill);
      _stroke
        ..color = const Color(0xB3E6B34A)
        ..strokeWidth = 2;
      canvas.drawCircle(a, 54, _stroke);
      _fill.color = const Color(0xD9FFE39A);
      canvas.drawCircle(a + capped, 22, _fill);
    }
  }

  void _sprite(Canvas canvas, Slice slice, Offset feet, double w, double h, double flip) {
    final img = Art.I.img(slice.path);
    if (img == null) return;
    final aspect = slice.src.width / slice.src.height;
    final dw = w / h > aspect ? h * aspect : w;
    final dh = w / h > aspect ? h : w / aspect;
    final dest = Rect.fromCenter(center: feet + Offset(0, -dh * 0.42), width: dw, height: dh);
    _fill.color = const Color(0x55000000);
    canvas.drawOval(Rect.fromCenter(center: feet + const Offset(0, 6), width: dw * 0.56, height: 16), _fill);
    if (flip < 0) {
      canvas.save();
      canvas.translate(dest.center.dx, dest.center.dy);
      canvas.scale(-1, 1);
      canvas.translate(-dest.center.dx, -dest.center.dy);
      canvas.drawImageRect(img, Art.I.src(slice), dest, _imgPaint);
      canvas.restore();
    } else {
      canvas.drawImageRect(img, Art.I.src(slice), dest, _imgPaint);
    }
  }

  void _joker(Canvas canvas) {
    _sprite(canvas, Slices.joker, g.p, 72, 108, g.face);
    _bar(canvas, g.p + const Offset(0, -78), g.hp / g.maxHp, 46, const Color(0xFF3DDC7A), const Color(0xFF8B1A14));
  }

  void _foe(Canvas canvas, Foe e) {
    final st = breeds[e.kind]!;
    _sprite(canvas, st.draw, e.p, st.w, st.h, e.face);
    if (e.kind == Breed.shield && e.shieldUp) {
      _stroke
        ..color = const Color(0xAAD4B46A)
        ..strokeWidth = 3;
      canvas.drawArc(
        Rect.fromCircle(center: e.p + Offset(e.face * 18, -28), radius: 18),
        -1.2,
        2.4,
        false,
        _stroke,
      );
    }
    _bar(
      canvas,
      e.p + Offset(0, -st.h * 0.72),
      e.hp / e.maxHp,
      e.kind == Breed.boss ? 70 : 40,
      e.kind == Breed.boss ? Dye.ember : const Color(0xFFE24B4B),
      const Color(0xFF3A1010),
    );
  }

  void _coin(Canvas canvas, Disk d) {
    final sl = switch (d.kind) {
      CoinKind.flame => Slices.flame,
      CoinKind.piercer => Slices.piercer,
      CoinKind.burst => Slices.burst,
      CoinKind.chain => Slices.chain,
    };
    final img = Art.I.img(sl.path);
    if (img == null) return;
    canvas.save();
    canvas.translate(d.p.dx, d.p.dy);
    canvas.rotate(d.spin);
    canvas.drawImageRect(img, Art.I.src(sl), const Rect.fromLTWH(-22, -22, 44, 44), _imgPaint);
    canvas.restore();
  }

  void _bar(Canvas canvas, Offset c, double k, double w, Color ok, Color bad) {
    _fill.color = const Color(0xCC110206);
    canvas.drawRect(Rect.fromCenter(center: c, width: w, height: 5), _fill);
    _fill.color = k > 0.45 ? ok : bad;
    canvas.drawRect(
      Rect.fromLTWH(c.dx - w / 2, c.dy - 2, w * k.clamp(0.0, 1.0), 4),
      _fill,
    );
  }

  @override
  bool shouldRepaint(covariant RingPainter old) =>
      old.t != t || old.g != g || old.padA != padA || old.padB != padB;
}
