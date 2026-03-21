import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:moonplex/core/platform/platform_detector.dart';
import 'package:moonplex/core/tmdb/tmdb_service.dart';
import 'package:moonplex/core/theme/moon_theme.dart';
import 'package:moonplex/core/providers/providers.dart';
import 'package:moonplex/features/detail/detail_screen.dart';

// ============== PROVIDERS ==============

enum BrowseFilter { all, movies, tv, anime, asianDrama }

enum BrowseSort { trending, latest, rating, az }

final browseFilterProvider =
    StateProvider<BrowseFilter>((ref) => BrowseFilter.all);
final browseSortProvider =
    StateProvider<BrowseSort>((ref) => BrowseSort.trending);
final browsePageProvider = StateProvider<int>((ref) => 1);

final browseResultsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final filter = ref.watch(browseFilterProvider);
  final sort = ref.watch(browseSortProvider);
  final page = ref.watch(browsePageProvider);

  final tmdb = ref.read(tmdbServiceProvider);

  MediaType type;
  switch (filter) {
    case BrowseFilter.movies:
      type = MediaType.movie;
      break;
    case BrowseFilter.tv:
      type = MediaType.tv;
      break;
    default:
      type = MediaType.movie; // Will need to combine results for "all"
  }

  String sortBy;
  switch (sort) {
    case BrowseSort.trending:
      sortBy = 'popularity.desc';
      break;
    case BrowseSort.latest:
      sortBy = 'release_date.desc';
      break;
    case BrowseSort.rating:
      sortBy = 'vote_average.desc';
      break;
    case BrowseSort.az:
      sortBy = 'original_title.asc';
      break;
  }

  if (filter == BrowseFilter.all) {
    // Combine movies and TV
    final movies =
        await tmdb.getDiscover(MediaType.movie, page: page, sortBy: sortBy);
    final tv = await tmdb.getDiscover(MediaType.tv, page: page, sortBy: sortBy);
    final combined = [...movies, ...tv];
    combined.shuffle();
    return combined;
  }

  return tmdb.getDiscover(type, page: page, sortBy: sortBy);
});

// ============== BROWSE SCREEN ==============

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      // Load more
      final currentPage = ref.read(browsePageProvider);
      ref.read(browsePageProvider.notifier).state = currentPage + 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformDetector.isDesktop;
    final isTV = PlatformDetector.isTV;
    final filter = ref.watch(browseFilterProvider);
    final sort = ref.watch(browseSortProvider);
    final results = ref.watch(browseResultsProvider);

    return Scaffold(
      backgroundColor: MoonTheme.backgroundPrimary,
      appBar: isDesktop || isTV
          ? AppBar(
              backgroundColor: MoonTheme.backgroundSecondary,
              title: const Text(
                'Browse',
                style: TextStyle(color: MoonTheme.textPrimary),
              ),
              automaticallyImplyLeading: false,
            )
          : null,
      body: Column(
        children: [
          // Filter and Sort Row
          Container(
            padding: const EdgeInsets.all(16),
            color: MoonTheme.backgroundSecondary,
            child: Column(
              children: [
                // Filter row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: BrowseFilter.values.map((f) {
                      final isSelected = filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getFilterLabel(f)),
                          selected: isSelected,
                          onSelected: (_) {
                            ref.read(browseFilterProvider.notifier).state = f;
                            ref.read(browsePageProvider.notifier).state = 1;
                          },
                          backgroundColor: MoonTheme.backgroundCard,
                          selectedColor: MoonTheme.accentGlow,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : MoonTheme.textSecondary,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? MoonTheme.accentGlow
                                : MoonTheme.cardBorder,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // Sort row
                Row(
                  children: [
                    const Text(
                      'Sort:',
                      style: TextStyle(
                        color: MoonTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...BrowseSort.values.map((s) {
                      final isSelected = sort == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_getSortLabel(s)),
                          selected: isSelected,
                          onSelected: (_) {
                            ref.read(browseSortProvider.notifier).state = s;
                            ref.read(browsePageProvider.notifier).state = 1;
                          },
                          backgroundColor: MoonTheme.backgroundCard,
                          selectedColor: MoonTheme.accentGlow,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : MoonTheme.textSecondary,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? MoonTheme.accentGlow
                                : MoonTheme.cardBorder,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Content grid
          Expanded(
            child: results.when(
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
                        const Text(
                          'No content found',
                          style: TextStyle(
                            color: MoonTheme.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final crossAxisCount = isDesktop ? 5 : (isTV ? 4 : 3);

                return GridView.builder(
                  controller: _scrollController,
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
                    return _BrowseCard(
                      item: item,
                      onTap: () => _navigateToDetail(context, item),
                    );
                  },
                );
              },
              loading: () => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 5 : 3,
                  childAspectRatio: 0.6,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: 15,
                itemBuilder: (context, index) => _shimmerCard(),
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
                    Text(
                      'Error loading content',
                      style: TextStyle(
                        color: MoonTheme.textSecondary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(browseResultsProvider),
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

  String _getFilterLabel(BrowseFilter filter) {
    switch (filter) {
      case BrowseFilter.all:
        return 'All';
      case BrowseFilter.movies:
        return 'Movies';
      case BrowseFilter.tv:
        return 'TV Shows';
      case BrowseFilter.anime:
        return 'Anime';
      case BrowseFilter.asianDrama:
        return 'Asian Drama';
    }
  }

  String _getSortLabel(BrowseSort sort) {
    switch (sort) {
      case BrowseSort.trending:
        return 'Trending';
      case BrowseSort.latest:
        return 'Latest';
      case BrowseSort.rating:
        return 'Rating';
      case BrowseSort.az:
        return 'A-Z';
    }
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

  Widget _shimmerCard() {
    return Shimmer.fromColors(
      baseColor: MoonTheme.backgroundCard,
      highlightColor: MoonTheme.backgroundSecondary,
      child: Container(
        decoration: BoxDecoration(
          color: MoonTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _BrowseCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const _BrowseCard({
    required this.item,
    this.onTap,
  });

  @override
  ConsumerState<_BrowseCard> createState() => _BrowseCardState();
}

class _BrowseCardState extends ConsumerState<_BrowseCard> {
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

