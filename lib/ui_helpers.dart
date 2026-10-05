import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notify.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Photo thumbnail that never crashes when offline or when the link is broken.
class ReportThumb extends StatelessWidget {
  final String? url;
  final double size;
  const ReportThumb({super.key, required this.url, this.size = 56});

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: Colors.grey.shade200,
    child: Icon(
      Icons.image_not_supported_outlined,
      color: Colors.grey.shade500,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url == null || url!.isEmpty
          ? _placeholder()
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
              loadingBuilder: (c, child, p) => p == null
                  ? child
                  : Container(
                      width: size,
                      height: size,
                      color: Colors.grey.shade200,
                    ),
            ),
    );
  }
}

/// Used by pull-to-refresh. Checks the server and warns if there is no internet.
Future<void> refreshReports(String uid) async {
  try {
    await FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    notifyError('No internet connection. Showing saved reports.');
  }
}
