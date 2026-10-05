import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_details_screen.dart';
import 'report_enums.dart';
import 'date_utils.dart';
import 'ui_helpers.dart';

class MyReportsScreen extends StatefulWidget {
  final ReportStatus? initialFilter;
  const MyReportsScreen({super.key, this.initialFilter});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late ReportStatus? _filter = widget.initialFilter;
  late Stream<QuerySnapshot> _stream = _buildStream();

  Stream<QuerySnapshot> _buildStream() => FirebaseFirestore.instance
      .collection('reports')
      .where('userId', isEqualTo: _uid)
      .snapshots();

  int _time(QueryDocumentSnapshot d) {
    final t = (d.data() as Map<String, dynamic>)['createdAt'];
    return t is Timestamp
        ? t.millisecondsSinceEpoch
        : DateTime.now().millisecondsSinceEpoch;
  }

  ReportStatus _status(QueryDocumentSnapshot d) =>
      ReportStatus.fromString((d.data() as Map<String, dynamic>)['status']);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorState(
              message: 'We could not load your reports. Check your internet connection.',
              onRetry: () => setState(() => _stream = _buildStream()),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!.docs.toList()
            ..sort((a, b) => _time(b).compareTo(_time(a)));
          final shown = _filter == null
              ? all
              : all.where((d) => _status(d) == _filter).toList();
          int count(ReportStatus s) => all.where((d) => _status(d) == s).length;

          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('All (${all.length})'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                    ),
                    ...ReportStatus.values.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(s.icon, size: 16, color: s.color),
                          label: Text('${s.label} (${count(s)})'),
                          selected: _filter == s,
                          onSelected: (_) => setState(() => _filter = s),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => refreshReports(_uid),
                  child: shown.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: all.isEmpty
                                  ? const EmptyState(
                                      icon: Icons.inbox_outlined,
                                      title: 'No reports yet',
                                      message: 'Go back and tap Submit Report to send your first one.',
                                    )
                                  : EmptyState(
                                      icon: Icons.filter_list_off,
                                      title: 'No ${_filter!.label} reports',
                                      message: 'Try a different filter to see your other reports.',
                                    ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final doc = shown[i];
                            final d = doc.data() as Map<String, dynamic>;
                            final status = _status(doc);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(10),
                                leading: ReportThumb(
                                  url: d['imageUrl'] as String?,
                                  size: 60,
                                ),
                                title: Text(
                                  d['category'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d['locationText'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          formatDate(d['createdAt']),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Chip(
                                  avatar: Icon(
                                    status.icon,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    status.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: status.color,
                                  side: BorderSide.none,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ReportDetailsScreen(reportId: doc.id),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
