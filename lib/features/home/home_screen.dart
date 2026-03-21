import 'dart:async';
import 'dart:math';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:moonplex/core/platform/platform_detector.dart';
import 'package:moonplex/core/tmdb/tmdb_service.dart';
import 'package:moonplex/core/database/app_database.dart';
import 'package:moonplex/core/theme/moon_theme.dart';
import 'package:moonplex/core/providers/providers.dart';
import 'package:moonplex/features/detail/detail_screen.dart';

// ============== PROVIDERS ==============

final trendingMoviesProvider = FutureProvider<List<MediaItem>>((ref) async {
  final tmdb = ref.watch(tmdbServiceProvider);
  return tmdb.getTrending(MediaType.movie, TimeWindow.week);
});

final trendingTvProvider = FutureProvider<List<MediaItem>>((ref) async {
  final tmdb = ref.watch(tmdbServiceProvider);
  return tmdb.getTrending(MediaType.tv, TimeWindow.week);
});

final continueWatchingProvider =
    FutureProvider<List<ContinueWatchingData>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final profile = await db.activeProfile;
  if (profile == null) return [];

  return (db.select(db.continueWatching)
        ..where((t) => t.profileId.equals(profile.id))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
        ..limit(10))
      .get();
});

final heroIndexProvider = StateProvider<int>((ref) => 0);

// ============== CONTENT CARD WIDGET ==============

class ContentCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool showRating;

  const ContentCard({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.onTap,
    this.showRating = true,
  });

  @override
  ConsumerState<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends ConsumerState<ContentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tmdb = ref.watch(tmdbServiceProvider);
    final isDesktop = PlatformDetector.isDesktop;
    final isTV = PlatformDetector.isTV;

    final cardWidth = widget.width ?? (isDesktop ? 160 : 120);
    final cardHeight = widget.height ?? (isDesktop ? 240 : 180);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: cardWidth,
          transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
          transformAlignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? MoonTheme.accentGlow : MoonTheme.cardBorder,
                width: _isHovered ? 2 : 1,
              ),
              boxShadow: _isHovered
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
                children: [
                  // Poster image
                  Positioned.fill(
                    child: widget.item.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: tmdb.posterUrl(widget.item.posterPath),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                _shimmerPlaceholder(cardWidth, cardHeight),
                            errorWidget: (context, url, error) =>
                                _placeholder(cardWidth, cardHeight),
                          )
                        : _placeholder(cardWidth, cardHeight),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Rating badge
                  if (widget.showRating && widget.item.rating > 0)
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
                  // Quality badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: MoonTheme.accentGlow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'HD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Title
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDesktop || isTV
                            ? MoonTheme.textPrimary
                            : Colors.white,
                        fontSize: isDesktop ? 13 : 11,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 4,
                          ),
                        ],
                      ),
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

  Widget _shimmerPlaceholder(double width, double height) {
    return Shimmer.fromColors(
      baseColor: MoonTheme.backgroundCard,
      highlightColor: MoonTheme.backgroundSecondary,
      child: Container(
          width: width, height: height, color: MoonTheme.backgroundCard),
    );
  }

  Widget _placeholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: MoonTheme.backgroundCard,
      child: const Center(
        child: Icon(Icons.movie, color: MoonTheme.textMuted, size: 40),
      ),
    );
  }
}

// ============== CONTENT SHELF ==============

class ContentShelf extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final bool showSeeAll;
  final VoidCallback? onSeeAll;
  final Function(MediaItem)? onItemTap;

  const ContentShelf({
    super.key,
    required this.title,
    required this.items,
    this.showSeeAll = false,
    this.onSeeAll,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformDetector.isDesktop;
    final isTV = PlatformDetector.isTV;

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 16,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: MoonTheme.textPrimary,
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showSeeAll)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(
                    'See All',
                    style: TextStyle(
                      color: MoonTheme.accentSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: isDesktop ? 260 : 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ContentCard(
                  item: item,
                  onTap: onItemTap != null ? () => onItemTap!(item) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============== HERO BANNER ==============

class HeroBanner extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final Function(MediaItem)? onPlay;
  final Function(MediaItem)? onInfo;
  final Function(MediaItem)? onWatchlist;
  final Function(MediaItem)? onWatchTogether;

  const HeroBanner({
    super.key,
    required this.items,
    this.onPlay,
    this.onInfo,
    this.onWatchlist,
    this.onWatchTogether,
  });

  @override
  ConsumerState<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<HeroBanner> {
  Timer? _autoCycleTimer;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoCycle();
  }

  @override
  void dispose() {
    _autoCycleTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoCycle() {
    _autoCycleTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final currentIndex = ref.read(heroIndexProvider);
      final nextIndex = (currentIndex + 1) % widget.items.length;
      ref.read(heroIndexProvider.notifier).state = nextIndex;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(heroIndexProvider);
    final tmdb = ref.watch(tmdbServiceProvider);
    final isDesktop = PlatformDetector.isDesktop;
    final isTV = PlatformDetector.isTV;

    if (widget.items.isEmpty) {
      return Container(
        height: isDesktop ? 500 : 300,
        color: MoonTheme.backgroundPrimary,
      );
    }

    final currentItem = widget.items[currentIndex % widget.items.length];

    return SizedBox(
      height: isDesktop ? 500 : (isTV ? 400 : 300),
      child: Stack(
        children: [
          // Backdrop images with crossfade
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              ref.read(heroIndexProvider.notifier).state = index;
            },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop
                  if (item.backdropPath != null)
                    CachedNetworkImage(
                      imageUrl: tmdb.backdropUrl(item.backdropPath),
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: MoonTheme.backgroundPrimary),
                      errorWidget: (context, url, error) =>
                          Container(color: MoonTheme.backgroundPrimary),
                    )
                  else
                    Container(color: MoonTheme.backgroundPrimary),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          MoonTheme.backgroundPrimary.withOpacity(0.8),
                          MoonTheme.backgroundPrimary,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Content overlay
          Positioned(
            bottom: isDesktop ? 60 : 40,
            left: isDesktop ? 80 : 24,
            right: isDesktop ? 80 : 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  currentItem.title,
                  style: TextStyle(
                    color: MoonTheme.textPrimary,
                    fontSize: isDesktop ? 36 : 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Rating and year
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      currentItem.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: MoonTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      currentItem.releaseYear.toString(),
                      style: const TextStyle(
                        color: MoonTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: MoonTheme.accentGlow.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentItem.mediaType == MediaType.movie
                            ? 'MOVIE'
                            : 'TV',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Overview
                if (currentItem.overview.isNotEmpty)
                  Text(
                    currentItem.overview,
                    maxLines: isDesktop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MoonTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                    // Play button
                    ElevatedButton.icon(
                      onPressed: widget.onPlay != null
                          ? () => widget.onPlay!(currentItem)
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 24),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MoonTheme.accentPrimary,
                        foregroundColor: MoonTheme.backgroundPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : 16,
                          vertical: isDesktop ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info button
                    OutlinedButton.icon(
                      onPressed: widget.onInfo != null
                          ? () => widget.onInfo!(currentItem)
                          : null,
                      icon: const Icon(Icons.info_outline, size: 20),
                      label: const Text('More Info'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MoonTheme.textPrimary,
                        side: const BorderSide(color: MoonTheme.textSecondary),
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 20 : 16,
                          vertical: isDesktop ? 14 : 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Watchlist button
                    IconButton(
                      onPressed: widget.onWatchlist != null
                          ? () => widget.onWatchlist!(currentItem)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: MoonTheme.textPrimary,
                      iconSize: 28,
                      tooltip: 'Add to Watchlist',
                    ),
                    // Watch Together button
                    IconButton(
                      onPressed: widget.onWatchTogether != null
                          ? () => widget.onWatchTogether!(currentItem)
                          : null,
                      icon: const Icon(Icons.people_outline),
                      color: MoonTheme.textPrimary,
                      iconSize: 28,
                      tooltip: 'Watch Together',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Page indicators
          Positioned(
            bottom: 16,
            right: isDesktop ? 80 : 24,
            child: Row(
              children: List.generate(
                widget.items.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == currentIndex ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == currentIndex
                        ? MoonTheme.accentPrimary
                        : MoonTheme.textMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============== HOME SCREEN ==============

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Route to platform-specific implementation
    if (PlatformDetector.isTV) {
      return const TvHomeScreen();
    } else if (PlatformDetector.isDesktop) {
      return const DesktopHomeScreen();
    } else {
      return const MobileHomeScreen();
    }
  }
}

// ============== MOBILE HOME SCREEN ==============

class MobileHomeScreen extends ConsumerWidget {
  const MobileHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingMovies = ref.watch(trendingMoviesProvider);
    final trendingTv = ref.watch(trendingTvProvider);
    final continueWatching = ref.watch(continueWatchingProvider);
    final tmdb = ref.watch(tmdbServiceProvider);

    return Scaffold(
      backgroundColor: MoonTheme.backgroundPrimary,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(trendingMoviesProvider);
          ref.invalidate(trendingTvProvider);
          ref.invalidate(continueWatchingProvider);
        },
        color: MoonTheme.accentPrimary,
        backgroundColor: MoonTheme.backgroundSecondary,
        child: CustomScrollView(
          slivers: [
            // Hero Banner
            SliverToBoxAdapter(
              child: trendingMovies.when(
                data: (movies) => HeroBanner(
                  items: movies.take(5).toList(),
                  onPlay: (item) => _navigateToDetail(context, item),
                  onInfo: (item) => _navigateToDetail(context, item),
                ),
                loading: () => Container(
                  height: 300,
                  color: MoonTheme.backgroundPrimary,
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: MoonTheme.accentPrimary),
                  ),
                ),
                error: (_, __) => Container(
                  height: 300,
                  color: MoonTheme.backgroundPrimary,
                ),
              ),
            ),
            // Continue Watching
            continueWatching.when(
              data: (items) {
                if (items.isEmpty)
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: _buildContinueWatching(items, tmdb),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            // Trending Movies
            trendingMovies.when(
              data: (movies) => SliverToBoxAdapter(
                child: ContentShelf(
                  title: 'Trending Movies',
                  items: movies,
                  onItemTap: (item) => _navigateToDetail(context, item),
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                        color: MoonTheme.accentPrimary),
                  ),
                ),
              ),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            // Trending TV
            trendingTv.when(
              data: (shows) => SliverToBoxAdapter(
                child: ContentShelf(
                  title: 'Trending TV Shows',
                  items: shows,
                  onItemTap: (item) => _navigateToDetail(context, item),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueWatching(
      List<ContinueWatchingData> items, TmdbService tmdb) {
    final mediaItems = items.map((data) {
      return MediaItem(
        id: data.id,
        tmdbId: data.tmdbId ?? 0,
        title: data.title,
        posterPath: data.posterPath,
        backdropPath: null,
        overview: '',
        rating: 0,
        releaseYear: 0,
        mediaType: data.mediaType == 'movie' ? MediaType.movie : MediaType.tv,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Continue Watching',
            style: TextStyle(
              color: MoonTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              final data = items[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ContinueWatchingCard(
                  item: item,
                  tmdb: tmdb,
                  progress: data.durationSeconds > 0
                      ? data.positionSeconds / data.durationSeconds
                      : 0,
                  onTap: () => _navigateToDetail(context, item),
                ),
              );
            },
          ),
        ),
      ],
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

class _ContinueWatchingCard extends StatelessWidget {
  final MediaItem item;
  final double progress;
  final TmdbService tmdb;
  final VoidCallback? onTap;

  const _ContinueWatchingCard({
    required this.item,
    required this.progress,
    required this.tmdb,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with progress
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.posterPath != null
                      ? Image.network(
                          tmdb.posterUrl(item.posterPath, size: 'w300'),
                          width: 280,
                          height: 140,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 280,
                          height: 140,
                          color: MoonTheme.backgroundCard,
                          child: const Icon(Icons.movie,
                              color: MoonTheme.textMuted),
                        ),
                ),
                // Progress bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: MoonTheme.backgroundCard.withOpacity(0.8),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        color: MoonTheme.accentPrimary,
                      ),
                    ),
                  ),
                ),
                // Play icon overlay
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MoonTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============== TV HOME SCREEN ==============

class TvHomeScreen extends ConsumerWidget {
  const TvHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingMovies = ref.watch(trendingMoviesProvider);
    final trendingTv = ref.watch(trendingTvProvider);

    return Scaffold(
      backgroundColor: MoonTheme.backgroundPrimary,
      body: trendingMovies.when(
        data: (movies) {
          return CustomScrollView(
            slivers: [
              // Hero Banner
              SliverToBoxAdapter(
                child: HeroBanner(
                  items: movies.take(5).toList(),
                  onPlay: (item) => _navigateToDetail(context, item),
                  onInfo: (item) => _navigateToDetail(context, item),
                ),
              ),
              // Trending Movies
              SliverToBoxAdapter(
                child: ContentShelf(
                  title: 'Trending Movies',
                  items: movies,
                  onItemTap: (item) => _navigateToDetail(context, item),
                ),
              ),
              // Trending TV
              trendingTv.when(
                data: (shows) => SliverToBoxAdapter(
                  child: ContentShelf(
                    title: 'Trending TV Shows',
                    items: shows,
                    onItemTap: (item) => _navigateToDetail(context, item),
                  ),
                ),
                loading: () =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: MoonTheme.accentPrimary),
        ),
        error: (_, __) => const Center(
          child: Text(
            'Failed to load content',
            style: TextStyle(color: MoonTheme.textPrimary),
          ),
        ),
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

// ============== DESKTOP HOME SCREEN ==============

class DesktopHomeScreen extends ConsumerWidget {
  const DesktopHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingMovies = ref.watch(trendingMoviesProvider);
    final trendingTv = ref.watch(trendingTvProvider);
    final continueWatching = ref.watch(continueWatchingProvider);

    return Scaffold(
      backgroundColor: MoonTheme.backgroundPrimary,
      body: CustomScrollView(
        slivers: [
          // Hero Banner
          SliverToBoxAdapter(
            child: trendingMovies.when(
              data: (movies) => HeroBanner(
                items: movies.take(5).toList(),
                onPlay: (item) => _navigateToDetail(context, item),
                onInfo: (item) => _navigateToDetail(context, item),
              ),
              loading: () => Container(
                height: 500,
                color: MoonTheme.backgroundPrimary,
                child: const Center(
                  child:
                      CircularProgressIndicator(color: MoonTheme.accentPrimary),
                ),
              ),
              error: (_, __) => Container(
                height: 500,
                color: MoonTheme.backgroundPrimary,
              ),
            ),
          ),
          // Continue Watching
          continueWatching.when(
            data: (items) {
              if (items.isEmpty)
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: _buildContinueWatchingDesktop(items),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // Trending Movies
          trendingMovies.when(
            data: (movies) => SliverToBoxAdapter(
              child: ContentShelf(
                title: 'Trending Movies',
                items: movies,
                onItemTap: (item) => _navigateToDetail(context, item),
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // Trending TV
          trendingTv.when(
            data: (shows) => SliverToBoxAdapter(
              child: ContentShelf(
                title: 'Trending TV Shows',
                items: shows,
                onItemTap: (item) => _navigateToDetail(context, item),
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildContinueWatchingDesktop(List<ContinueWatchingData> items) {
    final mediaItems = items.map((data) {
      return MediaItem(
        id: data.id,
        tmdbId: data.tmdbId ?? 0,
        title: data.title,
        posterPath: data.posterPath,
        backdropPath: null,
        overview: '',
        rating: 0,
        releaseYear: 0,
        mediaType: data.mediaType == 'movie' ? MediaType.movie : MediaType.tv,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            'Continue Watching',
            style: TextStyle(
              color: MoonTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              final data = items[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _ContinueWatchingCardDesktop(
                  item: item,
                  progress: data.durationSeconds > 0
                      ? data.positionSeconds / data.durationSeconds
                      : 0,
                  onTap: () {},
                ),
              );
            },
          ),
        ),
      ],
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

class _ContinueWatchingCardDesktop extends StatelessWidget {
  final MediaItem item;
  final double progress;
  final VoidCallback? onTap;

  const _ContinueWatchingCardDesktop({
    required this.item,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail with progress
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w400${item.posterPath}',
                            width: 320,
                            height: 160,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 320,
                              height: 160,
                              color: MoonTheme.backgroundCard,
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 320,
                              height: 160,
                              color: MoonTheme.backgroundCard,
                              child: const Icon(Icons.movie,
                                  color: MoonTheme.textMuted),
                            ),
                          )
                        : Container(
                            width: 320,
                            height: 160,
                            color: MoonTheme.backgroundCard,
                            child: const Icon(Icons.movie,
                                color: MoonTheme.textMuted),
                          ),
                  ),
                  // Progress bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: MoonTheme.backgroundCard.withOpacity(0.8),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          color: MoonTheme.accentPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MoonTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
