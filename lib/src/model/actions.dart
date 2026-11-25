import 'keyboard.dart';

/// I quattro modificatori del Mac, nell'ordine in cui macOS li scrive.
enum Mod {
  ctrl('⌃', 'Control'),
  opt('⌥', 'Option'),
  shift('⇧', 'Shift'),
  cmd('⌘', 'Command');

  const Mod(this.symbol, this.label);
  final String symbol;
  final String label;

  static String symbols(Iterable<Mod> mods) => Mod.values.where(mods.contains).map((m) => m.symbol).join();
}

enum MediaKey {
  playPause('Play / Pausa', 'PLAY'),
  next('Brano successivo', 'NEXT'),
  previous('Brano precedente', 'PREV'),
  volumeUp('Volume +', 'VOL+'),
  volumeDown('Volume −', 'VOL−'),
  mute('Muto', 'MUTO'),
  brightnessUp('Luminosità +', 'LUM+'),
  brightnessDown('Luminosità −', 'LUM−');

  const MediaKey(this.label, this.badge);
  final String label;
  final String badge;
}

/// I tipi di azione, nell'ordine in cui compaiono nel pannello.
enum ActionKind {
  normal('Normale', tap: true),
  remap('Altro tasto', tap: true),
  shortcut('Scorciatoia', tap: true, hold: true),
  text('Testo', tap: true),
  app('Apri app', tap: true),
  url('Link', tap: true),
  media('Media', tap: true),
  webhook('Home Assistant', tap: true),
  layer('Livello', hold: true),
  modifier('Modificatore', hold: true),
  disabled('Disattiva', tap: true);

  const ActionKind(this.label, {this.tap = false, this.hold = false});
  final String label;
  final bool tap;
  final bool hold;
}

sealed class KeyAction {
  const KeyAction();

  ActionKind get kind;

  /// Testo cortissimo da mostrare sul tasto disegnato.
  String get badge;

  /// Frase per la lista delle modifiche.
  String get describe;

  Map<String, Object?> toJson();

  /// Versione per il motore Swift: tutto già tradotto in keycode del Mac.
  Map<String, Object?> toEngine() => toJson();

  static KeyAction? fromJson(Map<String, Object?>? j) {
    if (j == null) return null;
    final mods = {
      for (final m in (j['mods'] as List?)?.cast<String>() ?? const <String>[])
        Mod.values.firstWhere((v) => v.name == m, orElse: () => Mod.cmd),
    };
    switch (j['kind']) {
      case 'remap':
        final k = Layouts.target(j['key'] as String? ?? '');
        return k == null ? null : RemapAction(k);
      case 'shortcut':
        final k = Layouts.target(j['key'] as String? ?? '');
        return k == null ? null : ShortcutAction(mods, k);
      case 'text':
        return TextAction(j['text'] as String? ?? '');
      case 'app':
        return OpenAppAction(j['name'] as String? ?? '', j['path'] as String? ?? '');
      case 'url':
        return OpenUrlAction(j['url'] as String? ?? '');
      case 'media':
        return MediaAction(MediaKey.values.firstWhere((m) => m.name == j['media'], orElse: () => MediaKey.playPause));
      case 'webhook':
        return WebhookAction(j['name'] as String? ?? '', j['url'] as String? ?? '');
      case 'layer':
        return LayerAction((j['layer'] as num?)?.toInt() ?? 1);
      case 'modifier':
        return ModifierAction(mods);
      case 'disabled':
        return const DisabledAction();
    }
    return null;
  }
}

class RemapAction extends KeyAction {
  const RemapAction(this.target);
  final KeyDef target;

  @override
  ActionKind get kind => ActionKind.remap;
  @override
  String get badge => target.label.isEmpty ? '␣' : target.label;
  @override
  String get describe => 'Diventa ${target.displayName}';
  @override
  Map<String, Object?> toJson() => {'kind': 'remap', 'key': target.id};
  @override
  Map<String, Object?> toEngine() => {'kind': 'remap', 'mac': target.mac};
}

class ShortcutAction extends KeyAction {
  const ShortcutAction(this.mods, this.key);
  final Set<Mod> mods;
  final KeyDef key;

  String get combo => '${Mod.symbols(mods)}${key.label.isEmpty ? 'Spazio' : key.label}';

  @override
  ActionKind get kind => ActionKind.shortcut;
  @override
  String get badge => combo;
  @override
  String get describe => 'Scorciatoia $combo';
  @override
  Map<String, Object?> toJson() => {
    'kind': 'shortcut',
    'mods': [for (final m in mods) m.name],
    'key': key.id,
  };
  @override
  Map<String, Object?> toEngine() => {
    'kind': 'shortcut',
    'mods': [for (final m in mods) m.name],
    'mac': key.mac,
  };
}

class TextAction extends KeyAction {
  const TextAction(this.text);
  final String text;

  @override
  ActionKind get kind => ActionKind.text;
  @override
  String get badge => 'TXT';
  @override
  String get describe {
    final t = text.replaceAll('\n', ' ');
    return 'Scrive “${t.length > 28 ? '${t.substring(0, 28)}…' : t}”';
  }

  @override
  Map<String, Object?> toJson() => {'kind': 'text', 'text': text};
}

class OpenAppAction extends KeyAction {
  const OpenAppAction(this.name, this.path);
  final String name;
  final String path;

  @override
  ActionKind get kind => ActionKind.app;
  @override
  String get badge => 'APP';
  @override
  String get describe => name.isEmpty ? 'Apre un\'app' : 'Apre $name';
  @override
  Map<String, Object?> toJson() => {'kind': 'app', 'name': name, 'path': path};
}

class OpenUrlAction extends KeyAction {
  const OpenUrlAction(this.url);
  final String url;

  @override
  ActionKind get kind => ActionKind.url;
  @override
  String get badge => 'URL';
  @override
  String get describe => 'Apre ${url.replaceFirst(RegExp(r'^https?://'), '')}';
  @override
  Map<String, Object?> toJson() => {'kind': 'url', 'url': url};
}

class MediaAction extends KeyAction {
  const MediaAction(this.media);
  final MediaKey media;

  @override
  ActionKind get kind => ActionKind.media;
  @override
  String get badge => media.badge;
  @override
  String get describe => media.label;
  @override
  Map<String, Object?> toJson() => {'kind': 'media', 'media': media.name};
}

/// Chiama un webhook di Home Assistant (es. luci della scrivania su Jarvis).
class WebhookAction extends KeyAction {
  const WebhookAction(this.name, this.url);
  final String name;
  final String url;

  @override
  ActionKind get kind => ActionKind.webhook;
  @override
  String get badge => 'HA';
  @override
  String get describe => name.isEmpty ? 'Webhook Home Assistant' : 'Casa: $name';
  @override
  Map<String, Object?> toJson() => {'kind': 'webhook', 'name': name, 'url': url};
}

/// Solo tenendo premuto: finché il tasto è giù, vale il livello indicato.
class LayerAction extends KeyAction {
  const LayerAction(this.layer);
  final int layer;

  @override
  ActionKind get kind => ActionKind.layer;
  @override
  String get badge => 'L$layer';
  @override
  String get describe => 'Livello $layer';
  @override
  Map<String, Object?> toJson() => {'kind': 'layer', 'layer': layer};
}

/// Solo tenendo premuto: il tasto si comporta come uno o più modificatori.
class ModifierAction extends KeyAction {
  const ModifierAction(this.mods);
  final Set<Mod> mods;

  @override
  ActionKind get kind => ActionKind.modifier;
  @override
  String get badge => Mod.symbols(mods);
  @override
  String get describe => 'Diventa ${Mod.symbols(mods)}';
  @override
  Map<String, Object?> toJson() => {
    'kind': 'modifier',
    'mods': [for (final m in mods) m.name],
  };
}

class DisabledAction extends KeyAction {
  const DisabledAction();

  @override
  ActionKind get kind => ActionKind.disabled;
  @override
  String get badge => '—';
  @override
  String get describe => 'Disattivato';
  @override
  Map<String, Object?> toJson() => {'kind': 'disabled'};
}

/// Cosa fa un tasto in un livello: premuto (tap) e tenuto premuto (hold).
/// tap null = comportamento normale (nei livelli 1 e 2: come nel livello base).
class KeyBinding {
  const KeyBinding({this.tap, this.hold});

  final KeyAction? tap;
  final KeyAction? hold;

  bool get isEmpty => tap == null && hold == null;

  KeyBinding copyWith({KeyAction? tap, KeyAction? hold, bool clearTap = false, bool clearHold = false}) =>
      KeyBinding(tap: clearTap ? null : (tap ?? this.tap), hold: clearHold ? null : (hold ?? this.hold));

  Map<String, Object?> toJson() => {if (tap != null) 'tap': tap!.toJson(), if (hold != null) 'hold': hold!.toJson()};

  Map<String, Object?> toEngine() => {
    if (tap != null) 'tap': tap!.toEngine(),
    if (hold != null) 'hold': hold!.toEngine(),
  };

  static KeyBinding fromJson(Map<String, Object?> j) => KeyBinding(
    tap: KeyAction.fromJson((j['tap'] as Map?)?.cast<String, Object?>()),
    hold: KeyAction.fromJson((j['hold'] as Map?)?.cast<String, Object?>()),
  );
}
