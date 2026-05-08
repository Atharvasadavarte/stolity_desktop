import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'webview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(const StolityApp());
}

class StolityApp extends StatelessWidget {
  const StolityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stolity',
      debugShowCheckedModeBanner: false,
      home: const StolityWebView(),
    );
  }
}
