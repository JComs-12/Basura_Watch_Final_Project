import 'package:flutter/material.dart';

List<String> reportImageUrls(Map<String, dynamic> d) {
  final list = d['imageUrls'];
  if (list is List && list.isNotEmpty) {
    return list.map((e) => e.toString()).toList();
  }
  final single = d['imageUrl'];
  return single == null ? [] : [single.toString()];
}

class FullScreenGallery extends StatefulWidget {
  final List<ImageProvider> images;
  final int initialIndex;
  const FullScreenGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image(image: widget.images[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class ReportImageGallery extends StatefulWidget {
  final List<String> urls;
  final double height;
  const ReportImageGallery({super.key, required this.urls, this.height = 260});

  @override
  State<ReportImageGallery> createState() => _ReportImageGalleryState();
}

class _ReportImageGalleryState extends State<ReportImageGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenGallery(
                      images: urls
                          .map<ImageProvider>((u) => NetworkImage(u))
                          .toList(),
                      initialIndex: i,
                    ),
                  ),
                ),
                child: Image.network(
                  urls[i],
                  width: double.infinity,
                  height: widget.height,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, p) => p == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            if (urls.length > 1) ...[
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_index + 1}/${urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    urls.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
