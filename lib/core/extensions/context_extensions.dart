import 'package:flutter/material.dart';

extension ContextExt on BuildContext {
  void showSnack(String message) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(message)));
  }
}
