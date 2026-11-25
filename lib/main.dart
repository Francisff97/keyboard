import 'package:material_ui/material_ui.dart';

import 'src/brand.dart';
import 'src/state.dart';
import 'src/ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState()..init();
  runApp(ToccoApp(state: state));
}

class ToccoApp extends StatelessWidget {
  const ToccoApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tocco',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(state: state),
    );
  }
}
