import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonplex/core/platform/platform_detector.dart';
import 'package:moonplex/core/tmdb/tmdb_service.dart';
import 'package:moonplex/core/theme/moon_theme.dart';
import 'package:moonplex/core/providers/providers.dart';
import 'package:moonplex/features/detail/detail_screen.dart';

// ============== PROVIDERS ==============

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchTypeProvider = StateProvider<MediaType>((ref) => MediaType.movie);
final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

  final type = ref.watch(searchTypeProvider);
  final tmdb = ref.read(tmdbServiceProvider);

  return tmdb.search(query, type);
});

// ============== SEARCH SCREEN ==============

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Auto-focus search on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    // Register keyboard shortcut for desktop
    if (PlatformDetector.isDesktop) {
      HardwareKeyboard.instance.addHandler(_handleKeyPress);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    if (PlatformDetector.isDesktop) {
      HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    }
    super.dispose();
  }

  bool _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+F or Cmd+F to focus search
      if ((event.logicalKey == LogicalKeyboardKey.keyF) &&
          (HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed)) {
        _focusNode.requestFocus();
        return true;
      }
    }
    return false;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformDetector.isDesktop;
    final isTV = PlatformDetector.isTV;
    final query = ref.watch(searchQueryProvider);
    final type = ref.watch(searchTypeProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: MoonTheme.backgroundPrimary,
      appBar: isDesktop || isTV
          ? AppBar(
              backgroundColor: MoonTheme.backgroundSecondary,
              title: const Text(
                'Search',
                style: TextStyle(color: MoonTheme.textPrimary),
              ),
              automaticallyImplyLeading: false,
            )
          : null,
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: MoonTheme.backgroundSecondary,
            child: Column(
              children: [
                // Text field
                TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: MoonTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search movies, TV shows...',
                    hintStyle: const TextStyle(color: MoonTheme.textMuted),
                    prefixIcon: const Icon(Icons.search,
                        color: MoonTheme.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: MoonTheme.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: MoonTheme.backgroundCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MoonTheme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MoonTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: MoonTheme.accentGlow, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Type selector
                Row(
                  children: [
                    const Text(
                      'Type:',
                      style: TextStyle(
                        color: MoonTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Movies'),
                      selected: type == MediaType.movie,
                      onSelected: (_) {
                        ref.read(searchTypeProvider.notifier).state =
                            MediaType.movie;
                        if (query.isNotEmpty) {
                          ref.invalidate(searchResultsProvider);
                        }
                      },
                      backgroundColor: MoonTheme.backgroundCard,
                      selectedColor: MoonTheme.accentGlow,
                      labelStyle: TextStyle(
                        color: type == MediaType.movie
                            ? Colors.white
                            : MoonTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('TV Shows'),
                      selected: type == MediaType.tv,
                      onSelected: (_) {
                        ref.read(searchTypeProvider.notifier).state =
                            MediaType.tv;
                        if (query.isNotEmpty) {
                          ref.invalidate(searchResultsProvider);
                        }
                      },
                      backgroundColor: MoonTheme.backgroundCard,
                      selectedColor: MoonTheme.accentGlow,
                      labelStyle: TextStyle(
                        color: type == MediaType.tv
                            ? Colors.white
                            : MoonTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    // Voice search for TV
                    if (isTV)
                      IconButton(
                        icon: const Icon(Icons.mic,
                            color: MoonTheme.textSecondary),
                        onPressed: () {
                          // TODO: Implement voice search
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Voice search coming soon'),
                              backgroundColor: MoonTheme.backgroundCard,
                            ),
                          );
                        },
                        tooltip: 'Voice Search',
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: query.isEmpty
                ? _emptyState(isDesktop)
                : results.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search_off,
                                color: MoonTheme.textMuted,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No results for "$query"',
                                style: const TextStyle(
                                  color: MoonTheme.textSecondary,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final crossAxisCount = isDesktop ? 5 : 3;

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: isDesktop ? 0.55 : 0.6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _SearchResultCard(
                            item: item,
                            onTap: () => _navigateToDetail(context, item),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: MoonTheme.accentPrimary,
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: MoonTheme.error,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Search failed',
                            style: TextStyle(
                              color: MoonTheme.textSecondary,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(searchResultsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDesktop) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            color: MoonTheme.textMuted,
            size: isDesktop ? 80 : 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Search for movies and TV shows',
            style: TextStyle(
              color: MoonTheme.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find your favorite content',
            style: TextStyle(
              color: MoonTheme.textMuted,
              fontSize: 14,
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MoonTheme.backgroundCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard, color: MoonTheme.textMuted, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Press Ctrl+F to search',
                    style: TextStyle(
                      color: MoonTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          tmdbId: item.tmdbId,
          mediaType: item.mediaType,
        ),
      ),
    );
  }
}

class _SearchResultCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const _SearchResultCard({
    required this.item,
    this.onTap,
  });

  @override
  ConsumerState<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends ConsumerState<_SearchResultCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformDetector.isDesktop;
    final tmdb = ref.watch(tmdbServiceProvider);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          transform: Matrix4.identity()
            ..scale(_isHovered && isDesktop ? 1.05 : 1.0),
          transformAlignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered && isDesktop
                    ? MoonTheme.accentGlow
                    : MoonTheme.cardBorder,
                width: _isHovered && isDesktop ? 2 : 1,
              ),
              boxShadow: _isHovered && isDesktop
                  ? [
                      BoxShadow(
                        color: MoonTheme.accentGlow.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster
                  widget.item.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: tmdb.posterUrl(widget.item.posterPath),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: MoonTheme.backgroundCard,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: MoonTheme.backgroundCard,
                            child: const Icon(Icons.movie,
                                color: MoonTheme.textMuted),
                          ),
                        )
                      : Container(
                          color: MoonTheme.backgroundCard,
                          child: const Icon(Icons.movie,
                              color: MoonTheme.textMuted),
                        ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Type badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.item.mediaType == MediaType.movie
                            ? Colors.blue.withOpacity(0.8)
                            : Colors.purple.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.item.mediaType == MediaType.movie
                            ? 'Movie'
                            : 'TV',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Rating
                  if (widget.item.rating > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              widget.item.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Title
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MoonTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.item.releaseYear > 0)
                          Text(
                            widget.item.releaseYear.toString(),
                            style: const TextStyle(
                              color: MoonTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

