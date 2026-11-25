import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../brand.dart';
import '../model/actions.dart';
import '../model/keyboard.dart';
import '../model/profile.dart';
import '../state.dart';
import '../widgets.dart';

/// Il pannello a destra: cosa fa il tasto selezionato.
class KeyEditor extends StatelessWidget {
  const KeyEditor({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final k = state.selectedKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: k == null
                ? const _Empty(key: ValueKey('empty'))
                : _Editor(key: ValueKey('${k.id}-${state.layer}-${state.profile.id}'), state: state, k: k),
          ),
        ),
        _ApplyBar(state: state),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('00 — INIZIA', style: FD.monoStyle(size: 10, color: FD.accent)),
          const SizedBox(height: 18),
          Text('SCEGLI\nUN TASTO', style: FD.displayStyle(64)),
          const SizedBox(height: 20),
          const Text(
            'Clicca un tasto sulla tastiera disegnata e decidi cosa fa: un altro tasto, una scorciatoia, un testo, un\'app. '
            'Puoi dargli anche una seconda funzione quando lo tieni premuto.',
            style: TextStyle(fontSize: 14, height: 1.55, color: FD.muted),
          ),
          const SizedBox(height: 16),
          const Hint('Premi i tasti della SOLIDEE: si accendono anche qui.'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({super.key, required this.state, required this.k});

  final AppState state;
  final KeyDef k;

  @override
  Widget build(BuildContext context) {
    final binding = state.bindingFor(k.id);
    final inh = binding == null ? state.inheritance(k.id) : null;
    final inherited = inh?.binding;
    final tap = binding?.tap;
    final hold = binding?.hold;
    final tapKind = tap?.kind ?? ActionKind.normal;
    final mouse = state.layout.isMouse;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(k.displayName.toUpperCase(), style: FD.displayStyle(34))),
            const SizedBox(width: 12),
            FDTextLink(label: '✕', size: 12, onTap: () => state.selectKey(null)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          mouse
              ? 'PULSANTE ${k.mac + 1} · ${state.device?.shortName.toUpperCase()} · ${layerNames[state.layer].toUpperCase()}'
              : 'HID 0x${k.hid.toRadixString(16).padLeft(2, '0').toUpperCase()} · MAC ${k.mac} · ${layerNames[state.layer].toUpperCase()}',
          style: FD.monoStyle(size: 9.5),
        ),
        if (k.note != null) ...[const SizedBox(height: 16), _Note(k.note!)],
        if (k.specialNote != null) ...[const SizedBox(height: 16), _Note(k.specialNote!)],
        if (k.unsupported) ...[
          const SizedBox(height: 16),
          const _Note(
            'Per ora i modificatori di sinistra non si possono cambiare: macOS li gestisce in modo speciale. '
            'Usa quelli di destra, oppure Caps Lock.',
          ),
        ] else ...[
          if (inherited != null) ...[
            const SizedBox(height: 16),
            _Note(
              'Da ${inh!.from}: ${[if (inherited.tap != null) inherited.tap!.describe, if (inherited.hold != null) 'tenuto ${inherited.hold!.describe}'].join(', ')}. '
              'Se lo cambi qui, vale solo per ${state.device?.shortName} nel profilo ${state.profile.name}.',
            ),
          ],
          const SizedBox(height: 28),

          const SectionLabel('01', 'Quando lo premi'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in ActionKind.values.where((a) => a.tap))
                FDChip(
                  label: kind.label,
                  selected: tapKind == kind,
                  onTap: () => state.setTap(_defaultFor(kind, state)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _TapEditor(state: state, k: k, action: tap),
          const SizedBox(height: 36),

          if (!mouse) ...[
            const SectionLabel('02', 'Quando lo tieni premuto'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FDChip(label: 'Niente', selected: hold == null, onTap: () => state.setHold(null)),
                for (final kind in ActionKind.values.where((a) => a.hold))
                  FDChip(
                    label: kind.label,
                    selected: hold?.kind == kind,
                    onTap: () => state.setHold(_defaultFor(kind, state)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _HoldEditor(state: state, action: hold),
            const SizedBox(height: 32),
          ],
        ],
        if (binding != null)
          Align(
            alignment: Alignment.centerLeft,
            child: FDTextLink(label: '↺ Ripristina tasto', onTap: state.resetKey),
          ),
      ],
    );
  }

  static KeyAction? _defaultFor(ActionKind kind, AppState s) {
    final esc = Layouts.target('esc')!;
    return switch (kind) {
      ActionKind.normal => null,
      ActionKind.remap => RemapAction(esc),
      ActionKind.shortcut => ShortcutAction({Mod.cmd}, Layouts.target('z')!),
      ActionKind.text => const TextAction(''),
      ActionKind.app => const OpenAppAction('', ''),
      ActionKind.url => const OpenUrlAction('https://'),
      ActionKind.media => const MediaAction(MediaKey.playPause),
      ActionKind.webhook => const WebhookAction('', 'http://jarvis.local:8123/api/webhook/'),
      ActionKind.layer => LayerAction(s.layer == 1 ? 2 : 1),
      ActionKind.modifier => const ModifierAction({Mod.ctrl}),
      ActionKind.disabled => const DisabledAction(),
    };
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FD.accent.withValues(alpha: 0.06),
        border: Border.all(color: FD.accent.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, height: 1.45, color: FD.text)),
    );
  }
}

// ---------------------------------------------------------------------------
// Premuto
// ---------------------------------------------------------------------------

class _TapEditor extends StatelessWidget {
  const _TapEditor({required this.state, required this.k, required this.action});

  final AppState state;
  final KeyDef k;
  final KeyAction? action;

  @override
  Widget build(BuildContext context) {
    final a = action;
    switch (a) {
      case null:
        return Hint(
          state.layer == 0
              ? 'Fa quello che c\'è scritto sopra: ${k.displayName}.'
              : 'Trasparente: in questo livello fa quello che fa nel livello Base.',
        );
      case RemapAction():
        return _KeyPicker(
          label: 'Diventa',
          value: a.target,
          presets: const [
            'esc',
            'enter',
            'backspace',
            'delete',
            'tab',
            'home',
            'end',
            'pgup',
            'pgdn',
            'f1',
            'f5',
            'f12',
          ],
          onPick: (t) => state.setTap(RemapAction(t)),
        );
      case ShortcutAction():
        return _ShortcutEditor(action: a, onChanged: state.setTap, mouse: state.layout.isMouse);
      case TextAction():
        return _TextEditor(
          initial: a.text,
          hint: 'es. info@francescoferri.me',
          lines: 4,
          help: 'Lo scrive al posto tuo, dove c\'è il cursore. Va bene per firme, indirizzi, risposte tipo ai clienti.',
          onChanged: (v) => state.setTap(TextAction(v)),
        );
      case OpenAppAction():
        return _AppPicker(
          apps: state.installedApps,
          selected: a.path,
          onPick: (app) => state.setTap(OpenAppAction(app.name, app.path)),
        );
      case OpenUrlAction():
        OpenUrlAction current() => (state.bindingFor(k.id)?.tap as OpenUrlAction?) ?? a;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TextEditor(
              initial: a.url,
              hint: 'https://',
              mono: true,
              help: 'Va bene anche un link a una cartella o un file (file://).',
              onChanged: (v) => state.setTap(OpenUrlAction(v.trim(), browser: current().browser)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                FDChip(
                  label: 'Browser predefinito',
                  selected: a.browser.isEmpty,
                  onTap: () => state.setTap(OpenUrlAction(current().url)),
                ),
                FDChip(
                  label: 'Safari',
                  selected: a.browser == OpenUrlAction.safari,
                  onTap: () => state.setTap(OpenUrlAction(current().url, browser: OpenUrlAction.safari)),
                ),
              ],
            ),
          ],
        );
      case MediaAction():
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in MediaKey.values)
              FDChip(label: m.label, selected: a.media == m, onTap: () => state.setTap(MediaAction(m))),
          ],
        );
      case WebhookAction():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TextEditor(
              initial: a.name,
              hint: 'Nome, es. Luci scrivania',
              onChanged: (v) =>
                  state.setTap(WebhookAction(v, (state.bindingFor(k.id)?.tap as WebhookAction?)?.url ?? a.url)),
            ),
            const SizedBox(height: 8),
            _TextEditor(
              initial: a.url,
              hint: 'http://jarvis.local:8123/api/webhook/…',
              mono: true,
              help:
                  'In Home Assistant crea un\'automazione con attivazione "Webhook" e incolla qui il suo indirizzo. '
                  'Il tasto manda una richiesta POST.',
              onChanged: (v) => state.setTap(
                WebhookAction((state.bindingFor(k.id)?.tap as WebhookAction?)?.name ?? a.name, v.trim()),
              ),
            ),
          ],
        );
      case DisabledAction():
        return const Hint('Il tasto non fa niente. Utile nei giochi per il tasto Win o per Caps Lock.');
      case LayerAction() || ModifierAction():
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Tenuto premuto
// ---------------------------------------------------------------------------

class _HoldEditor extends StatelessWidget {
  const _HoldEditor({required this.state, required this.action});

  final AppState state;
  final KeyAction? action;

  @override
  Widget build(BuildContext context) {
    final a = action;
    switch (a) {
      case null:
        return const Hint(
          'Dagli una seconda funzione: premuto fa una cosa, tenuto premuto un\'altra. '
          'Esempio: Caps Lock premuto è Esc, tenuto apre il livello 1 con le frecce su IJKL.',
        );
      case LayerAction():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final l in [1, 2])
                  FDChip(label: layerNames[l], selected: a.layer == l, onTap: () => state.setHold(LayerAction(l))),
              ],
            ),
            const SizedBox(height: 10),
            const Hint('Finché lo tieni giù, la tastiera usa quel livello. Lo lasci e torna normale.'),
          ],
        );
      case ModifierAction():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModToggles(mods: a.mods, onChanged: (m) => state.setHold(ModifierAction(m))),
            const SizedBox(height: 10),
            const Hint('Tenuto premuto si comporta come questi tasti insieme.'),
          ],
        );
      case ShortcutAction():
        return _ShortcutEditor(action: a, onChanged: state.setHold, mouse: state.layout.isMouse);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Controlli
// ---------------------------------------------------------------------------

class _ModToggles extends StatelessWidget {
  const _ModToggles({required this.mods, required this.onChanged});

  final Set<Mod> mods;
  final ValueChanged<Set<Mod>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final m in Mod.values)
          Tooltip(
            message: m.label,
            child: FDChip(
              label: m.symbol,
              selected: mods.contains(m),
              onTap: () {
                final next = {...mods};
                next.contains(m) ? next.remove(m) : next.add(m);
                onChanged(next);
              },
            ),
          ),
      ],
    );
  }
}

class _ShortcutEditor extends StatelessWidget {
  const _ShortcutEditor({required this.action, required this.onChanged, this.mouse = false});

  final ShortcutAction action;
  final ValueChanged<KeyAction> onChanged;
  final bool mouse;

  /// Comode soprattutto sui tasti laterali del mouse.
  static final _navigation = <(String, Set<Mod>, String)>[
    ('Indietro', {Mod.cmd}, 'lbracket'),
    ('Avanti', {Mod.cmd}, 'rbracket'),
    ('Mission Control', {Mod.ctrl}, 'up'),
    ('Desktop ←', {Mod.ctrl}, 'left'),
    ('Desktop →', {Mod.ctrl}, 'right'),
    ('Tab precedente', {Mod.cmd, Mod.shift}, 'lbracket'),
    ('Tab successiva', {Mod.cmd, Mod.shift}, 'rbracket'),
  ];

  static final _presets = <(String, Set<Mod>, String)>[
    ('Annulla', {Mod.cmd}, 'z'),
    ('Ripeti', {Mod.cmd, Mod.shift}, 'z'),
    ('Copia', {Mod.cmd}, 'c'),
    ('Incolla', {Mod.cmd}, 'v'),
    ('Salva', {Mod.cmd}, 's'),
    ('Screenshot', {Mod.cmd, Mod.shift}, '4'),
    ('Spotlight', {Mod.cmd}, 'space'),
    ('Chiudi', {Mod.cmd}, 'w'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FD.surface,
            border: Border.all(color: FD.line),
          ),
          child: Text(
            action.combo,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w500, letterSpacing: 6, color: FD.text),
          ),
        ),
        const SizedBox(height: 14),
        _ModToggles(mods: action.mods, onChanged: (m) => onChanged(ShortcutAction(m, action.key))),
        const SizedBox(height: 14),
        _KeyPicker(
          label: 'Tasto',
          value: action.key,
          recordMods: true,
          onPick: (k) => onChanged(ShortcutAction(action.mods, k)),
          onPickCombo: (mods, k) => onChanged(ShortcutAction(mods, k)),
        ),
        const SizedBox(height: 18),
        Text('PRONTE', style: FD.monoStyle(size: 9.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, mods, id) in mouse ? [..._navigation, ..._presets] : [..._presets, ..._navigation])
              FDChip(
                label: label,
                selected: action.key.id == id && action.mods.length == mods.length && action.mods.containsAll(mods),
                onTap: () => onChanged(ShortcutAction(mods, Layouts.target(id)!)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Scegli un tasto premendolo davvero, o da una lista di quelli più usati.
class _KeyPicker extends StatefulWidget {
  const _KeyPicker({
    required this.label,
    required this.value,
    required this.onPick,
    this.presets = const [],
    this.recordMods = false,
    this.onPickCombo,
  });

  final String label;
  final KeyDef value;
  final List<String> presets;
  final bool recordMods;
  final ValueChanged<KeyDef> onPick;
  final void Function(Set<Mod> mods, KeyDef key)? onPickCombo;

  @override
  State<_KeyPicker> createState() => _KeyPickerState();
}

class _KeyPickerState extends State<_KeyPicker> {
  final _focus = FocusNode();
  bool _listening = false;

  static const _modifierIds = {'lshift', 'rshift', 'lctrl', 'rctrl', 'lalt', 'ralt', 'lgui', 'rgui'};

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (!_listening || e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = Layouts.byFlutterUsage(e.physicalKey.usbHidUsage);
    if (k == null) return KeyEventResult.handled;
    // Nelle scorciatoie i modificatori da soli non chiudono la registrazione.
    if (widget.recordMods && _modifierIds.contains(k.id)) return KeyEventResult.handled;
    final hw = HardwareKeyboard.instance;
    final mods = <Mod>{
      if (hw.isMetaPressed) Mod.cmd,
      if (hw.isAltPressed) Mod.opt,
      if (hw.isControlPressed) Mod.ctrl,
      if (hw.isShiftPressed) Mod.shift,
    };
    if (widget.recordMods && mods.isNotEmpty && widget.onPickCombo != null) {
      widget.onPickCombo!(mods, k);
    } else {
      widget.onPick(k);
    }
    setState(() => _listening = false);
    _focus.unfocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          onFocusChange: (f) {
            if (!f && _listening) setState(() => _listening = false);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() => _listening = !_listening);
                _listening ? _focus.requestFocus() : _focus.unfocus();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _listening ? FD.accent.withValues(alpha: 0.08) : Colors.transparent,
                  border: Border.all(color: _listening ? FD.accent : FD.line),
                ),
                child: Row(
                  children: [
                    Text(widget.label.toUpperCase(), style: FD.monoStyle(size: 9.5)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _listening ? 'Premi un tasto…' : (v.label.isEmpty ? 'Spazio' : v.displayName),
                        style: TextStyle(fontSize: 14, color: _listening ? FD.accent : FD.text),
                      ),
                    ),
                    Text(_listening ? 'CLICCA PER USCIRE' : 'REGISTRA', style: FD.monoStyle(size: 9, color: FD.accent)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.presets.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in widget.presets)
                if (Layouts.target(id) case final p?)
                  FDChip(label: p.label, selected: v.id == id, onTap: () => widget.onPick(p)),
            ],
          ),
        ],
      ],
    );
  }
}

class _TextEditor extends StatefulWidget {
  const _TextEditor({
    required this.initial,
    required this.hint,
    required this.onChanged,
    this.help,
    this.lines = 1,
    this.mono = false,
  });

  final String initial;
  final String hint;
  final String? help;
  final int lines;
  final bool mono;
  final ValueChanged<String> onChanged;

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          minLines: widget.lines,
          maxLines: widget.lines == 1 ? 1 : 8,
          style: widget.mono
              ? FD.monoStyle(size: 12, color: FD.text).copyWith(letterSpacing: 0.5)
              : const TextStyle(fontSize: 14, color: FD.text),
          decoration: fdInput(widget.hint, mono: widget.mono),
          onChanged: widget.onChanged,
        ),
        if (widget.help != null) ...[const SizedBox(height: 10), Hint(widget.help!)],
      ],
    );
  }
}

class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.apps, required this.selected, required this.onPick});

  final List<AppRef> apps;
  final String selected;
  final ValueChanged<AppRef> onPick;

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.apps.where((a) => a.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          style: const TextStyle(fontSize: 14, color: FD.text),
          decoration: fdInput('Cerca un\'app'),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 10),
        Container(
          height: 200,
          decoration: BoxDecoration(border: Border.all(color: FD.line)),
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) =>
                AppRow(app: list[i], selected: list[i].path == widget.selected, onTap: () => widget.onPick(list[i])),
          ),
        ),
      ],
    );
  }
}

/// Riga di una lista di app, usata qui e nel pannello profili.
class AppRow extends StatefulWidget {
  const AppRow({super.key, required this.app, required this.onTap, this.selected = false, this.trailing});

  final AppRef app;
  final VoidCallback onTap;
  final bool selected;
  final String? trailing;

  @override
  State<AppRow> createState() => _AppRowState();
}

class _AppRowState extends State<AppRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: widget.selected ? FD.accent.withValues(alpha: 0.15) : (_hover ? FD.surfaceHigh : Colors.transparent),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.app.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: widget.selected ? FD.text : FD.text.withValues(alpha: 0.85)),
                ),
              ),
              if (widget.trailing != null) Text(widget.trailing!.toUpperCase(), style: FD.monoStyle(size: 9)),
              if (widget.selected) const Icon(Icons.check, size: 14, color: FD.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final last = state.lastApplied;
    final note = state.dirty
        ? 'Modifiche non ancora applicate'
        : last == null
        ? 'Niente da applicare'
        : 'Applicato alle ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: FD.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(note.toUpperCase(), style: FD.monoStyle(size: 9.5, color: state.dirty ? FD.accent : FD.muted)),
          const SizedBox(height: 12),
          FDButton(
            label: 'Salva e applica',
            icon: Icons.arrow_forward,
            filled: true,
            big: true,
            onPressed: state.dirty ? state.apply : null,
          ),
        ],
      ),
    );
  }
}
