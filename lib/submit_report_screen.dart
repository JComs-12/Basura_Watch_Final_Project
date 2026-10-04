import 'dart:convert';
import 'dart:io';

import 'report_enums.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const cloudName = 'l8mrm6wy';
const uploadPreset = 'basurawatch_preset';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationText = TextEditingController();
  final _description = TextEditingController();

  ReportCategory? _category;
  File? _image;
  double? _lat;
  double? _lng;
  bool _loading = false;
  bool _photoError = false;

  void _msg(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
      );
      if (picked != null) {
        setState(() {
          _image = File(picked.path);
          _photoError = false;
        });
      }
    } catch (e) {
      _msg(
        'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}. Try the other option.',
        error: true,
      );
    }
  }

  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _msg('Please turn on your GPS', error: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _msg('Location permission denied', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _msg('Location captured');
    } catch (e) {
      _msg('Could not get location. Please try again.', error: true);
    }
  }

  Future<String> _uploadImage(File file) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Upload failed: $body');
    }
    return jsonDecode(body)['secure_url'];
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    final photoOk = _image != null;
    setState(() => _photoError = !photoOk);

    if (!formOk || !photoOk) {
      _msg('Please fill in the fields marked in red', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final imageUrl = await _uploadImage(_image!);
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'category': _category!.label,
        'description': _description.text.trim(),
        'locationText': _locationText.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'imageUrl': imageUrl,
        'status': ReportStatus.pending.label,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _msg('Report submitted!');
      Navigator.pop(context);
    } catch (e) {
      _msg('Error: $e', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _photoError ? Colors.red : Colors.grey.shade300;
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: borderColor,
                    width: _photoError ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _image == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: _photoError ? Colors.red : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No photo yet',
                              style: TextStyle(
                                color: _photoError ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
              if (_photoError)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'A photo is required',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
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
                controller: _locationText,
                decoration: const InputDecoration(
                  labelText: 'Street / Barangay',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Street or barangay is required'
                    : null,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _getLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _lat == null
                      ? 'Use my current location'
                      : 'GPS saved (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})',
                ),
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
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit Report'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
