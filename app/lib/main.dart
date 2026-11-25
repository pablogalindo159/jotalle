import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/settings.dart';
import 'services/upload_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  final fila = UploadQueue(settings);
  runApp(JotalleApp(settings: settings, fila: fila));
}

class JotalleApp extends StatefulWidget {
  const JotalleApp({super.key, required this.settings, required this.fila});
  final Settings settings;
  final UploadQueue fila;

  @override
  State<JotalleApp> createState() => _JotalleAppState();
}

class _JotalleAppState extends State<JotalleApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    widget.fila.enviarTudo();
    // quando a conexão voltar, esvazia a fila
    _sub = Connectivity().onConnectivityChanged.listen((_) => widget.fila.enviarTudo());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Jotalle',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF3D8BD4),
          scaffoldBackgroundColor: const Color(0xFF061A38),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF061A38), elevation: 0, centerTitle: true),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.black.withOpacity(.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        home: HomeScreen(settings: widget.settings, fila: widget.fila),
      );
}
