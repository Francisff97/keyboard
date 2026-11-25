import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../brand.dart';
import '../model/actions.dart';
import '../model/keyboard.dart';
import '../state.dart';
import 'keycap_art.dart';

/// Colori della SOLIDEE, presi dalla foto.
class Solidee {
  static const caseTop = Color(0xFF2B2E33);
  static const caseBottom = Color(0xFF1C1E21);
  static const plate = Color(0xFF070809);

  static const alphaSkirt = Color(0xFF0B0D10);
  static const alphaTop = Color(0xFF1A1D22);
  static const modSkirt = Color(0xFF1B2C3A);
  static const modTop = Color(0xFF2C4458);

  /// Luce blu ghiaccio delle scritte.
  static const ice = Color(0xFF8BE9FF);

  /// La luce mista sotto i tasti.
  static const rgb = [
    Color(0xFFFF3D8B),
    Color(0xFFFF8A3D),
    Color(0xFFFFE14D),
    Color(0xFF4DFF9A),
    Color(0xFF3DD8FF),
    Color(0xFF8A5CFF),
    Color(0xFFFF3D8B),
  ];

  static const hold = Color(0xFFEE6352);
}

/// Colori di una tastiera qualsiasi (layout standard): sobri, senza grafica.
class PlainKeys {
  static const caseTop = Color(0xFF232427);
  static const caseBottom = Color(0xFF18191B);
  static const plate = Color(0xFF0C0C0D);
  static const alphaSkirt = Color(0xFF111214);
  static const alphaTop = Color(0xFF26282C);
  static const modSkirt = Color(0xFF16171A);
  static const modTop = Color(0xFF34373C);
  static const legend = Color(0xFFE6E6E6);
}

class KeyboardView extends StatelessWidget {
  const KeyboardView({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final layout = state.layout;
    final deco = layout.decorated;
    return LayoutBuilder(
      builder: (context, c) {
        // Bordo della scocca: 0.35u per lato.
        const pad = 0.35;
        final u = (c.maxWidth / (layout.width + pad * 2)).clamp(20.0, 72.0);
        final w = u * (layout.width + pad * 2);
        final h = u * (layout.height + pad * 2);
        return Center(
          child: SizedBox(
            width: w,
            height: h + u * 0.6,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // La luce mista che esce da sotto la scocca.
                if (deco)
                  Positioned(
                    left: u * 0.4,
                    right: u * 0.4,
                    top: h * 0.55,
                    height: h * 0.5,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: u * 0.7, sigmaY: u * 0.5),
                      child: Opacity(
                        opacity: 0.35,
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: LinearGradient(colors: Solidee.rgb)),
                        ),
                      ),
                    ),
                  ),
                // Scocca.
                Positioned(
                  left: 0,
                  top: 0,
                  width: w,
                  height: h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: deco
                            ? const [Solidee.caseTop, Solidee.caseBottom]
                            : const [PlainKeys.caseTop, PlainKeys.caseBottom],
                      ),
                      borderRadius: BorderRadius.circular(u * 0.32),
                      border: Border.all(color: const Color(0xFF3B3F45)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: u * 0.8,
                          offset: Offset(0, u * 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                // Piastra con la luce mista tra i tasti.
                Positioned(
                  left: u * (pad - 0.06),
                  top: u * (pad - 0.06),
                  width: u * (layout.width + 0.12),
                  height: u * (layout.height + 0.12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(u * 0.12),
                      color: deco ? Solidee.plate : PlainKeys.plate,
                      gradient: deco
                          ? LinearGradient(colors: [for (final c in Solidee.rgb) Color.lerp(Solidee.plate, c, 0.28)!])
                          : null,
                    ),
                  ),
                ),
                for (final k in layout.keys)
                  Positioned(
                    left: u * (pad + k.x),
                    top: u * (pad + k.y),
                    width: u * k.w,
                    height: u * k.h,
                    child: _Keycap(keyDef: k, u: u, state: state, deco: deco),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Keycap extends StatefulWidget {
  const _Keycap({required this.keyDef, required this.u, required this.state, required this.deco});

  final KeyDef keyDef;
  final double u;
  final AppState state;
  final bool deco;

  @override
  State<_Keycap> createState() => _KeycapState();
}

class _KeycapState extends State<_Keycap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final k = widget.keyDef;
    final u = widget.u;
    final s = widget.state;
    final layer = s.layer;

    final binding = s.bindingFor(k.id);
    final inherited = binding == null ? s.inheritedFor(k.id) : null;
    final selected = s.selectedKey?.id == k.id;
    final pressed = s.pressed.contains(k.id);

    // Il tasto che, tenuto premuto, apre il livello che stai guardando.
    final opensLayer = s.opensCurrentLayer(k.id);

    // Nei livelli 1 e 2 i tasti senza modifiche sono "trasparenti": passano al livello base.
    final dim = layer > 0 && binding == null && inherited == null && !opensLayer;

    final mod = k.tone == KeyTone.mod;
    final deco = widget.deco;
    final skirt = deco
        ? (mod ? Solidee.modSkirt : Solidee.alphaSkirt)
        : (mod ? PlainKeys.modSkirt : PlainKeys.alphaSkirt);
    var top = deco ? (mod ? Solidee.modTop : Solidee.alphaTop) : (mod ? PlainKeys.modTop : PlainKeys.alphaTop);
    if (_hover && !k.firmware) top = Color.lerp(top, Colors.white, 0.08)!;
    if (pressed) top = Color.lerp(top, Solidee.ice, 0.18)!;

    final gap = u * 0.05;
    final radius = u * 0.13;

    Widget cap = Padding(
      padding: EdgeInsets.all(gap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: skirt,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected
                ? FD.text
                : opensLayer
                ? Solidee.hold
                : pressed
                ? Solidee.ice.withValues(alpha: 0.8)
                : Colors.black.withValues(alpha: 0.6),
            width: selected || opensLayer ? 2 : 1,
          ),
          boxShadow: [
            if (pressed) BoxShadow(color: Solidee.ice.withValues(alpha: 0.45), blurRadius: u * 0.4),
            if (selected) BoxShadow(color: FD.accent.withValues(alpha: 0.5), blurRadius: u * 0.35),
          ],
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 90),
          padding: EdgeInsets.fromLTRB(u * 0.08, u * (pressed ? 0.08 : 0.04), u * 0.08, u * (pressed ? 0.10 : 0.14)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius * 0.8),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(top, Colors.white, 0.05)!, top],
              ),
            ),
            child: k.art == KeyArt.none || !deco
                ? _Legends(
                    keyDef: k,
                    u: u,
                    italian: s.italianLegends,
                    pressed: pressed,
                    color: deco ? Solidee.ice : PlainKeys.legend,
                    glow: deco,
                  )
                : CustomPaint(painter: KeycapArtPainter(k.art, glow: pressed ? 1.8 : 1)),
          ),
        ),
      ),
    );

    // Etichetta con l'azione assegnata, sotto il tasto.
    final tap = (binding ?? inherited)?.tap;
    final hold = (binding ?? inherited)?.hold;
    if (tap != null || hold != null) {
      cap = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: cap),
          if (tap != null)
            Positioned(
              left: gap + u * 0.06,
              right: gap + u * 0.06,
              bottom: gap + u * 0.02,
              child: KeyBadge(
                text: tap.badge,
                color: inherited != null
                    ? FD.muted.withValues(alpha: 0.5)
                    : (tap is DisabledAction ? FD.danger : FD.accent),
                u: u,
              ),
            ),
          if (hold != null)
            Positioned(
              right: gap - u * 0.04,
              top: gap - u * 0.06,
              child: _HoldDot(text: hold.badge, u: u, faded: inherited != null),
            ),
        ],
      );
    }

    final tip = k.firmware
        ? 'Fn lo gestisce la tastiera: non arriva mai al Mac.'
        : [
            k.displayName,
            if (binding?.tap != null) binding!.tap!.describe,
            if (binding?.hold != null) 'Tenuto: ${binding!.hold!.describe}',
          ].join(' · ');

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: k.firmware ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: k.firmware ? null : () => s.selectKey(k.id),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: k.firmware ? 0.45 : (dim ? 0.32 : 1),
            child: cap,
          ),
        ),
      ),
    );
  }
}

class _Legends extends StatelessWidget {
  const _Legends({
    required this.keyDef,
    required this.u,
    required this.italian,
    required this.pressed,
    required this.color,
    required this.glow,
  });

  final KeyDef keyDef;
  final double u;
  final bool italian;
  final bool pressed;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final k = keyDef;
    final shadows = glow || pressed
        ? [
            Shadow(
              color: color.withValues(alpha: pressed ? 0.95 : 0.55),
              blurRadius: u * (pressed ? 0.22 : 0.12),
            ),
          ]
        : null;
    TextStyle style(double size, {double alpha = 1}) => TextStyle(
      fontSize: size,
      height: 1,
      color: color.withValues(alpha: alpha),
      fontWeight: FontWeight.w600,
      shadows: shadows,
    );

    final main = k.legend(italian: italian);
    final shift = k.shiftLegend(italian: italian);
    final isWord = main.length > 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(u * 0.1, u * 0.07, u * 0.08, u * 0.05),
      child: Stack(
        children: [
          if (isWord && k.tone == KeyTone.mod)
            Align(
              alignment: k.w > 1.2 ? Alignment.centerLeft : Alignment.center,
              child: Text(main, maxLines: 1, overflow: TextOverflow.clip, style: style(u * 0.2)),
            )
          else
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shift != null) ...[Text(shift, style: style(u * 0.18, alpha: 0.75)), SizedBox(height: u * 0.03)],
                  Text(main, style: style(u * (shift != null ? 0.2 : 0.26))),
                ],
              ),
            ),
          if (k.fn != null)
            Align(
              alignment: Alignment.bottomRight,
              child: Text(k.fn!, style: style(u * 0.13, alpha: 0.5)),
            ),
        ],
      ),
    );
  }
}

class KeyBadge extends StatelessWidget {
  const KeyBadge({super.key, required this.text, required this.color, required this.u});

  final String text;
  final Color color;
  final double u;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: u * 0.24,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: u * 0.04),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(u * 0.04)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          style: FD
              .monoStyle(size: u * 0.15, color: Colors.white, weight: FontWeight.w700)
              .copyWith(letterSpacing: u * 0.01),
        ),
      ),
    );
  }
}

class _HoldDot extends StatelessWidget {
  const _HoldDot({required this.text, required this.u, required this.faded});

  final String text;
  final double u;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: u * 0.26),
      height: u * 0.26,
      padding: EdgeInsets.symmetric(horizontal: u * 0.05),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: faded ? FD.muted.withValues(alpha: 0.6) : Solidee.hold,
        borderRadius: BorderRadius.circular(u * 0.13),
        border: Border.all(color: FD.bg, width: 1.5),
      ),
      child: Text(
        text,
        style: FD.monoStyle(size: u * 0.13, color: Colors.white, weight: FontWeight.w700).copyWith(letterSpacing: 0),
      ),
    );
  }
}
