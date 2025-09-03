import 'package:flutter/material.dart';

class ConnectionSetupScreen extends StatelessWidget {
  const ConnectionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Setup')),
      body: const Center(child: Text('Additional connection options coming soon.')),
    );
  }
}
