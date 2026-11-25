import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../brand.dart';
import '../model/keyboard.dart';
import '../model/profile.dart';
import '../state.dart';
import '../widgets.dart';
import 'key_editor.dart';
import 'keyboard_view.dart';
import 'mouse_view.dart';
import 'side_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (!state.loaded) return const SizedBox.shrink();
          // I pulsanti del mouse premuti si accendono sul mouse disegnato.
          return Listener(
            onPointerDown: (e) => state.mouseButtons(e.buttons),
            onPointerUp: (e) => state.mouseButtons(e.buttons),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyS, meta: true): state.apply,
                const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () => state.setLayer(0),
                const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () => state.setLayer(1),
                const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () => state.setLayer(2),
              },
              child: Focus(
                autofocus: true,
                child: Column(
                  children: [
                    _TopBar(state: state, onAbout: () => _showAbout(context)),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 250, child: SidePanel(state: state)),
                          Container(width: 1, color: FD.lineSoft),
                          Expanded(child: _Center(state: state)),
                          Container(width: 1, color: FD.lineSoft),
                          SizedBox(width: 340, child: KeyEditor(state: state)),
                        ],
                      ),
                    ),
                    const _Footer(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => Dialog(
        backgroundColor: FD.surface,
        shape: const RoundedRectangleBorder(side: BorderSide(color: FD.line)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FDLogo(height: 56),
                const SizedBox(height: 28),
                Text('TOCCO', style: FD.displayStyle(44)),
                const SizedBox(height: 8),
                Text('LA TUA TASTIERA, SU MISURA', style: FD.monoStyle(size: 10, color: FD.accent)),
                const SizedBox(height: 24),
                const Text(
                  'Cambia cosa fanno i tasti della tua tastiera meccanica: scorciatoie, testi, app, '
                  'una seconda funzione tenendo premuto e profili diversi per ogni app. '
                  'Le luci e il tasto Fn restano alla tastiera: Tocco lavora sul Mac.',
                  style: TextStyle(fontSize: 14, height: 1.6, color: FD.text),
                ),
                const SizedBox(height: 16),
                Text(
                  'Le impostazioni stanno in ${state.store.path}',
                  style: const TextStyle(fontSize: 12, height: 1.5, color: FD.muted),
                ),
                const SizedBox(height: 28),
                Container(height: 1, color: FD.line),
                const SizedBox(height: 20),
                Text('FATTA DA FRANCESCO FERRI', style: FD.monoStyle(size: 10, color: FD.text)),
                const SizedBox(height: 4),
                const Text(
                  'Designer e sviluppatore web. Todi, Umbria.',
                  style: TextStyle(fontSize: 13, color: FD.muted),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FDButton(label: 'francescoferri.me', onPressed: () => openLink(FDLinks.site)),
                    FDButton(label: 'Scrivimi', onPressed: () => openLink(FDLinks.email)),
                    FDButton(label: 'Chiudi', onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Center extends StatelessWidget {
  const _Center({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = state.profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nome del profilo e azioni.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(p.name.toUpperCase(), overflow: TextOverflow.ellipsis, style: FD.displayStyle(44)),
              ),
              FDTextLink(label: 'Rinomina', onTap: () => _rename(context)),
              if (!p.global) ...[
                const SizedBox(width: 20),
                FDTextLink(label: 'Elimina', onTap: () => _confirmDelete(context)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _AppsRow(state: state, onAdd: () => _addApp(context)),
          const SizedBox(height: 22),

          // Dispositivi gestiti.
          _DevicesRow(state: state),
          const SizedBox(height: 12),

          // Livelli e etichette.
          if (state.device != null)
            Row(
              children: [
                for (var l = 0; l < layerCount; l++) ...[
                  Tooltip(
                    message: '⌘${l + 1}',
                    child: FDChip(
                      label: '${layerNames[l]}${_count(l) > 0 ? '  ${_count(l)}' : ''}',
                      selected: state.layer == l,
                      onTap: () => state.setLayer(l),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (!state.layout.isMouse) ...[
                  Text('ETICHETTE', style: FD.monoStyle(size: 9.5)),
                  const SizedBox(width: 12),
                  FDChip(label: 'US', selected: !state.italianLegends, onTap: () => state.setItalianLegends(false)),
                  const SizedBox(width: 6),
                  FDChip(label: 'ITA', selected: state.italianLegends, onTap: () => state.setItalianLegends(true)),
                ],
              ],
            ),
          const SizedBox(height: 18),

          // Il dispositivo disegnato.
          if (state.device == null)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(border: Border.all(color: FD.line)),
              child: const Hint('Nessun dispositivo attivo. Spunta una tastiera o un mouse nella colonna a sinistra.'),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 10),
              decoration: BoxDecoration(border: Border.all(color: FD.line)),
              child: Column(
                children: [
                  if (state.layout.isMouse) MouseView(state: state, maxHeight: 340) else KeyboardView(state: state),
                  const SizedBox(height: 6),
                  _Legend(mouse: state.layout.isMouse),
                ],
              ),
            ),
          const SizedBox(height: 22),
          Expanded(child: _ChangesList(state: state)),
        ],
      ),
    );
  }

  int _count(int layer) => state.device == null ? 0 : state.profile.layer(state.device!.id, layer).length;

  Future<void> _rename(BuildContext context) async {
    final c = TextEditingController(text: state.profile.name);
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _SmallDialog(
        title: 'Rinomina',
        body: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(fontSize: 16, color: FD.text),
          decoration: fdInput('Nome del profilo'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [FDButton(label: 'Salva', filled: true, onPressed: () => Navigator.of(context).pop(c.text))],
      ),
    );
    if (name != null) state.renameProfile(name);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _SmallDialog(
        title: 'Elimino ${state.profile.name}?',
        body: const Text(
          'Le sue app torneranno a usare il profilo Globale.',
          style: TextStyle(fontSize: 14, height: 1.5, color: FD.muted),
        ),
        actions: [
          FDButton(label: 'Annulla', onPressed: () => Navigator.of(context).pop(false)),
          FDButton(label: 'Elimina', filled: true, onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (ok == true) state.deleteProfile();
  }

  Future<void> _addApp(BuildContext context) async {
    final app = await showDialog<AppRef>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _AddAppDialog(state: state),
    );
    if (app != null) state.addApp(app);
  }
}

class _AppsRow extends StatelessWidget {
  const _AppsRow({required this.state, required this.onAdd});

  final AppState state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = state.profile;
    if (p.global) {
      return Text('VALE OVUNQUE · GLI ALTRI PROFILI CAMBIANO SOLO I TASTI CHE TOCCANO', style: FD.monoStyle(size: 9.5));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('SI ATTIVA IN', style: FD.monoStyle(size: 9.5)),
        const SizedBox(width: 4),
        for (final a in p.apps)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            decoration: BoxDecoration(border: Border.all(color: FD.line)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.name, style: const TextStyle(fontSize: 12, color: FD.text)),
                const SizedBox(width: 8),
                FDTextLink(label: '✕', size: 10, onTap: () => state.removeApp(a)),
              ],
            ),
          ),
        FDTextLink(label: '+ Aggiungi app', onTap: onAdd),
      ],
    );
  }
}

class _DevicesRow extends StatelessWidget {
  const _DevicesRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final d = state.device;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final m in state.managedDevices)
                FDChip(
                  label: '${m.isMouse ? '◉ ' : '⌨ '}${m.shortName}${state.isConnected(m) ? '' : ' · off'}',
                  selected: m.id == d?.id,
                  onTap: () => state.selectDevice(m.id),
                ),
            ],
          ),
        ),
        if (d != null && !d.isMouse) ...[
          const SizedBox(width: 12),
          Text('LAYOUT', style: FD.monoStyle(size: 9.5)),
          const SizedBox(width: 12),
          for (final l in Layouts.keyboards) ...[
            Tooltip(
              message: l.name,
              child: FDChip(
                label: l.id == 'solidee65' ? 'SOLIDEE 65%' : 'Standard',
                selected: d.layoutId == l.id,
                onTap: () => state.setLayout(d, l.id),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({this.mouse = false});

  final bool mouse;

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label, {bool round = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: c, shape: round ? BoxShape.circle : BoxShape.rectangle),
        ),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: FD.monoStyle(size: 9)),
      ],
    );
    return Wrap(
      spacing: 22,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        item(FD.accent, 'Premuto'),
        if (!mouse) item(Solidee.hold, 'Tenuto premuto', round: true),
        item(FD.muted.withValues(alpha: 0.5), 'Dal Globale'),
        item(FD.danger, 'Disattivato'),
      ],
    );
  }
}

class _ChangesList extends StatelessWidget {
  const _ChangesList({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final layout = state.layout;
    final entries = state.currentLayer().entries.where((e) => layout.byId(e.key) != null).toList()
      ..sort((a, b) {
        final ka = layout.byId(a.key)!;
        final kb = layout.byId(b.key)!;
        return (ka.y * 1000 + ka.x).compareTo(kb.y * 1000 + kb.x);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(entries.length.toString().padLeft(2, '0'), 'Modifiche · ${layerNames[state.layer]}'),
        if (entries.isEmpty)
          Hint(
            state.layer == 0
                ? 'Nessun tasto cambiato in questo profilo.'
                : 'Livello vuoto. Per usarlo, dai a un tasto la funzione "tenuto premuto → ${layerNames[state.layer]}".',
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                final k = layout.byId(e.key)!;
                final b = e.value;
                return _ChangeRow(
                  keyLabel: k.label.isEmpty ? 'Spazio' : k.label,
                  name: k.displayName,
                  tap: b.tap?.describe,
                  hold: b.hold?.describe,
                  selected: state.selectedKey?.id == k.id,
                  onTap: () => state.selectKey(k.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ChangeRow extends StatefulWidget {
  const _ChangeRow({
    required this.keyLabel,
    required this.name,
    required this.tap,
    required this.hold,
    required this.selected,
    required this.onTap,
  });

  final String keyLabel;
  final String name;
  final String? tap;
  final String? hold;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ChangeRow> createState() => _ChangeRowState();
}

class _ChangeRowState extends State<_ChangeRow> {
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: widget.selected ? FD.surfaceHigh : (_hover ? FD.surface : Colors.transparent),
            border: const Border(bottom: BorderSide(color: FD.lineSoft)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: FD.line)),
                child: Text(
                  widget.keyLabel.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: FD.monoStyle(size: 9.5, color: FD.text),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 130,
                child: Text(
                  widget.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: FD.muted),
                ),
              ),
              Text('→', style: FD.monoStyle(color: FD.accent)),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (widget.tap != null) TextSpan(text: widget.tap),
                      if (widget.tap != null && widget.hold != null) const TextSpan(text: '   '),
                      if (widget.hold != null)
                        TextSpan(
                          text: 'tenuto: ${widget.hold}',
                          style: const TextStyle(color: Solidee.hold),
                        ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: FD.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallDialog extends StatelessWidget {
  const _SmallDialog({required this.title, required this.body, required this.actions});

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: FD.surface,
      shape: const RoundedRectangleBorder(side: BorderSide(color: FD.line)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title.toUpperCase(), style: FD.displayStyle(32)),
              const SizedBox(height: 20),
              body,
              const SizedBox(height: 28),
              Wrap(alignment: WrapAlignment.end, spacing: 12, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAppDialog extends StatefulWidget {
  const _AddAppDialog({required this.state});

  final AppState state;

  @override
  State<_AddAppDialog> createState() => _AddAppDialogState();
}

class _AddAppDialogState extends State<_AddAppDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final front = s.frontApp;
    final apps = s.installedApps.where((a) => a.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return _SmallDialog(
      title: 'Aggiungi app',
      actions: [FDButton(label: 'Chiudi', onPressed: () => Navigator.of(context).pop())],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            autofocus: true,
            style: const TextStyle(fontSize: 14, color: FD.text),
            decoration: fdInput('Cerca tra le app installate'),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 12),
          Container(
            height: 280,
            decoration: BoxDecoration(border: Border.all(color: FD.line)),
            child: ListView(
              children: [
                if (front != null && _q.isEmpty && !apps.contains(front))
                  AppRow(app: front, trailing: 'in primo piano', onTap: () => Navigator.of(context).pop(front)),
                for (final a in apps)
                  AppRow(
                    app: a,
                    trailing: switch (s.ownerOf(a)) {
                      final o? when o.id == s.profile.id => 'già qui',
                      final o? => o.name,
                      null => null,
                    },
                    onTap: () => Navigator.of(context).pop(a),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Hint('Se un\'app è già in un altro profilo, si sposta qui.'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onAbout});

  final AppState state;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final managed = state.managedDevices;
    final online = managed.where(state.isConnected).length;
    final label = managed.isEmpty
        ? 'Nessun dispositivo'
        : '$online di ${managed.length} ${managed.length == 1 ? 'dispositivo collegato' : 'dispositivi collegati'}';
    return Container(
      height: 64,
      padding: EdgeInsets.only(left: Platform.isMacOS ? 88 : 28, right: 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FD.lineSoft)),
      ),
      child: Row(
        children: [
          const ToccoIcon(size: 28),
          const SizedBox(width: 14),
          Text('TOCCO', style: FD.displayStyle(24)),
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: FD.line),
          const SizedBox(width: 16),
          Expanded(
            child: Text('LA TUA TASTIERA, SU MISURA', style: FD.monoStyle(size: 10), overflow: TextOverflow.ellipsis),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: online > 0 ? const Color(0xFF4DFF9A) : FD.muted, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(label.toUpperCase(), style: FD.monoStyle(size: 10, color: FD.text)),
          const SizedBox(width: 28),
          SizedBox(
            width: 150,
            child: FDToggle(
              label: state.enabled ? 'Motore attivo' : 'Motore in pausa',
              value: state.enabled,
              onChanged: state.setEnabled,
            ),
          ),
          const SizedBox(width: 20),
          FDTextLink(label: 'Info', onTap: onAbout),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: FD.lineSoft)),
      ),
      child: Row(
        children: [
          FDTextLink(label: '© ${DateTime.now().year} Francesco Design', size: 10, onTap: () => openLink(FDLinks.site)),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
              'Gratis. Nessun account. I tuoi tasti restano sul tuo Mac.',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: FD.muted),
            ),
          ),
          for (final social in FDLinks.socials) ...[
            const SizedBox(width: 18),
            FDTextLink(label: social.label, size: 10, onTap: () => openLink(social.uri)),
          ],
          const SizedBox(width: 18),
          Container(width: 1, height: 14, color: FD.line),
          const SizedBox(width: 18),
          FDTextLink(label: 'francescoferri.me', size: 10, arrow: true, onTap: () => openLink(FDLinks.site)),
        ],
      ),
    );
  }
}
