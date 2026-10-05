import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_enums.dart';
import 'image_gallery.dart';
import 'date_utils.dart';
import 'notify.dart';
import 'edit_report_screen.dart';

class ReportDetailsScreen extends StatelessWidget {
  final String reportId;
  const ReportDetailsScreen({super.key, required this.reportId});

  List<Map<String, dynamic>> _history(
    Map<String, dynamic> d,
    ReportStatus current,
  ) {
    final raw = d['statusHistory'];
    if (raw is List && raw.isNotEmpty) {
      final list = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      list.sort((a, b) {
        final ta = a['at'] is Timestamp
            ? (a['at'] as Timestamp).millisecondsSinceEpoch
            : 0;
        final tb = b['at'] is Timestamp
            ? (b['at'] as Timestamp).millisecondsSinceEpoch
            : 0;
        return ta.compareTo(tb);
      });
      return list;
    }
    final list = <Map<String, dynamic>>[
      {'status': ReportStatus.pending.label, 'at': d['createdAt']},
    ];
    if (current != ReportStatus.pending) {
      list.add({'status': current.label, 'at': d['statusUpdatedAt']});
    }
    return list;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 32),
        title: const Text('Delete this report?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(100, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId);
      final fresh = await ref.get();
      final status = ReportStatus.fromString((fresh.data() ?? {})['status']);
      if (status != ReportStatus.pending) {
        notifyError(
          'This report is already being handled and can no longer be deleted.',
        );
        return;
      }
      await ref.delete();
      if (context.mounted) Navigator.pop(context);
      notifySuccess('Report deleted');
    } catch (_) {
      notifyError('Could not delete the report. Check your internet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const ErrorMessage();
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('This report no longer exists.'));
          }
          final d = snap.data!.data() as Map<String, dynamic>;
          final status = ReportStatus.fromString(d['status']);
          final reply = (d['adminReply'] ?? '').toString().trim();
          final history = _history(d, status);
          final canModify =
              status == ReportStatus.pending && d['userId'] == uid;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ReportImageGallery(urls: reportImageUrls(d)),
              const SizedBox(height: 16),
              if (reply.isNotEmpty) ...[
                Card(
                  color: const Color(0xFFE8F5E9),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.support_agent, color: Color(0xFF2E7D32)),
                            SizedBox(width: 8),
                            Text(
                              'Response from BasuraWatch',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(reply, style: const TextStyle(fontSize: 15)),
                        if (d['repliedAt'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            formatDate(d['repliedAt'], withTime: true),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        avatar: Icon(
                          status.icon,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          status.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: status.color,
                        side: BorderSide.none,
                      ),
                      const SizedBox(height: 8),
                      _row(Icons.category_outlined, 'Category', d['category']),
                      _row(Icons.place_outlined, 'Address', d['locationText']),
                      _row(
                        Icons.access_time,
                        'Submitted',
                        formatDate(d['createdAt'], withTime: true),
                      ),
                      if (d['editedAt'] != null)
                        _row(
                          Icons.edit_calendar_outlined,
                          'Last edited',
                          formatDate(d['editedAt'], withTime: true),
                        ),
                      if ((d['description'] ?? '').toString().isNotEmpty)
                        _row(Icons.notes, 'Description', d['description']),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status history',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < history.length; i++)
                        _timelineItem(
                          ReportStatus.fromString(history[i]['status']),
                          history[i]['at'],
                          isLast: i == history.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
              if (canModify) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditReportScreen(reportId: reportId, data: d),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _confirmDelete(context),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _timelineItem(ReportStatus s, dynamic at, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: s.color,
                child: Icon(s.icon, size: 16, color: Colors.white),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    at is Timestamp
                        ? formatDate(at, withTime: true)
                        : 'Date not recorded',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text('$value', style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorMessage extends StatelessWidget {
  const ErrorMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Could not load this report. Check your internet connection and try again.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
