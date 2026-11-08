import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/connect.dart';
import 'screens/guide.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Lineup',
      size: Size(1280, 800),
      minimumSize: Size(960, 640),
      center: true,
      backgroundColor: Color(0xFF0B0C0E),
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  final state = AppState();
  runApp(LineupApp(state: state));
  await state.restore();
}

class LineupApp extends StatelessWidget {
  const LineupApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final palette = state.palette;
        return AppScope(
          state: state,
          child: PaletteScope(
            palette: palette,
            child: MaterialApp(
              title: 'Lineup',
              debugShowCheckedModeBanner: false,
              theme: palette.toThemeData(),
              home: state.restoring
                  ? const Scaffold()
                  : state.credentials == null
                      ? const ConnectScreen()
                      : const GuideScreen(),
            ),
          ),
        );
      },
    );
  }
}
