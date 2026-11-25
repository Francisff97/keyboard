import 'package:material_ui/material_ui.dart';

import '../brand.dart';
import '../model/actions.dart';
import '../model/keyboard.dart';
import '../state.dart';
import 'keyboard_view.dart';

/// Un mouse da gioco visto dall'alto, con i tasti laterali sul lato del pollice.
/// Disegnato in uno spazio 300 × 460 e poi scalato.
class MouseView extends StatelessWidget {
  const MouseView({super.key, required this.state, this.maxHeight = 380});

  final AppState state;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final layout = Layouts.mouse;
    return LayoutBuilder(
      builder: (context, c) {
        final scale = (c.maxWidth / layout.width).clamp(0.4, maxHeight / layout.height);
        final w = layout.width * scale;
        final h = layout.height * scale;
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: CustomPaint(painter: _BodyPainter())),
                for (final b in layout.keys)
                  Positioned(
                    left: b.x * scale,
                    top: b.y * scale,
                    width: b.w * scale,
                    height: b.h * scale,
                    child: _MouseButton(def: b, scale: scale, state: state),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BodyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300;
    canvas.save();
    canvas.scale(s);
    final body = Path()
      ..moveTo(150, 6)
      ..cubicTo(95, 6, 50, 14, 40, 40)
      ..cubicTo(34, 70, 34, 140, 36, 180)
      ..cubicTo(22, 186, 0, 196, 0, 232)
      ..cubicTo(0, 300, 4, 352, 16, 382)
      ..cubicTo(32, 430, 80, 456, 150, 456)
      ..cubicTo(220, 456, 270, 430, 282, 380)
      ..cubicTo(294, 330, 292, 250, 284, 190)
      ..cubicTo(276, 130, 272, 60, 262, 40)
      ..cubicTo(252, 14, 205, 6, 150, 6)
      ..close();

    canvas.drawShadow(body, Colors.black, 18, false);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2C30), Color(0xFF151618)],
        ).createShader(const Rect.fromLTWH(0, 0, 300, 460)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF3B3F45),
    );

    // Appoggio del palmo, leggermente più chiaro.
    final palm = Path()
      ..moveTo(70, 214)
      ..cubicTo(90, 204, 210, 204, 238, 214)
      ..cubicTo(250, 300, 236, 400, 150, 420)
      ..cubicTo(64, 400, 52, 300, 70, 214)
      ..close();
    canvas.drawPath(palm, Paint()..color = const Color(0xFF1E2023));

    // Una striscia di luce, come sui mouse da gioco.
    final light = RRect.fromLTRBR(118, 360, 182, 368, const Radius.circular(4));
    canvas.drawRRect(
      light.inflate(6),
      Paint()
        ..shader = LinearGradient(colors: [for (final c in Solidee.rgb) c.withValues(alpha: 0.35)])
            .createShader(light.outerRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(light, Paint()..shader = const LinearGradient(colors: Solidee.rgb).createShader(light.outerRect));

    // Filo.
    canvas.drawLine(
      const Offset(150, 6),
      const Offset(150, -40),
      Paint()
        ..strokeWidth = 4
        ..color = const Color(0xFF1A1B1D),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MouseButton extends StatefulWidget {
  const _MouseButton({required this.def, required this.scale, required this.state});

  final KeyDef def;
  final double scale;
  final AppState state;

  @override
  State<_MouseButton> createState() => _MouseButtonState();
}

class _MouseButtonState extends State<_MouseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.def;
    final s = widget.state;
    final scale = widget.scale;
    final binding = s.bindingFor(b.id);
    final inherited = binding == null ? s.inheritedFor(b.id) : null;
    final tap = (binding ?? inherited)?.tap;
    final selected = s.selectedKey?.id == b.id;
    final pressed = s.pressed.contains(b.id);
    final big = b.h > 100;
    final wheel = b.id == 'm-middle';

    // Forme: i due tasti grandi seguono la curva del mouse.
    final r = Radius.circular(10 * scale);
    final radius = switch (b.id) {
      'm-left' => BorderRadius.only(topLeft: Radius.circular(70 * scale), topRight: r, bottomLeft: r, bottomRight: r),
      'm-right' => BorderRadius.only(topRight: Radius.circular(90 * scale), topLeft: r, bottomLeft: r, bottomRight: r),
      _ => BorderRadius.circular((wheel ? 13 : 7) * scale),
    };

    var fill = wheel ? const Color(0xFF3A3D42) : const Color(0xFF222428);
    if (_hover && !b.firmware) fill = Color.lerp(fill, Colors.white, 0.08)!;
    if (pressed) fill = Color.lerp(fill, Solidee.ice, 0.25)!;

    final border = selected
        ? FD.text
        : tap != null
        ? (inherited != null ? FD.muted : (tap is DisabledAction ? FD.danger : FD.accent))
        : pressed
        ? Solidee.ice
        : const Color(0xFF0E0F11);

    Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: border, width: selected || tap != null ? 2 : 1),
        boxShadow: [
          if (pressed) BoxShadow(color: Solidee.ice.withValues(alpha: 0.5), blurRadius: 14 * scale),
          if (selected) BoxShadow(color: FD.accent.withValues(alpha: 0.5), blurRadius: 12 * scale),
        ],
      ),
      child: wheel ? CustomPaint(painter: _WheelRidges()) : null,
    );

    if (big) {
      child = Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20 * scale,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      b.label.toUpperCase(),
                      maxLines: 1,
                      style: FD.monoStyle(size: 9.5 * scale.clamp(0.8, 1.4)),
                    ),
                  ),
                ),
                if (tap != null) ...[
                  SizedBox(height: 8 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                    child: KeyBadge(
                      text: tap.badge,
                      color: inherited != null ? FD.muted.withValues(alpha: 0.5) : FD.accent,
                      u: 44 * scale,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final tip = b.firmware
        ? 'Il click sinistro non si cambia: rischieresti di non poter più cliccare.'
        : [b.displayName, if (tap != null) tap.describe].join(' · ');

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: b.firmware ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: b.firmware ? null : () => s.selectKey(b.id),
          child: Opacity(opacity: b.firmware ? 0.55 : 1, child: child),
        ),
      ),
    );
  }
}

class _WheelRidges extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF55595F)
      ..strokeWidth = 1.2;
    for (var y = size.height * 0.12; y < size.height * 0.9; y += size.height / 11) {
      canvas.drawLine(Offset(size.width * 0.22, y), Offset(size.width * 0.78, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
