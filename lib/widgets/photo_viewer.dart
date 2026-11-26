import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/services/photo_service.dart';

/// Full-screen, swipeable, pinch-to-zoom photo viewer with disk caching and
/// automatic signed-URL refresh on expiration.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
    this.storagePaths = const [],
  });

  final List<String> urls;
  final int initialIndex;
  final List<String> storagePaths;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _controller;
  late final List<String> _urls;
  final Set<int> _retried = {};
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _urls = List<String>.from(widget.urls);
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshAt(int i) async {
    if (_retried.contains(i) || i >= widget.storagePaths.length) return;
    _retried.add(i);
    try {
      final fresh = await PhotoService.signedUrl(widget.storagePaths[i]);
      if (!mounted) return;
      setState(() => _urls[i] = fresh);
    } catch (_) {
      // Leave the broken-image indicator visible.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${_urls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final path =
              i < widget.storagePaths.length ? widget.storagePaths[i] : null;
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: _urls[i],
                cacheKey: path,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) {
                  if (path != null && !_retried.contains(i)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _refreshAt(i);
                    });
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
