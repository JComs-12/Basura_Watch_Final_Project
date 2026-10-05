import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_enums.dart';
import 'image_gallery.dart';

class ReportDetailsScreen extends StatelessWidget {
  final String reportId;
  const ReportDetailsScreen({super.key, required this.reportId});

  String _fmt(dynamic ts) =>
      ts is Timestamp ? ts.toDate().toString().substring(0, 16) : 'Just now';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!.data() as Map<String, dynamic>;
          final status = ReportStatus.fromString(d['status']);
          final reply = (d['adminReply'] ?? '').toString().trim();

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
                            _fmt(d['repliedAt']),
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
                        _fmt(d['createdAt']),
                      ),
                      if ((d['description'] ?? '').toString().isNotEmpty)
                        _row(Icons.notes, 'Description', d['description']),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
