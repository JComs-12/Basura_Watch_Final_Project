import 'package:flutter/material.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

void _show(String text, IconData icon, Color color) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void notifySuccess(String text) =>
    _show(text, Icons.check_circle, const Color(0xFF2E7D32));

void notifyError(String text) => _show(text, Icons.error, Colors.red.shade700);

void notifyInfo(String text) =>
    _show(text, Icons.info, Colors.blueGrey.shade700);
