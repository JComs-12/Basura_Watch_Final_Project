import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'my_reports_screen.dart';

class ReportDetailsScreen extends StatelessWidget {
  final String reportId;
  const ReportDetailsScreen({super.key, required this.reportId});

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
          final status = d['status'] ?? 'Pending';
          final ts = d['createdAt'];
          final date = ts is Timestamp
              ? ts.toDate().toString().substring(0, 16)
              : 'Just now';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    d['imageUrl'],
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Chip(
                  label: Text(
                    status,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: statusColor(status),
                ),
                const SizedBox(height: 12),
                _row(Icons.category, 'Category', d['category']),
                _row(Icons.place, 'Location', d['locationText']),
                if (d['latitude'] != null)
                  _row(
                    Icons.my_location,
                    'GPS',
                    '${d['latitude']}, ${d['longitude']}',
                  ),
                _row(Icons.access_time, 'Submitted', date),
                if ((d['description'] ?? '').toString().isNotEmpty)
                  _row(Icons.notes, 'Description', d['description']),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '$value'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
