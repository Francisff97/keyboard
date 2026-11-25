import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../model/keyboard.dart';

/// I tre tasti decorati della SOLIDEE: Esc, Invio e barra spaziatrice.
/// Sole rosso, onde e nuvole, ridisegnati in modo semplice.
class KeycapArtPainter extends CustomPainter {
  const KeycapArtPainter(this.art, {this.glow = 1});

  final KeyArt art;

  /// 1 = normale, >1 quando il tasto è premuto (si accende un po').
  final double glow;

  static const _sun = Color(0xFFE5432F);
  static const _sunLight = Color(0xFFFF7A4D);
  static const _wave = Color(0xFF3B78C4);
  static const _waveDeep = Color(0xFF1F3F75);
  static const _foam = Color(0xFFE8F4FF);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.shortestSide * 0.18));
    canvas.save();
    canvas.clipRRect(r);
    switch (art) {
      case KeyArt.esc:
        _sky(canvas, size, const [Color(0xFF1A2440), Color(0xFF3A2547)]);
        _sunDisc(canvas, Offset(size.width * 0.62, size.height * 0.42), size.height * 0.26);
        _waves(canvas, size, base: 0.70, amp: 0.08, count: 2);
      case KeyArt.enter:
        _sky(canvas, size, const [Color(0xFF162238), Color(0xFF243656)]);
        _sunDisc(canvas, Offset(size.width * 0.78, size.height * 0.34), size.height * 0.20);
        _crest(canvas, size);
      case KeyArt.space:
        _sky(canvas, size, const [Color(0xFF10141F), Color(0xFF1B1830)]);
        _clouds(canvas, size, behind: true);
        _sunDisc(canvas, Offset(size.width * 0.5, size.height * 0.52), size.height * 0.40);
        _clouds(canvas, size, behind: false);
      case KeyArt.none:
        break;
    }
    canvas.restore();
  }

  void _sky(Canvas canvas, Size size, List<Color> colors) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(Offset.zero & size),
    );
  }

  void _sunDisc(Canvas canvas, Offset c, double radius) {
    canvas.drawCircle(
      c,
      radius * 1.9,
      Paint()
        ..color = _sun.withValues(alpha: 0.18 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8),
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [_sunLight, _sun],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
  }

  /// Onde morbide in fondo al tasto.
  void _waves(Canvas canvas, Size size, {required double base, required double amp, required int count}) {
    for (var i = 0; i < count; i++) {
      final y0 = size.height * (base + i * 0.14);
      final path = Path()..moveTo(0, y0);
      const steps = 24;
      for (var s = 0; s <= steps; s++) {
        final x = size.width * s / steps;
        final y = y0 + math.sin(s / steps * math.pi * 3 + i) * size.height * amp;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = Color.lerp(_wave, _waveDeep, i / count)!);
      final edge = Path()..moveTo(0, y0);
      for (var s = 0; s <= steps; s++) {
        final x = size.width * s / steps;
        final y = y0 + math.sin(s / steps * math.pi * 3 + i) * size.height * amp;
        edge.lineTo(x, y);
      }
      canvas.drawPath(
        edge,
        Paint()
          ..color = _foam.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.035,
      );
    }
  }

  /// Una grande onda che si arriccia da sinistra.
  void _crest(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.42)
      ..cubicTo(w * 0.10, h * 0.10, w * 0.38, h * 0.02, w * 0.46, h * 0.30)
      ..cubicTo(w * 0.40, h * 0.22, w * 0.30, h * 0.30, w * 0.34, h * 0.44)
      ..cubicTo(w * 0.50, h * 0.62, w * 0.75, h * 0.66, w, h * 0.70)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_wave, _waveDeep],
        ).createShader(Offset.zero & size),
    );
    final curl = Path()
      ..moveTo(w * 0.02, h * 0.40)
      ..cubicTo(w * 0.12, h * 0.12, w * 0.36, h * 0.06, w * 0.44, h * 0.29);
    final foam = Paint()
      ..color = _foam
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.05;
    canvas.drawPath(curl, foam);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(w * (0.36 + i * 0.035), h * (0.30 + (i.isEven ? 0.02 : -0.02))),
        h * 0.025,
        Paint()..color = _foam,
      );
    }
    _waves(canvas, size, base: 0.80, amp: 0.05, count: 1);
  }

  /// Strisce di nuvole che attraversano la barra spaziatrice.
  void _clouds(Canvas canvas, Size size, {required bool behind}) {
    final w = size.width;
    final h = size.height;
    final bands = behind
        ? const [(0.18, 0.04, 0.40, 0.10), (0.62, 0.30, 0.95, 0.12)]
        : const [(0.30, 0.66, 0.70, 0.11), (0.08, 0.80, 0.30, 0.09), (0.70, 0.78, 0.96, 0.10)];
    for (final (x0, y, x1, th) in bands) {
      final rect = RRect.fromLTRBR(w * x0, h * y, w * x1, h * (y + th), Radius.circular(h * th));
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: behind
                ? [const Color(0xFF3D2E63), const Color(0xFF5B3F7A)]
                : [const Color(0xFF6B4A8F), const Color(0xFFE38B6A)],
          ).createShader(rect.outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(KeycapArtPainter old) => old.art != art || old.glow != glow;
}
