import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notify.dart';
import 'report_enums.dart';

class EditReportScreen extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> data;
  const EditReportScreen({
    super.key,
    required this.reportId,
    required this.data,
  });

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address = TextEditingController(
    text: (widget.data['locationText'] ?? '').toString(),
  );
  late final TextEditingController _description = TextEditingController(
    text: (widget.data['description'] ?? '').toString(),
  );
  late ReportCategory? _category = ReportCategory.values
      .where((c) => c.label == widget.data['category'])
      .firstOrNull;
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      notifyError('Please fill in the fields marked in red');
      return;
    }
    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.reportId);
      final fresh = await ref.get();
      final status = ReportStatus.fromString((fresh.data() ?? {})['status']);
      if (status != ReportStatus.pending) {
        if (mounted) Navigator.pop(context);
        notifyError(
          'This report is already being handled and can no longer be edited.',
        );
        return;
      }
      await ref.update({
        'category': _category!.label,
        'locationText': _address.text.trim(),
        'description': _description.text.trim(),
        'editedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      notifySuccess('Report updated successfully');
      return;
    } catch (_) {
      notifyError('Could not save changes. Check your internet and try again.');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF2E7D32)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You can edit a report only while it is Pending. Photos cannot be changed.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ReportCategory>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: ReportCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(c.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Please choose a category' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Address is required'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Save changes'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
