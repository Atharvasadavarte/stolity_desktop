import 'package:flutter/material.dart';

void showReusableSnackbar(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
  final snack = SnackBar(
    content: Text(
      message,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
    ),
    backgroundColor: Colors.black,
    duration: duration,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  );

  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(snack);
}
