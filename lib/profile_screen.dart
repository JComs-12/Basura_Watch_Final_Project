import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_actions.dart';
import 'date_utils.dart';
import 'notify.dart';
import 'report_enums.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;

  String _name(User? u) {
    final n = u?.displayName;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    final e = u?.email;
    if (e != null && e.contains('@')) return e.split('@').first;
    return 'User';
  }

  String _provider(User? u) =>
      (u?.providerData.any((p) => p.providerId == 'google.com') ?? false)
      ? 'Google account'
      : 'Email & password';

  Future<void> _editName() async {
    final controller = TextEditingController(text: _user?.displayName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit name'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null) return;
    if (newName.isEmpty) {
      notifyError('Name cannot be empty');
      return;
    }
    try {
      await _user!.updateDisplayName(newName);
      await _user!.reload();
      if (mounted) setState(() {});
      notifySuccess('Name updated successfully');
    } catch (_) {
      notifyError('Could not update your name. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final created = user?.metadata.creationTime;
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white,
                  backgroundImage: (user?.photoURL != null)
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Text(
                          _name(user)[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  _name(user),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .where('userId', isEqualTo: user?.uid)
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              int count(ReportStatus s) => docs
                  .where(
                    (d) =>
                        ReportStatus.fromString(
                          (d.data() as Map<String, dynamic>)['status'],
                        ) ==
                        s,
                  )
                  .length;
              return Row(
                children: [
                  _mini(
                    'Total',
                    docs.length,
                    Icons.assignment,
                    const Color(0xFF2E7D32),
                  ),
                  _mini(
                    'Ongoing',
                    count(ReportStatus.inProgress),
                    ReportStatus.inProgress.icon,
                    ReportStatus.inProgress.color,
                  ),
                  _mini(
                    'Resolved',
                    count(ReportStatus.resolved),
                    ReportStatus.resolved.icon,
                    ReportStatus.resolved.color,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF2E7D32),
                  ),
                  title: const Text('Name'),
                  subtitle: Text(_name(user)),
                  trailing: IconButton(
                    tooltip: 'Edit name',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _editName,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                  title: const Text('Email'),
                  subtitle: Text(user?.email ?? 'Not available'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.login, color: Color(0xFF2E7D32)),
                  title: const Text('Signed in with'),
                  subtitle: Text(_provider(user)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                  title: const Text('Member since'),
                  subtitle: Text(
                    created == null
                        ? 'Not available'
                        : formatDate(Timestamp.fromDate(created)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: () async {
              await confirmLogout(context);
              if (context.mounted &&
                  FirebaseAuth.instance.currentUser == null) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 6),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
