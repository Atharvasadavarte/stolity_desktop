import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../constants.dart';

Future<void> initializeWindow() async {
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: const Size(1280, 800),
      minimumSize: const Size(800, 600),
      center: true,
      title: 'Stolity',
      backgroundColor: kBackgroundColor,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}
