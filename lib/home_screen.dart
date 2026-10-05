import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'submit_report_screen.dart';
import 'my_reports_screen.dart';
import 'report_details_screen.dart';
import 'report_enums.dart';
import 'app_logo.dart';
import 'date_utils.dart';
import 'auth_actions.dart';
import 'profile_screen.dart';
import 'ui_helpers.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _name(User? u) {
    final n = u?.displayName;
    if (n != null && n.trim().isNotEmpty) return n.trim().split(' ').first;
    final e = u?.email;
    if (e != null && e.contains('@')) return e.split('@').first;
    return 'there';
  }

  int _time(QueryDocumentSnapshot d) {
    final t = (d.data() as Map<String, dynamic>)['createdAt'];
    return t is Timestamp
        ? t.millisecondsSinceEpoch
        : DateTime.now().millisecondsSinceEpoch;
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, userSnap) {
        final user = userSnap.data ?? FirebaseAuth.instance.currentUser;
        final uid = user?.uid ?? '';
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 16,
            title: const Row(
              children: [
                AppLogo(size: 36),
                SizedBox(width: 10),
                Text(
                  'BasuraWatch Davao',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Account',
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'profile') _open(context, const ProfileScreen());
                  if (value == 'logout') confirmLogout(context);
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text(
                      user?.email ?? user?.displayName ?? 'Signed in',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 10),
                        Text('My Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red, size: 20),
                        SizedBox(width: 10),
                        Text('Log out', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF2E7D32),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            _name(user)[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => refreshReports(uid),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${_name(user)}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'See garbage? Report it.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.recycling,
                        size: 56,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.add_a_photo,
                        label: 'Submit Report',
                        onTap: () => _open(context, const SubmitReportScreen()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.list_alt,
                        label: 'My Reports',
                        onTap: () => _open(context, const MyReportsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reports')
                      .where('userId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return ErrorState(
                        message: 'We could not load your reports. Pull down to try again.',
                        onRetry: () => refreshReports(uid),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snap.data!.docs.toList()
                      ..sort((a, b) => _time(b).compareTo(_time(a)));

                    int count(ReportStatus s) => docs
                        .where(
                          (d) =>
                              ReportStatus.fromString(
                                (d.data() as Map<String, dynamic>)['status'],
                              ) ==
                              s,
                        )
                        .length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: ReportStatus.values
                              .map(
                                (s) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: _StatCard(
                                      status: s,
                                      count: count(s),
                                      onTap: () => _open(
                                        context,
                                        MyReportsScreen(initialFilter: s),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent reports',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _open(context, const MyReportsScreen()),
                              child: const Text('See all'),
                            ),
                          ],
                        ),
                        if (docs.isEmpty)
                          const EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'No reports yet',
                            message: 'Tap Submit Report to send your first garbage report.',
                          )
                        else
                          ...docs.take(3).map((doc) {
                            final d = doc.data() as Map<String, dynamic>;
                            final status = ReportStatus.fromString(d['status']);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(10),
                                leading: ReportThumb(
                                  url: d['imageUrl'] as String?,
                                  size: 56,
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
                                      maxLines: 1,
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
                                onTap: () => _open(
                                  context,
                                  ReportDetailsScreen(reportId: doc.id),
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final ReportStatus status;
  final int count;
  final VoidCallback onTap;
  const _StatCard({
    required this.status,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(status.icon, color: status.color),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(status.label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
