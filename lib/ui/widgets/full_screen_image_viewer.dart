import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../theme/app_theme.dart';

/// Full screen image viewer with pinch-to-zoom and swipe gallery
class FullScreenImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  static void show(BuildContext context, List<String> imagePaths, {int initialIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imagePaths: imagePaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Image counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_currentIndex + 1} / ${widget.imagePaths.length}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // Share functionality placeholder
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share will be available in future update')),
              );
            },
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (context, index) {
          final path = widget.imagePaths[index];
          final file = File(path);
          
          return PhotoViewGalleryPageOptions(
            imageProvider: FileImage(file),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            heroAttributes: PhotoViewHeroAttributes(tag: 'image_$index'),
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Cannot load image',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              );
            },
          );
        },
        itemCount: widget.imagePaths.length,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? null
                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
            color: AppTheme.primaryColor,
          ),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageController: _pageController,
        onPageChanged: _onPageChanged,
      ),
    );
  }
}

/// Image gallery grid with tap to view full screen
class ImageGalleryGrid extends StatelessWidget {
  final List<String> imagePaths;
  final int crossAxisCount;
  final double spacing;
  final Function(int index)? onImageTap;

  const ImageGalleryGrid({
    super.key,
    required this.imagePaths,
    this.crossAxisCount = 3,
    this.spacing = 4,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: imagePaths.length,
      itemBuilder: (context, index) {
        final path = imagePaths[index];
        final file = File(path);
        
        return GestureDetector(
          onTap: () {
            if (onImageTap != null) {
              onImageTap!(index);
            } else {
              FullScreenImageViewer.show(context, imagePaths, initialIndex: index);
            }
          },
          child: Hero(
            tag: 'image_grid_$index',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: file.existsSync()
                  ? Image.file(
                      file,
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image, color: Colors.white54),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.broken_image, color: Colors.white54),
                    ),
            ),
          ),
        );
      },
    );
  }
}
