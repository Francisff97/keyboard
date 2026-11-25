/// I layout dei dispositivi che Tocco sa disegnare:
/// - la SOLIDEE 65% (68 tasti, "68 Monstor");
/// - una tastiera standard ANSI a 104 tasti, per tutte le altre;
/// - un mouse da gioco con i tasti laterali.
///
/// Ogni tasto ha:
/// - la posizione (in "unità" per le tastiere, in punti per il mouse);
/// - il codice HID (pagina 0x07 tastiera, 0x09 pulsanti), quello che Flutter
///   vede come PhysicalKeyboardKey e che il motore legge da IOHID;
/// - il codice che il motore usa: keycode di macOS (kVK_*) per le tastiere,
///   numero del pulsante (0 sinistro, 1 destro, 2 centrale…) per il mouse.
library;

import 'dart:ui' show Rect;

enum DeviceKind { keyboard, mouse }

enum KeyTone { alpha, mod }

/// Tasti con la grafica speciale (sole rosso e onde, come nella foto).
enum KeyArt { none, esc, enter, space }

class KeyDef {
  const KeyDef({
    required this.id,
    required this.label,
    required this.hid,
    required this.mac,
    this.x = -1,
    this.y = -1,
    this.w = 1,
    this.h = 1,
    this.shift,
    this.fn,
    this.it,
    this.itShift,
    this.name,
    this.tone = KeyTone.alpha,
    this.art = KeyArt.none,
    this.firmware = false,
    this.note,
  });

  final String id;

  /// Etichetta stampata sul tasto.
  final String label;

  /// Simbolo con Shift, stampato sopra (es. "!" sull'1).
  final String? shift;

  /// Funzione con Fn, stampata piccola in basso (es. "F1").
  final String? fn;

  /// Cosa esce con il layout italiano (Italiano – Pro) e con Shift.
  final String? it;
  final String? itShift;

  /// Nome lungo, per il pannello a destra.
  final String? name;

  final int hid;

  /// Keycode del Mac (tastiere) o numero del pulsante (mouse).
  final int mac;
  final double x;
  final double y;
  final double w;
  final double h;
  final KeyTone tone;
  final KeyArt art;

  /// Gestito dal dispositivo stesso: non arriva mai al Mac (Fn, click sinistro).
  final bool firmware;

  /// Avviso da mostrare nel pannello (es. tasti DPI del mouse).
  final String? note;

  bool get onBoard => x >= 0;
  String get displayName => name ?? label;
  Rect get rect => Rect.fromLTWH(x, y, w, h);

  /// Etichetta da mostrare sul tasto, in base al layout scelto.
  String legend({required bool italian}) => italian ? (it ?? label) : label;
  String? shiftLegend({required bool italian}) => italian ? (itShift ?? shift) : shift;

  /// Il valore di PhysicalKeyboardKey.usbHidUsage per questo tasto.
  int get flutterUsage => 0x00070000 | hid;
}

class _K {
  const _K(
    this.id,
    this.label,
    this.hid,
    this.mac, {
    this.w = 1,
    this.h = 1,
    this.shift,
    this.fn,
    this.it,
    this.itShift,
    this.name,
    this.tone = KeyTone.alpha,
    this.art = KeyArt.none,
    this.firmware = false,
  });

  final String id;
  final String label;
  final int hid;
  final int mac;
  final double w;
  final double h;
  final String? shift;
  final String? fn;
  final String? it;
  final String? itShift;
  final String? name;
  final KeyTone tone;
  final KeyArt art;
  final bool firmware;

  /// Lo stesso tasto senza grafica e senza funzioni Fn (per la tastiera standard).
  _K plain({double? w, double h = 1, String? label, KeyTone? tone}) => _K(
    id,
    label ?? (this.label.isEmpty ? '' : this.label),
    hid,
    mac,
    w: w ?? 1,
    h: h,
    shift: shift,
    it: it,
    itShift: itShift,
    name: name,
    tone: tone ?? this.tone,
  );
}

const _m = KeyTone.mod;

const _solideeRows = <List<_K>>[
  [
    _K('esc', 'Esc', 0x29, 53, art: KeyArt.esc, name: 'Esc', tone: _m),
    _K('1', '1', 0x1E, 18, shift: '!', fn: 'F1', itShift: '!'),
    _K('2', '2', 0x1F, 19, shift: '@', fn: 'F2', itShift: '"'),
    _K('3', '3', 0x20, 20, shift: '#', fn: 'F3', itShift: '£'),
    _K('4', '4', 0x21, 21, shift: r'$', fn: 'F4', itShift: r'$'),
    _K('5', '5', 0x22, 23, shift: '%', fn: 'F5', itShift: '%'),
    _K('6', '6', 0x23, 22, shift: '^', fn: 'F6', itShift: '&'),
    _K('7', '7', 0x24, 26, shift: '&', fn: 'F7', itShift: '/'),
    _K('8', '8', 0x25, 28, shift: '*', fn: 'F8', itShift: '('),
    _K('9', '9', 0x26, 25, shift: '(', fn: 'F9', itShift: ')'),
    _K('0', '0', 0x27, 29, shift: ')', fn: 'F10', itShift: '='),
    _K('minus', '-', 0x2D, 27, shift: '_', fn: 'F11', it: "'", itShift: '?'),
    _K('equal', '=', 0x2E, 24, shift: '+', fn: 'F12', it: 'ì', itShift: '^'),
    _K('backspace', 'Back', 0x2A, 51, w: 2, name: 'Backspace', tone: _m),
    _K('grave', '`', 0x35, 50, shift: '~', it: r'\', itShift: '|', name: 'Tasto ` ~', tone: _m),
  ],
  [
    _K('tab', 'Tab', 0x2B, 48, w: 1.5, tone: _m),
    _K('q', 'Q', 0x14, 12),
    _K('w', 'W', 0x1A, 13),
    _K('e', 'E', 0x08, 14),
    _K('r', 'R', 0x15, 15),
    _K('t', 'T', 0x17, 17),
    _K('y', 'Y', 0x1C, 16),
    _K('u', 'U', 0x18, 32),
    _K('i', 'I', 0x0C, 34),
    _K('o', 'O', 0x12, 31),
    _K('p', 'P', 0x13, 35),
    _K('lbracket', '[', 0x2F, 33, shift: '{', fn: 'Home', it: 'è', itShift: 'é'),
    _K('rbracket', ']', 0x30, 30, shift: '}', fn: 'End', it: '+', itShift: '*'),
    _K('backslash', r'\', 0x31, 42, w: 1.5, shift: '|', it: 'ù', itShift: '§', tone: _m),
    _K('delete', 'Del', 0x4C, 117, name: 'Canc (Del)', tone: _m),
  ],
  [
    _K('caps', 'CapsLock', 0x39, 57, w: 1.75, name: 'Caps Lock', tone: _m),
    _K('a', 'A', 0x04, 0),
    _K('s', 'S', 0x16, 1),
    _K('d', 'D', 0x07, 2),
    _K('f', 'F', 0x09, 3),
    _K('g', 'G', 0x0A, 5),
    _K('h', 'H', 0x0B, 4),
    _K('j', 'J', 0x0D, 38),
    _K('k', 'K', 0x0E, 40),
    _K('l', 'L', 0x0F, 37),
    _K('semicolon', ';', 0x33, 41, shift: ':', it: 'ò', itShift: 'ç'),
    _K('quote', "'", 0x34, 39, shift: '"', it: 'à', itShift: '°'),
    _K('enter', 'Enter', 0x28, 36, w: 2.25, art: KeyArt.enter, name: 'Invio', tone: _m),
    _K('pgup', 'PgUp', 0x4B, 116, name: 'Pagina su', tone: _m),
  ],
  [
    _K('lshift', 'Shift', 0xE1, 56, w: 2.25, name: 'Shift sinistro', tone: _m),
    _K('z', 'Z', 0x1D, 6),
    _K('x', 'X', 0x1B, 7),
    _K('c', 'C', 0x06, 8),
    _K('v', 'V', 0x19, 9),
    _K('b', 'B', 0x05, 11),
    _K('n', 'N', 0x11, 45),
    _K('m', 'M', 0x10, 46),
    _K('comma', ',', 0x36, 43, shift: '<', fn: 'Win', itShift: ';'),
    _K('period', '.', 0x37, 47, shift: '>', fn: 'Mac', itShift: ':'),
    _K('slash', '/', 0x38, 44, shift: '?', it: '-', itShift: '_'),
    _K('rshift', 'Shift', 0xE5, 60, w: 1.75, name: 'Shift destro', tone: _m),
    _K('up', '↑', 0x52, 126, name: 'Freccia su'),
    _K('pgdn', 'PgDn', 0x4E, 121, name: 'Pagina giù', tone: _m),
  ],
  [
    _K('lctrl', 'Ctrl', 0xE0, 59, w: 1.25, name: 'Ctrl sinistro', tone: _m),
    _K('lgui', 'Win', 0xE3, 55, w: 1.25, shift: '⌘', name: 'Win (⌘ sul Mac)', tone: _m),
    _K('lalt', 'Alt', 0xE2, 58, w: 1.25, shift: '⌥', name: 'Alt (⌥ sul Mac)', tone: _m),
    _K('space', '', 0x2C, 49, w: 6.25, art: KeyArt.space, name: 'Spazio'),
    _K('ralt', 'Alt', 0xE6, 61, shift: '⌥', name: 'Alt destro', tone: _m),
    _K('fn', 'Fn', 0, 63, name: 'Fn', tone: _m, firmware: true),
    _K('rctrl', 'Ctrl', 0xE4, 62, name: 'Ctrl destro', tone: _m),
    _K('left', '←', 0x50, 123, name: 'Freccia sinistra'),
    _K('down', '↓', 0x51, 125, name: 'Freccia giù'),
    _K('right', '→', 0x4F, 124, name: 'Freccia destra'),
  ],
];

/// Spazio vuoto nella riga (tra i gruppi di tasti).
_K _gap(double w) => _K('_gap', '', 0, 0, w: w);

List<KeyDef> _place(List<(double, List<_K>)> rows) {
  final out = <KeyDef>[];
  for (final (y, row) in rows) {
    var x = 0.0;
    for (final k in row) {
      if (k.id != '_gap') {
        out.add(
          KeyDef(
            id: k.id,
            label: k.label,
            hid: k.hid,
            mac: k.mac,
            x: x,
            y: y,
            w: k.w,
            h: k.h,
            shift: k.shift,
            fn: k.fn,
            it: k.it,
            itShift: k.itShift,
            name: k.name,
            tone: k.tone,
            art: k.art,
            firmware: k.firmware,
          ),
        );
      }
      x += k.w;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Tastiera standard ANSI 104
// ---------------------------------------------------------------------------

final Map<String, _K> _s = {
  for (final r in _solideeRows)
    for (final k in r) k.id: k,
};

_K _p(String id, {double? w, double h = 1, String? label, KeyTone? tone}) =>
    _s[id]!.plain(w: w, h: h, label: label, tone: tone);

const _f = [
  _K('f1', 'F1', 0x3A, 122, tone: _m),
  _K('f2', 'F2', 0x3B, 120, tone: _m),
  _K('f3', 'F3', 0x3C, 99, tone: _m),
  _K('f4', 'F4', 0x3D, 118, tone: _m),
  _K('f5', 'F5', 0x3E, 96, tone: _m),
  _K('f6', 'F6', 0x3F, 97, tone: _m),
  _K('f7', 'F7', 0x40, 98, tone: _m),
  _K('f8', 'F8', 0x41, 100, tone: _m),
  _K('f9', 'F9', 0x42, 101, tone: _m),
  _K('f10', 'F10', 0x43, 109, tone: _m),
  _K('f11', 'F11', 0x44, 103, tone: _m),
  _K('f12', 'F12', 0x45, 111, tone: _m),
];

const _kp = KeyTone.alpha;

List<KeyDef> _buildAnsi() {
  final letters1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
  final letters2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
  final letters3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];
  final numbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  return _place([
    (
      0,
      [
        _p('esc'),
        _gap(1),
        ..._f.sublist(0, 4),
        _gap(0.5),
        ..._f.sublist(4, 8),
        _gap(0.5),
        ..._f.sublist(8, 12),
        _gap(0.25),
        const _K('prtsc', 'PrtSc', 0x46, 105, name: 'Stamp (F13 sul Mac)', tone: _m),
        const _K('scrlk', 'ScrLk', 0x47, 107, name: 'Bloc Scorr (F14 sul Mac)', tone: _m),
        const _K('pause', 'Pause', 0x48, 113, name: 'Pausa (F15 sul Mac)', tone: _m),
      ],
    ),
    (
      1.25,
      [
        _p('grave', tone: KeyTone.alpha),
        for (final n in numbers) _p(n),
        _p('minus'),
        _p('equal'),
        _p('backspace', w: 2),
        _gap(0.25),
        const _K('insert', 'Ins', 0x49, 114, name: 'Ins (Help sul Mac)', tone: _m),
        const _K('home', 'Home', 0x4A, 115, name: 'Inizio riga', tone: _m),
        _p('pgup'),
        _gap(0.25),
        const _K('numlock', 'Num', 0x53, 71, name: 'Bloc Num (Clear sul Mac)', tone: _m),
        const _K('kpdiv', '/', 0x54, 75, name: 'Tastierino /', tone: _kp),
        const _K('kpmul', '*', 0x55, 67, name: 'Tastierino *', tone: _kp),
        const _K('kpminus', '−', 0x56, 78, name: 'Tastierino −', tone: _kp),
      ],
    ),
    (
      2.25,
      [
        _p('tab', w: 1.5),
        for (final l in letters1) _p(l),
        _p('lbracket'),
        _p('rbracket'),
        _p('backslash', w: 1.5, tone: KeyTone.alpha),
        _gap(0.25),
        _p('delete'),
        const _K('end', 'End', 0x4D, 119, name: 'Fine riga', tone: _m),
        _p('pgdn'),
        _gap(0.25),
        const _K('kp7', '7', 0x5F, 89, name: 'Tastierino 7', tone: _kp),
        const _K('kp8', '8', 0x60, 91, name: 'Tastierino 8', tone: _kp),
        const _K('kp9', '9', 0x61, 92, name: 'Tastierino 9', tone: _kp),
        const _K('kpplus', '+', 0x57, 69, h: 2, name: 'Tastierino +', tone: _kp),
      ],
    ),
    (
      3.25,
      [
        _p('caps', w: 1.75),
        for (final l in letters2) _p(l),
        _p('semicolon'),
        _p('quote'),
        _p('enter', w: 2.25),
        _gap(3.5),
        const _K('kp4', '4', 0x5C, 86, name: 'Tastierino 4', tone: _kp),
        const _K('kp5', '5', 0x5D, 87, name: 'Tastierino 5', tone: _kp),
        const _K('kp6', '6', 0x5E, 88, name: 'Tastierino 6', tone: _kp),
      ],
    ),
    (
      4.25,
      [
        _p('lshift', w: 2.25),
        for (final l in letters3) _p(l),
        _p('comma'),
        _p('period'),
        _p('slash'),
        _p('rshift', w: 2.75),
        _gap(1.25),
        _p('up'),
        _gap(1.25),
        const _K('kp1', '1', 0x59, 83, name: 'Tastierino 1', tone: _kp),
        const _K('kp2', '2', 0x5A, 84, name: 'Tastierino 2', tone: _kp),
        const _K('kp3', '3', 0x5B, 85, name: 'Tastierino 3', tone: _kp),
        const _K('kpenter', 'Ent', 0x58, 76, h: 2, name: 'Invio del tastierino', tone: _m),
      ],
    ),
    (
      5.25,
      [
        _p('lctrl', w: 1.25),
        _p('lgui', w: 1.25),
        _p('lalt', w: 1.25),
        _p('space', w: 6.25),
        _p('ralt', w: 1.25),
        const _K('rgui', 'Win', 0xE7, 54, w: 1.25, shift: '⌘', name: 'Win destro (⌘ sul Mac)', tone: _m),
        const _K('menu', 'Menu', 0x65, 110, w: 1.25, name: 'Tasto menu', tone: _m),
        _p('rctrl', w: 1.25),
        _gap(0.25),
        _p('left'),
        _p('down'),
        _p('right'),
        _gap(0.25),
        const _K('kp0', '0', 0x62, 82, w: 2, name: 'Tastierino 0', tone: _kp),
        const _K('kpdot', '.', 0x63, 65, name: 'Tastierino .', tone: _kp),
      ],
    ),
  ]);
}

// ---------------------------------------------------------------------------
// Mouse da gioco (disegnato in uno spazio 300 × 460 punti)
// ---------------------------------------------------------------------------

const _dpiNote =
    'Su molti mouse da gioco questo tasto cambia i DPI dentro al mouse e non arriva al Mac. '
    'Se si accende quando lo premi, puoi usarlo. Con il programma del produttore (es. G HUB) '
    'puoi impostarlo una volta come "pulsante" e salvarlo nella memoria del mouse.';

const _mouseButtons = <KeyDef>[
  KeyDef(
    id: 'm-left',
    label: 'Sinistro',
    name: 'Click sinistro',
    hid: 1,
    mac: 0,
    x: 72,
    y: 24,
    w: 74,
    h: 168,
    firmware: true,
  ),
  KeyDef(id: 'm-right', label: 'Destro', name: 'Click destro', hid: 2, mac: 1, x: 154, y: 24, w: 96, h: 168),
  KeyDef(id: 'm-middle', label: 'Rotella', name: 'Click della rotella', hid: 3, mac: 2, x: 137, y: 46, w: 26, h: 76),
  KeyDef(
    id: 'm-9',
    label: 'G9',
    name: 'Tasto dietro la rotella',
    hid: 9,
    mac: 8,
    x: 139,
    y: 132,
    w: 22,
    h: 26,
    note: _dpiNote,
  ),
  KeyDef(id: 'm-dpiup', label: 'DPI+', name: 'Tasto DPI +', hid: 8, mac: 7, x: 44, y: 46, w: 24, h: 40, note: _dpiNote),
  KeyDef(
    id: 'm-dpidown',
    label: 'DPI−',
    name: 'Tasto DPI −',
    hid: 7,
    mac: 6,
    x: 44,
    y: 92,
    w: 24,
    h: 40,
    note: _dpiNote,
  ),
  KeyDef(
    id: 'm-sniper',
    label: 'Sniper',
    name: 'Tasto sniper (pollice)',
    hid: 6,
    mac: 5,
    x: 2,
    y: 198,
    w: 30,
    h: 36,
    note: _dpiNote,
  ),
  KeyDef(id: 'm-forward', label: 'Avanti', name: 'Avanti (laterale)', hid: 5, mac: 4, x: 4, y: 248, w: 28, h: 46),
  KeyDef(id: 'm-back', label: 'Indietro', name: 'Indietro (laterale)', hid: 4, mac: 3, x: 4, y: 300, w: 28, h: 46),
];

// ---------------------------------------------------------------------------
// Registro dei layout
// ---------------------------------------------------------------------------

class Layout {
  Layout({
    required this.id,
    required this.name,
    required this.kind,
    required this.keys,
    required this.width,
    required this.height,
    this.decorated = false,
  }) : _byId = {for (final k in keys) k.id: k};

  final String id;
  final String name;
  final DeviceKind kind;
  final List<KeyDef> keys;

  /// In unità per le tastiere, in punti per il mouse.
  final double width;
  final double height;

  /// Colori e grafica della SOLIDEE.
  final bool decorated;

  final Map<String, KeyDef> _byId;

  KeyDef? byId(String id) => _byId[id];
  bool get isMouse => kind == DeviceKind.mouse;
}

class Layouts {
  Layouts._();

  static final solidee65 = Layout(
    id: 'solidee65',
    name: '65% · 68 tasti',
    kind: DeviceKind.keyboard,
    keys: _place([for (var y = 0; y < _solideeRows.length; y++) (y.toDouble(), _solideeRows[y])]),
    width: 16,
    height: 5,
    decorated: true,
  );

  static final ansi = Layout(
    id: 'ansi',
    name: 'Standard · 104 tasti',
    kind: DeviceKind.keyboard,
    keys: _buildAnsi(),
    width: 22.5,
    height: 6.25,
  );

  static final mouse = Layout(
    id: 'mouse',
    name: 'Mouse',
    kind: DeviceKind.mouse,
    keys: _mouseButtons,
    width: 300,
    height: 460,
  );

  static final all = [solidee65, ansi, mouse];
  static final keyboards = [solidee65, ansi];

  static Layout byId(String id) => all.firstWhere((l) => l.id == id, orElse: () => ansi);

  /// Un tasto da usare come destinazione (Altro tasto, Scorciatoia).
  /// La tastiera standard li ha tutti: F1–F12, Home, End, tastierino…
  static KeyDef? target(String id) => ansi.byId(id) ?? solidee65.byId(id);

  /// Dal tasto fisico premuto (PhysicalKeyboardKey.usbHidUsage) al tasto.
  static KeyDef? byFlutterUsage(int usage) => _byUsage[usage];

  static final Map<int, KeyDef> _byUsage = {
    for (final k in [...solidee65.keys, ...ansi.keys])
      if (k.hid != 0) k.flutterUsage: k,
  };

  /// Tabella HID → keycode Mac, per il motore (riconoscere da quale tastiera arriva un tasto).
  static Map<String, int> get hidToMac => {
    for (final k in [...ansi.keys, ...solidee65.keys])
      if (k.hid != 0) '${k.hid}': k.mac,
  };

  /// Indovina il layout di una tastiera dal nome che dà a macOS.
  /// Tutto quello che non sembra una 65% usa la tastiera standard.
  static Layout guess(String name) {
    final n = name.toLowerCase();
    if (n.contains('solidee') || RegExp(r'(^|\D)(65|68)(%|\D|$)').hasMatch(n)) return solidee65;
    return ansi;
  }
}
