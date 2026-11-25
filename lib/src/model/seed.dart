import 'actions.dart';
import 'device.dart';
import 'keyboard.dart';
import 'profile.dart';

KeyDef _k(String id) => Layouts.target(id)!;

/// Versione dei comandi personali: aumentala quando aggiungi comandi qui sotto,
/// così Tocco li aggiunge anche a chi ha già le impostazioni salvate.
const presetsVersion = 1;

/// Indirizzo di Home Assistant su Jarvis via Tailscale: funziona da casa e da fuori.
const _jarvis = 'https://jarvis.tail370cac.ts.net:9443';

/// I comandi di Francesco, su tutte le tastiere.
///
/// Tieni premuto **Shift destro** (c'è su tutte, SOLIDEE compresa) e premi:
/// - G → Gestionale
/// - E → mail del Gestionale
/// - C → Claude in Safari
/// - T → 10FastFingers in Safari
/// - A → Gestione inserzioni di Meta
/// - L → luci di casa (Home Assistant su Jarvis)
/// - M → Musica
///
/// Se un tasto è già usato, non lo sovrascrive.
void addPersonalPresets(Profile global) {
  const d = allKeyboardsId;
  void put(int layer, String key, KeyBinding b) {
    if (global.binding(d, layer, key) == null) global.setBinding(d, layer, key, b);
  }

  put(0, 'rshift', const KeyBinding(hold: LayerAction(1)));
  put(1, 'g', const KeyBinding(tap: OpenUrlAction('https://gestionale.francescoferri.me')));
  put(1, 'e', const KeyBinding(tap: OpenUrlAction('https://gestionale.francescoferri.me/mail')));
  put(1, 'c', const KeyBinding(tap: OpenUrlAction('https://claude.ai/new', browser: OpenUrlAction.safari)));
  put(
    1,
    't',
    const KeyBinding(
      tap: OpenUrlAction('https://10fastfingers.com/typing-test/italian', browser: OpenUrlAction.safari),
    ),
  );
  put(1, 'a', const KeyBinding(tap: OpenUrlAction('https://adsmanager.facebook.com/adsmanager/manage/campaigns')));
  put(1, 'l', const KeyBinding(tap: WebhookAction('Luci di casa', '$_jarvis/api/webhook/tocco_luci')));
  put(1, 'm', const KeyBinding(tap: OpenAppAction('Musica', '/System/Applications/Music.app')));
}

/// I profili di partenza: esempi da cambiare, non regole.
/// Le tastiere usano "Tutte le tastiere"; [mouse] è l'id del mouse a cui legare gli esempi.
List<Profile> seedProfiles({String? mouse}) {
  const k = allKeyboardsId;
  final global = Profile(id: 'globale', name: 'Globale', global: true);
  final figma =
      Profile(
          id: 'figma',
          name: 'Figma',
          apps: [const AppRef(name: 'Figma', bundleId: 'com.figma.Desktop', path: '/Applications/Figma.app')],
        )
        ..setBinding(k, 0, 'pgup', KeyBinding(tap: ShortcutAction({Mod.cmd}, _k('z'))))
        ..setBinding(k, 0, 'pgdn', KeyBinding(tap: ShortcutAction({Mod.cmd, Mod.shift}, _k('z'))));
  final code =
      Profile(
          id: 'vscode',
          name: 'VS Code',
          apps: [
            const AppRef(
              name: 'Visual Studio Code',
              bundleId: 'com.microsoft.VSCode',
              path: '/Applications/Visual Studio Code.app',
            ),
          ],
        )
        ..setBinding(k, 0, 'pgup', KeyBinding(tap: ShortcutAction({Mod.cmd}, _k('p'))))
        ..setBinding(k, 0, 'pgdn', KeyBinding(tap: ShortcutAction({Mod.cmd, Mod.shift}, _k('f'))));
  final games = Profile(id: 'giochi', name: 'Giochi')
    ..setBinding(k, 0, 'caps', const KeyBinding(tap: DisabledAction()));

  if (mouse != null) {
    final m = mouse;
    global
      // Indietro e Avanti funzionano ovunque (Finder, Safari, Impostazioni…).
      ..setBinding(m, 0, 'm-back', KeyBinding(tap: ShortcutAction({Mod.cmd}, _k('lbracket'))))
      ..setBinding(m, 0, 'm-forward', KeyBinding(tap: ShortcutAction({Mod.cmd}, _k('rbracket'))))
      // Tasto sniper: Mission Control.
      ..setBinding(m, 0, 'm-sniper', KeyBinding(tap: ShortcutAction({Mod.ctrl}, _k('up'))));
    figma
      ..setBinding(m, 0, 'm-back', KeyBinding(tap: ShortcutAction({Mod.cmd}, _k('z'))))
      ..setBinding(m, 0, 'm-forward', KeyBinding(tap: ShortcutAction({Mod.cmd, Mod.shift}, _k('z'))));
  }

  return [global, figma, code, games];
}
