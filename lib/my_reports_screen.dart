import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_enums.dart';

import 'report_details_screen.dart';

Color statusColor(String s) => ReportStatus.fromString(s).color;

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs.toList();
          int time(QueryDocumentSnapshot d) {
            final t = (d.data() as Map<String, dynamic>)['createdAt'];
            return t is Timestamp
                ? t.millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch;
          }

          docs.sort((a, b) => time(b).compareTo(time(a)));
          if (docs.isEmpty) {
            return const Center(child: Text('No reports yet'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final status = d['status'] ?? 'Pending';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      d['imageUrl'],
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(d['category'] ?? ''),
                  subtitle: Text(d['locationText'] ?? ''),
                  trailing: Chip(
                    label: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: statusColor(status),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportDetailsScreen(reportId: docs[i].id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
