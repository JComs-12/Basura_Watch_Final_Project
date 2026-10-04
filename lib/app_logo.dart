import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    // To use your own logo image later:
    // 1. Put it in assets/logo.png and add under flutter: in pubspec.yaml
    //      assets:
    //        - assets/logo.png
    // 2. Replace the child below with Image.asset('assets/logo.png')
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)],
        ),
      ),
      child: Icon(Icons.recycling, color: Colors.white, size: size * 0.6),
    );
  }
}
