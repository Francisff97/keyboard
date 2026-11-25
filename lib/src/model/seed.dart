import 'actions.dart';
import 'keyboard.dart';
import 'profile.dart';

KeyDef _k(String id) => Layouts.target(id)!;

/// I profili di partenza: esempi da cambiare, non regole.
/// [keyboard] e [mouse] sono gli id dei dispositivi a cui legare gli esempi.
List<Profile> seedProfiles({String? keyboard, String? mouse}) {
  final global = Profile(id: 'globale', name: 'Globale', global: true);
  final figma = Profile(
    id: 'figma',
    name: 'Figma',
    apps: [const AppRef(name: 'Figma', bundleId: 'com.figma.Desktop', path: '/Applications/Figma.app')],
  );
  final code = Profile(
    id: 'vscode',
    name: 'VS Code',
    apps: [
      const AppRef(
        name: 'Visual Studio Code',
        bundleId: 'com.microsoft.VSCode',
        path: '/Applications/Visual Studio Code.app',
      ),
    ],
  );
  final games = Profile(id: 'giochi', name: 'Giochi');

  if (keyboard != null) {
    final k = keyboard;
    global
      // Caps Lock: premuto è Esc, tenuto premuto apre il livello 1.
      ..setBinding(k, 0, 'caps', KeyBinding(tap: RemapAction(_k('esc')), hold: const LayerAction(1)))
      // Livello 1: frecce sotto la mano destra, Home/End, scorciatoie utili.
      ..setBinding(k, 1, 'i', KeyBinding(tap: RemapAction(_k('up'))))
      ..setBinding(k, 1, 'j', KeyBinding(tap: RemapAction(_k('left'))))
      ..setBinding(k, 1, 'k', KeyBinding(tap: RemapAction(_k('down'))))
      ..setBinding(k, 1, 'l', KeyBinding(tap: RemapAction(_k('right'))))
      ..setBinding(k, 1, 'u', KeyBinding(tap: RemapAction(_k('home'))))
      ..setBinding(k, 1, 'o', KeyBinding(tap: RemapAction(_k('end'))))
      ..setBinding(k, 1, 'p', const KeyBinding(tap: MediaAction(MediaKey.playPause)))
      ..setBinding(k, 1, 'lbracket', const KeyBinding(tap: MediaAction(MediaKey.volumeDown)))
      ..setBinding(k, 1, 'rbracket', const KeyBinding(tap: MediaAction(MediaKey.volumeUp)));
    figma
      ..setBinding(k, 0, 'pgup', KeyBinding(tap: ShortcutAction({Mod.cmd}, _k('z'))))
      ..setBinding(k, 0, 'pgdn', KeyBinding(tap: ShortcutAction({Mod.cmd, Mod.shift}, _k('z'))));
    code
      ..setBinding(k, 0, 'pgup', KeyBinding(tap: ShortcutAction({Mod.cmd}, _k('p'))))
      ..setBinding(k, 0, 'pgdn', KeyBinding(tap: ShortcutAction({Mod.cmd, Mod.shift}, _k('f'))));
    games.setBinding(k, 0, 'caps', const KeyBinding(tap: DisabledAction()));
  }

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
