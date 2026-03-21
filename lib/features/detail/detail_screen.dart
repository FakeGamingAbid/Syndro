import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:moonplex/core/platform/platform_detector.dart';
import 'package:moonplex/core/tmdb/tmdb_service.dart';
import 'package:moonplex/core/providers/providers.dart';
import 'package:moonplex/core/theme/moon_theme.dart';
import 'package:moonplex/features/player/player_screen.dart';

// ============== PROVIDERS ==============

final detailProvider =
    FutureProvider.family<dynamic, ({int tmdbId, MediaType mediaType})>(
        (ref, params) async {
  final tmdb = ref.read(tmdbServiceProvider);
  if (params.mediaType == MediaType.movie) {
    return tmdb.getMovieDetail(params.tmdbId);
  } else {
    return tmdb.getTvDetail(params.tmdbId);
  }
});

final sourcesProvider = FutureProvider<List<SourceLink>>((ref) async {
  final params = ref.watch(detailParamsProvider);
  if (params == null) return [];

  // Return empty list for now - sources will be fetched differently
  return [];
});

final detailParamsProvider =
    StateProvider<({int tmdbId, MediaType mediaType})?>((ref) => null);
final selectedSeasonProvider = StateProvider<int>((ref) => 1);
final isInWatchlistProvider = StateProvider<bool>((ref) => false);



// ============== SOURCE LINK MODEL ==============

class SourceLink {
  final String name;
  final String url;
  final String quality;
  final bool isDirect;

  SourceLink({
    required this.name,
    required this.url,
    required this.quality,
    this.isDirect = false,
  });
}

// ============== DETAIL SCREEN ==============

class DetailScreen extends ConsumerStatefulWidget {
  final int tmdbId;
  final MediaType mediaType;

  const DetailScreen({
    super.key,
    required this.tmdbId,
    required this.mediaType,
  });

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  bool _isOverviewExpanded = false;

  @override
  void initState() {
    super.initState();
    // Set params for providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(detailParamsProvider.notifier).state = (
        tmdbId: widget.tmdbId,
        mediaType: widget.mediaType,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
        detailProvider((tmdbId: widget.tmdbId, mediaType: widget.mediaType)));
    final isTV = PlatformDetector.isTV;
    final isDesktop = PlatformDetector.isDesktop;

    return Scaffold(
      backgroundColor: MoonTheme.backgroundPrimary,
      body: detailAsync.when(
        data: (detail) => _buildContent(context, detail, isTV, isDesktop),
        loading: () => _buildLoading(),
        error: (error, _) => _buildError(error),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, dynamic detail, bool isTV, bool isDesktop) {
    final tmdb = ref.read(tmdbServiceProvider);

    return CustomScrollView(
      slivers: [
        // Hero backdrop
        SliverToBoxAdapter(
          child: Stack(
            children: [
              // Backdrop
              SizedBox(
                height: isDesktop ? 500 : 350,
                width: double.infinity,
                child: detail.backdropPath != null
                    ? CachedNetworkImage(
                        imageUrl: tmdb.backdropUrl(detail.backdropPath),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: MoonTheme.backgroundPrimary,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: MoonTheme.backgroundPrimary,
                        ),
                      )
                    : Container(color: MoonTheme.backgroundPrimary),
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
                        MoonTheme.backgroundPrimary.withOpacity(0.5),
                        MoonTheme.backgroundPrimary,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: MoonTheme.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  detail.title,
                  style: TextStyle(
                    color: MoonTheme.textPrimary,
                    fontSize: isDesktop ? 36 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Meta info
                Row(
                  children: [
                    if (detail.rating > 0) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        detail.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: MoonTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Text(
                      detail.releaseYear.toString(),
                      style: const TextStyle(
                        color: MoonTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    if (detail.runtime > 0) ...[
                      const SizedBox(width: 16),
                      Text(
                        _formatRuntime(detail.runtime),
                        style: const TextStyle(
                          color: MoonTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Genre tags
                if (detail.genres.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detail.genres.map<Widget>((genre) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: MoonTheme.accentGlow.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: MoonTheme.cardBorder),
                        ),
                        child: Text(
                          genre.name,
                          style: const TextStyle(
                            color: MoonTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),
                // Action buttons
                _buildActionButtons(detail),
                const SizedBox(height: 24),
                // Tagline
                if (detail.tagline != null && detail.tagline!.isNotEmpty) ...[
                  Text(
                    '"${detail.tagline}"',
                    style: const TextStyle(
                      color: MoonTheme.accentSecondary,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Overview
                Text(
                  'Overview',
                  style: TextStyle(
                    color: MoonTheme.textPrimary,
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.overview,
                  maxLines: _isOverviewExpanded ? null : 3,
                  overflow: _isOverviewExpanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MoonTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (detail.overview.length > 150)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isOverviewExpanded = !_isOverviewExpanded;
                      });
                    },
                    child:
                        Text(_isOverviewExpanded ? 'Show Less' : 'Read More'),
                  ),
                const SizedBox(height: 24),
                // Cast
                if (detail.cast.isNotEmpty) _buildCastRow(detail.cast, tmdb),
                const SizedBox(height: 24),
                // TV Show specific: Seasons and Episodes
                if (widget.mediaType == MediaType.tv)
                  _buildSeasonsSection(detail),
                // Sources section
                _buildSourcesSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(dynamic detail) {
    final isTV = PlatformDetector.isTV;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Play button
        ElevatedButton.icon(
          onPressed: () => _playContent(detail),
          icon: const Icon(Icons.play_arrow, size: 24),
          label: const Text('Play'),
          style: ElevatedButton.styleFrom(
            backgroundColor: MoonTheme.accentPrimary,
            foregroundColor: MoonTheme.backgroundPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        // Download button (not on TV)
        if (!isTV)
          OutlinedButton.icon(
            onPressed: () => _showDownloadDialog(detail),
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MoonTheme.textPrimary,
              side: const BorderSide(color: MoonTheme.textSecondary),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        // Watchlist button
        OutlinedButton.icon(
          onPressed: () => _toggleWatchlist(detail),
          icon: Icon(
            ref.watch(isInWatchlistProvider)
                ? Icons.check_circle
                : Icons.add_circle_outline,
            size: 20,
          ),
          label: Text(
              ref.watch(isInWatchlistProvider) ? 'In Watchlist' : 'Watchlist'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ref.watch(isInWatchlistProvider)
                ? MoonTheme.success
                : MoonTheme.textPrimary,
            side: BorderSide(
              color: ref.watch(isInWatchlistProvider)
                  ? MoonTheme.success
                  : MoonTheme.textSecondary,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        // Watch Together button
        OutlinedButton.icon(
          onPressed: () => _startWatchTogether(detail),
          icon: const Icon(Icons.people_outline, size: 20),
          label: const Text('Watch Together'),
          style: OutlinedButton.styleFrom(
            foregroundColor: MoonTheme.textPrimary,
            side: const BorderSide(color: MoonTheme.textSecondary),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildCastRow(List<CastMember> cast, TmdbService tmdb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cast',
          style: TextStyle(
            color: MoonTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            itemBuilder: (context, index) {
              final member = cast[index];
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    // Profile image
                    ClipOval(
                      child: member.profilePath != null
                          ? CachedNetworkImage(
                              imageUrl: tmdb.profileUrl(member.profilePath),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 70,
                                height: 70,
                                color: MoonTheme.backgroundCard,
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 70,
                                height: 70,
                                color: MoonTheme.backgroundCard,
                                child: const Icon(Icons.person,
                                    color: MoonTheme.textMuted),
                              ),
                            )
                          : Container(
                              width: 70,
                              height: 70,
                              color: MoonTheme.backgroundCard,
                              child: const Icon(Icons.person,
                                  color: MoonTheme.textMuted),
                            ),
                    ),
                    const SizedBox(height: 8),
                    // Name
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: MoonTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Character
                    Text(
                      member.character,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: MoonTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonsSection(TvDetail detail) {
    final selectedSeason = ref.watch(selectedSeasonProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seasons',
          style: TextStyle(
            color: MoonTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Season selector
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: detail.seasons.length,
            itemBuilder: (context, index) {
              final season = detail.seasons[index];
              final isSelected = season.seasonNumber == selectedSeason;
              return GestureDetector(
                onTap: () {
                  ref.read(selectedSeasonProvider.notifier).state =
                      season.seasonNumber;
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MoonTheme.accentGlow
                        : MoonTheme.backgroundCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? MoonTheme.accentGlow
                          : MoonTheme.cardBorder,
                    ),
                  ),
                  child: Text(
                    'Season ${season.seasonNumber}',
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : MoonTheme.textSecondary,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Episodes list
        FutureBuilder<SeasonDetail>(
          future: _loadSeason(detail.tmdbId, selectedSeason),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(color: MoonTheme.accentPrimary),
              );
            }
            if (!snapshot.hasData || snapshot.data!.episodes.isEmpty) {
              return const Text(
                'No episodes available',
                style: TextStyle(color: MoonTheme.textMuted),
              );
            }
            final episodes = snapshot.data!.episodes;
            return Column(
              children: episodes.map((episode) {
                return _EpisodeCard(
                  episode: episode,
                  seasonNumber: selectedSeason,
                  onPlay: () => _playEpisode(detail, episode),
                  onDownload: () => _downloadEpisode(detail, episode),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<SeasonDetail> _loadSeason(int tvId, int seasonNumber) async {
    final tmdb = ref.read(tmdbServiceProvider);
    return tmdb.getSeason(tvId, seasonNumber);
  }

  Widget _buildSourcesSection() {
    final sourcesAsync = ref.watch(sourcesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Sources',
          style: TextStyle(
            color: MoonTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        sourcesAsync.when(
          data: (sources) {
            if (sources.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: MoonTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MoonTheme.cardBorder),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.source, color: MoonTheme.textMuted, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'No sources found',
                      style: TextStyle(
                        color: MoonTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Searching providers...',
                      style: TextStyle(
                        color: MoonTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: sources.map((source) {
                return _SourceCard(
                  source: source,
                  onTap: () => _playSource(source),
                );
              }).toList(),
            );
          },
          loading: () => Column(
            children: List.generate(3, (index) => _shimmerSourceCard()),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MoonTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Failed to load sources',
              style: TextStyle(color: MoonTheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerSourceCard() {
    return Shimmer.fromColors(
      baseColor: MoonTheme.backgroundCard,
      highlightColor: MoonTheme.backgroundSecondary,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MoonTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading...',
                    style: TextStyle(color: MoonTheme.textMuted),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '...',
                    style: TextStyle(color: MoonTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: MoonTheme.accentPrimary),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: MoonTheme.error, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load content',
            style: TextStyle(color: MoonTheme.textPrimary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(color: MoonTheme.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(detailProvider(
                  (tmdbId: widget.tmdbId, mediaType: widget.mediaType)));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatRuntime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  void _playContent(dynamic detail) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          contentId: detail.tmdbId?.toString() ?? '',
          title: detail.title,
          providerInternalName: 'default',
          linkId: '0',
        ),
      ),
    );
  }

  void _playEpisode(TvDetail detail, Episode episode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          contentId: '${detail.tmdbId}_${episode.episodeNumber}',
          title: '${detail.title} - S${episode.episodeNumber}',
          providerInternalName: 'default',
          linkId: '0',
        ),
      ),
    );
  }

  void _playSource(SourceLink source) {
    // TODO: Play with specific source
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing from ${source.name}'),
        backgroundColor: MoonTheme.backgroundCard,
      ),
    );
  }

  void _showDownloadDialog(dynamic detail) {
    // TODO: Show quality picker dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download feature coming soon'),
        backgroundColor: MoonTheme.backgroundCard,
      ),
    );
  }

  void _downloadEpisode(TvDetail detail, Episode episode) {
    if (PlatformDetector.isTV) return;
    // TODO: Download episode
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download feature coming soon'),
        backgroundColor: MoonTheme.backgroundCard,
      ),
    );
  }

  void _toggleWatchlist(dynamic detail) {
    final current = ref.read(isInWatchlistProvider);
    ref.read(isInWatchlistProvider.notifier).state = !current;
    // TODO: Save to database
  }

  void _startWatchTogether(dynamic detail) {
    // TODO: Open Watch Together screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Watch Together coming soon'),
        backgroundColor: MoonTheme.backgroundCard,
      ),
    );
  }
}

// ============== EPISODE CARD ==============

class _EpisodeCard extends StatelessWidget {
  final Episode episode;
  final int seasonNumber;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;

  const _EpisodeCard({
    required this.episode,
    required this.seasonNumber,
    this.onPlay,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformDetector.isTV;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MoonTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MoonTheme.cardBorder),
      ),
      child: Row(
        children: [
          // Episode thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: episode.stillPath != null
                ? CachedNetworkImage(
                    imageUrl:
                        'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                    width: 160,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 160,
                      height: 90,
                      color: MoonTheme.backgroundSecondary,
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 160,
                      height: 90,
                      color: MoonTheme.backgroundSecondary,
                      child: const Icon(Icons.tv, color: MoonTheme.textMuted),
                    ),
                  )
                : Container(
                    width: 160,
                    height: 90,
                    color: MoonTheme.backgroundSecondary,
                    child: const Icon(Icons.tv, color: MoonTheme.textMuted),
                  ),
          ),
          const SizedBox(width: 12),
          // Episode info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E${episode.episodeNumber}: ${episode.title}',
                  style: const TextStyle(
                    color: MoonTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (episode.airDate != null)
                  Text(
                    episode.airDate!,
                    style: const TextStyle(
                      color: MoonTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                if (episode.overview != null &&
                    episode.overview!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    episode.overview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MoonTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Action buttons
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.play_circle_fill,
                    color: MoonTheme.accentPrimary),
                onPressed: onPlay,
              ),
              if (!isTV)
                IconButton(
                  icon: const Icon(Icons.download,
                      color: MoonTheme.textSecondary),
                  onPressed: onDownload,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============== SOURCE CARD ==============

class _SourceCard extends StatelessWidget {
  final SourceLink source;
  final VoidCallback? onTap;

  const _SourceCard({
    required this.source,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MoonTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MoonTheme.cardBorder),
        ),
        child: Row(
          children: [
            // Provider icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MoonTheme.accentGlow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_circle_outline,
                color: MoonTheme.accentPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Source info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    style: const TextStyle(
                      color: MoonTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getQualityColor(source.quality),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          source.quality,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (source.isDirect) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Direct',
                          style: TextStyle(
                            color: MoonTheme.success,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Play icon
            const Icon(
              Icons.chevron_right,
              color: MoonTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Color _getQualityColor(String quality) {
    switch (quality.toUpperCase()) {
      case '4K':
      case '2160P':
        return Colors.purple;
      case '1080P':
        return Colors.green;
      case '720P':
        return Colors.blue;
      case '480P':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}


