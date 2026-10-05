import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'report_enums.dart';
import 'image_gallery.dart';
import 'notify.dart';

const cloudName = 'l8mrm6wy';
const uploadPreset = 'basurawatch_preset';
const maxPhotos = 5;

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
  final List<File> _images = [];
  double? _lat;
  double? _lng;
  bool _loading = false;
  bool _photoError = false;

  Future<void> _fromCamera() async {
    if (_images.length >= maxPhotos) {
      notifyInfo('You can add up to $maxPhotos photos.');
      return;
    }
    try {
      final p = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (p != null) {
        setState(() {
          _images.add(File(p.path));
          _photoError = false;
        });
      }
    } catch (_) {
      notifyError('Could not open the camera. Try the gallery instead.');
    }
  }

  Future<void> _fromGallery() async {
    final remaining = maxPhotos - _images.length;
    if (remaining <= 0) {
      notifyInfo('You can add up to $maxPhotos photos.');
      return;
    }
    try {
      final picker = ImagePicker();
      List<XFile> picked;
      if (remaining >= 2) {
        picked = await picker.pickMultiImage(
          imageQuality: 70,
          limit: remaining,
        );
      } else {
        final one = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
        );
        picked = one == null ? [] : [one];
      }
      if (picked.isEmpty) return;
      if (picked.length > remaining) {
        notifyInfo(
          'Only $maxPhotos photos allowed. Extra photos were skipped.',
        );
      }
      setState(() {
        _images.addAll(picked.take(remaining).map((x) => File(x.path)));
        _photoError = false;
      });
    } catch (_) {
      notifyError('Could not open the gallery. Please try again.');
    }
  }

  void _remove(int i) => setState(() => _images.removeAt(i));

  void _preview(int i) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenGallery(
          images: _images.map<ImageProvider>((f) => FileImage(f)).toList(),
          initialIndex: i,
        ),
      ),
    );
  }

  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        notifyError('Please turn on your GPS');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        notifyError('Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });

      try {
        final geocoding = Geocoding();
        final places = await geocoding.placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (places.isNotEmpty) {
          final p = places.first;
          final parts = <String>[];
          for (final String? s in [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ]) {
            final t = s?.trim() ?? '';
            if (t.isNotEmpty && !parts.contains(t)) parts.add(t);
          }
          if (parts.isNotEmpty) {
            setState(() => _locationText.text = parts.join(', '));
          }
        }
        notifySuccess('Location captured');
      } catch (_) {
        notifyInfo('GPS saved, but the address was not found. Please type it.');
      }
    } catch (e) {
      notifyError('Could not get location. Please try again.');
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
    final photoOk = _images.isNotEmpty;
    setState(() => _photoError = !photoOk);

    if (!formOk || !photoOk) {
      notifyError('Please fill in the fields marked in red');
      return;
    }

    setState(() => _loading = true);
    try {
      final urls = await Future.wait(_images.map(_uploadImage));
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'category': _category!.label,
        'description': _description.text.trim(),
        'locationText': _locationText.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'imageUrl': urls.first,
        'imageUrls': urls,
        'status': ReportStatus.pending.label,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      notifySuccess('Report submitted successfully!');
      return;
    } catch (e) {
      notifyError(
        'Could not submit the report. Check your internet and try again.',
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _thumb(int i) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _preview(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _images[i],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _remove(i),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _photoError ? Colors.red : Colors.grey.shade300;
    final full = _images.length >= maxPhotos;
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: borderColor,
                    width: _photoError ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Photos (${_images.length}/$maxPhotos)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_images.isNotEmpty)
                          const Text(
                            'Tap a photo to preview',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: _images.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 36,
                                    color: _photoError
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Add up to $maxPhotos photos',
                                    style: TextStyle(
                                      color: _photoError
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (var i = 0; i < _images.length; i++)
                                  _thumb(i),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              if (_photoError)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'At least one photo is required',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: full ? null : _fromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: full ? null : _fromGallery,
                      icon: const Icon(Icons.photo_library),
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
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Address is required'
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
                  ? Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 10),
                          Text(
                            'Uploading ${_images.length} photo(s)...',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
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
