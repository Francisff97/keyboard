import 'package:material_ui/material_ui.dart';

import '../brand.dart';
import '../model/device.dart';
import '../model/keyboard.dart';
import '../model/profile.dart';
import '../state.dart';
import '../widgets.dart';

/// Colonna a sinistra: profili, app in primo piano, tastiera, permessi.
class SidePanel extends StatelessWidget {
  const SidePanel({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final active = state.activeProfile;
    final front = state.frontApp;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        Text('PROFILI', style: FD.displayStyle(28)),
        const SizedBox(height: 20),
        for (final p in state.profiles)
          _ProfileTile(
            profile: p,
            selected: p.id == state.profile.id,
            inUse: p.id == active.id,
            onTap: () => state.selectProfile(p.id),
          ),
        const SizedBox(height: 12),
        FDTextLink(label: '+ Nuovo profilo', onTap: state.addProfile),
        const SizedBox(height: 36),

        const SectionLabel('A', 'In primo piano'),
        Text(front?.name ?? '—', style: const TextStyle(fontSize: 14, color: FD.text)),
        const SizedBox(height: 4),
        Text('→ PROFILO ${active.name.toUpperCase()}', style: FD.monoStyle(size: 9.5, color: FD.accent)),
        const SizedBox(height: 32),

        const SectionLabel('B', 'Dispositivi'),
        for (final d in state.devices)
          _DeviceRow(
            device: d,
            connected: state.isConnected(d),
            onToggle: () => state.setManaged(d, !d.managed),
            onKind: () => state.setKind(d, d.isMouse ? DeviceKind.keyboard : DeviceKind.mouse),
          ),
        const SizedBox(height: 8),
        const Hint(
          'Spunta quelli da personalizzare. Tocco riconosce da solo tastiere e mouse: se sbaglia, cambia il tipo.',
        ),
        const SizedBox(height: 32),

        const SectionLabel('C', 'Permessi'),
        if (!state.status.native)
          const Hint('Anteprima: il motore non risponde, quindi i tasti non cambiano ancora. L\'interfaccia funziona.')
        else ...[
          _PermissionRow(
            label: 'Accessibilità',
            ok: state.status.accessibility,
            onOpen: () => state.engine.openPrivacySettings('accessibility'),
          ),
          _PermissionRow(
            label: 'Monitoraggio input',
            ok: state.status.inputMonitoring,
            onOpen: () => state.engine.openPrivacySettings('inputMonitoring'),
          ),
          if (!state.status.permissionsOk) ...[
            const SizedBox(height: 12),
            FDButton(
              label: 'Chiedi permessi',
              onPressed: () async {
                await state.engine.requestPermissions();
                await state.refreshEngine();
              },
            ),
          ],
        ],
      ],
    );
  }
}

class _ProfileTile extends StatefulWidget {
  const _ProfileTile({required this.profile, required this.selected, required this.inUse, required this.onTap});

  final Profile profile;
  final bool selected;
  final bool inUse;
  final VoidCallback onTap;

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final sub = p.global
        ? 'Ovunque'
        : p.apps.isEmpty
        ? 'Nessuna app'
        : p.apps.map((a) => a.name).join(' · ');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: widget.selected ? FD.surfaceHigh : (_hover ? FD.surface : Colors.transparent),
            border: Border(
              left: BorderSide(color: widget.selected ? FD.accent : FD.line, width: widget.selected ? 2 : 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.selected ? FD.text : FD.text.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        if (widget.inUse) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF4DFF9A), shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(sub.toUpperCase(), overflow: TextOverflow.ellipsis, style: FD.monoStyle(size: 9)),
                  ],
                ),
              ),
              Text(
                p.changeCount.toString().padLeft(2, '0'),
                style: FD.monoStyle(size: 10, color: widget.selected ? FD.accent : FD.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.connected, required this.onToggle, required this.onKind});

  final DeviceConfig device;
  final bool connected;
  final VoidCallback onToggle;
  final VoidCallback onKind;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final selected = d.managed;
    final meta = [
      d.isMouse ? 'Mouse' : (d.layoutId == 'solidee65' ? 'Tastiera 65%' : 'Tastiera'),
      d.id,
      if (d.builtIn) 'Integrata',
      if (!connected) 'Scollegato',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(top: 2),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: selected ? FD.accent : Colors.transparent,
                  border: Border.all(color: selected ? FD.accent : FD.muted),
                ),
                child: selected ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: Text(
                    d.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: connected && selected ? FD.text : FD.muted),
                  ),
                ),
                const SizedBox(height: 3),
                Text(meta.toUpperCase(), style: FD.monoStyle(size: 8.5)),
                const SizedBox(height: 4),
                FDTextLink(label: d.isMouse ? '⇄ È una tastiera' : '⇄ È un mouse', size: 8.5, onTap: onKind),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.ok, required this.onOpen});

  final String label;
  final bool ok;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: ok ? const Color(0xFF4DFF9A) : FD.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: FD.text)),
          ),
          if (!ok) FDTextLink(label: 'Apri', arrow: true, size: 9.5, onTap: onOpen),
        ],
      ),
    );
  }
}
