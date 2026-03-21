import 'package:dio/dio.dart';
import 'package:moonplex/core/database/app_database.dart';
import 'package:moonplex/core/config/remote_config_service.dart';

enum MediaType { movie, tv }

enum TimeWindow { day, week }

// ============== MODELS ==============

class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(id: json['id'] as int, name: json['name'] as String);
  }
}

class CastMember {
  final String name;
  final String character;
  final String? profilePath;

  CastMember({required this.name, required this.character, this.profilePath});

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      name: json['name'] as String? ?? '',
      character: json['character'] as String? ?? '',
      profilePath: json['profile_path'] as String?,
    );
  }
}

class Season {
  final int seasonNumber;
  final String? posterPath;
  final String? airDate;
  final int episodeCount;

  Season({
    required this.seasonNumber,
    this.posterPath,
    this.airDate,
    required this.episodeCount,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      seasonNumber: json['season_number'] as int,
      posterPath: json['poster_path'] as String?,
      airDate: json['air_date'] as String?,
      episodeCount: json['episode_count'] as int? ?? 0,
    );
  }
}

class Episode {
  final int episodeNumber;
  final String title;
  final String? overview;
  final String? airDate;
  final String? stillPath;
  final double rating;

  Episode({
    required this.episodeNumber,
    required this.title,
    this.overview,
    this.airDate,
    this.stillPath,
    required this.rating,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      episodeNumber: json['episode_number'] as int,
      title: json['name'] as String? ?? 'Episode ${json['episode_number']}',
      overview: json['overview'] as String?,
      airDate: json['air_date'] as String?,
      stillPath: json['still_path'] as String?,
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MediaItem {
  final int id;
  final int tmdbId;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String overview;
  final double rating;
  final int releaseYear;
  final MediaType mediaType;
  final List<int> genreIds;

  MediaItem({
    required this.id,
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.overview,
    required this.rating,
    required this.releaseYear,
    required this.mediaType,
    this.genreIds = const [],
  });

  factory MediaItem.fromJson(Map<String, dynamic> json, MediaType type) {
    final releaseDate = json['release_date'] as String? ??
        json['first_air_date'] as String? ??
        '';
    return MediaItem(
      id: json['id'] as int,
      tmdbId: json['id'] as int,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      overview: json['overview'] as String? ?? '',
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseYear: releaseDate.isNotEmpty
          ? int.tryParse(releaseDate.substring(0, 4)) ?? 0
          : 0,
      mediaType: type,
      genreIds: (json['genre_ids'] as List<dynamic>?)?.cast<int>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tmdbId': tmdbId,
        'title': title,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'overview': overview,
        'rating': rating,
        'releaseYear': releaseYear,
        'mediaType': mediaType.name,
        'genreIds': genreIds,
      };

  factory MediaItem.fromCacheJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as int,
      tmdbId: json['tmdbId'] as int,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      overview: json['overview'] as String,
      rating: (json['rating'] as num).toDouble(),
      releaseYear: json['releaseYear'] as int,
      mediaType: json['mediaType'] == 'movie' ? MediaType.movie : MediaType.tv,
      genreIds: (json['genreIds'] as List<dynamic>).cast<int>(),
    );
  }
}

class MovieDetail extends MediaItem {
  final String? imdbId;
  final int runtime;
  final List<Genre> genres;
  final List<CastMember> cast;
  final List<String> directors;
  final String? tagline;

  MovieDetail({
    required super.id,
    required super.tmdbId,
    required super.title,
    super.posterPath,
    super.backdropPath,
    required super.overview,
    required super.rating,
    required super.releaseYear,
    required super.mediaType,
    super.genreIds,
    this.imdbId,
    required this.runtime,
    this.genres = const [],
    this.cast = const [],
    this.directors = const [],
    this.tagline,
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    final credits = json['credits'] as Map<String, dynamic>? ?? {};
    final crew = credits['crew'] as List<dynamic>? ?? [];
    final directors = crew
        .where((c) => c['job'] == 'Director')
        .map((c) => c['name'] as String)
        .toList();

    return MovieDetail(
      id: json['id'] as int,
      tmdbId: json['id'] as int,
      title: json['title'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      overview: json['overview'] as String? ?? '',
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseYear: json['release_date'] != null &&
              (json['release_date'] as String).length >= 4
          ? int.parse((json['release_date'] as String).substring(0, 4))
          : 0,
      mediaType: MediaType.movie,
      imdbId: json['imdb_id'] as String?,
      runtime: json['runtime'] as int? ?? 0,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => Genre.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      cast: (credits['cast'] as List<dynamic>?)
              ?.take(20)
              .map((c) => CastMember.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      directors: directors,
      tagline: json['tagline'] as String?,
    );
  }
}

class TvDetail extends MediaItem {
  final String? imdbId;
  final List<Season> seasons;
  final int totalEpisodes;
  final String status;
  final List<Genre> genres;
  final List<CastMember> cast;

  TvDetail({
    required super.id,
    required super.tmdbId,
    required super.title,
    super.posterPath,
    super.backdropPath,
    required super.overview,
    required super.rating,
    required super.releaseYear,
    required super.mediaType,
    super.genreIds,
    this.imdbId,
    required this.seasons,
    required this.totalEpisodes,
    required this.status,
    this.genres = const [],
    this.cast = const [],
  });

  factory TvDetail.fromJson(Map<String, dynamic> json) {
    final seasons = (json['seasons'] as List<dynamic>?)
            ?.where((s) => (s as Map<String, dynamic>)['season_number'] != 0)
            .map((s) => Season.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    final credits = json['credits'] as Map<String, dynamic>? ?? {};

    return TvDetail(
      id: json['id'] as int,
      tmdbId: json['id'] as int,
      title: json['name'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      overview: json['overview'] as String? ?? '',
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseYear: json['first_air_date'] != null &&
              (json['first_air_date'] as String).length >= 4
          ? int.parse((json['first_air_date'] as String).substring(0, 4))
          : 0,
      mediaType: MediaType.tv,
      imdbId: json['imdb_id'] as String?,
      seasons: seasons,
      totalEpisodes: json['number_of_episodes'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => Genre.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      cast: (credits['cast'] as List<dynamic>?)
              ?.take(20)
              .map((c) => CastMember.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SeasonDetail {
  final int tvId;
  final int seasonNumber;
  final String? posterPath;
  final List<Episode> episodes;

  SeasonDetail({
    required this.tvId,
    required this.seasonNumber,
    this.posterPath,
    required this.episodes,
  });

  factory SeasonDetail.fromJson(
      int tvId, int seasonNumber, Map<String, dynamic> json) {
    return SeasonDetail(
      tvId: tvId,
      seasonNumber: seasonNumber,
      posterPath: json['poster_path'] as String?,
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ============== TMDB SERVICE ==============

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBase = 'https://image.tmdb.org/t/p';

  late final Dio _dio;
  final AppDatabase _db;

  TmdbService(this._db) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  String posterUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBase/$size$path';
  }

  String backdropUrl(String? path, {String size = 'original'}) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBase/$size$path';
  }

  String profileUrl(String? path, {String size = 'w185'}) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBase/$size$path';
  }

  Future<String> _getApiKey() async {
    final config = await RemoteConfigService.getConfig();
    return config['tmdb_api_key'] as String? ?? '';
  }

  Future<Map<String, dynamic>> _get(
      String endpoint, Map<String, dynamic> params) async {
    final apiKey = await _getApiKey();

    // Fetch from API
    try {
      final response = await _dio.get(endpoint, queryParameters: {
        ...params,
        'api_key': apiKey,
        'language': 'en-US',
      });

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MediaItem>> getTrending(MediaType type, TimeWindow window) async {
    final day = window == TimeWindow.day ? 'day' : 'week';
    final endpoint =
        type == MediaType.movie ? 'trending/movie/$day' : 'trending/tv/$day';

    final data = await _get(endpoint, {});
    final results = data['results'] as List<dynamic>;

    return results
        .map((json) => MediaItem.fromJson(json as Map<String, dynamic>, type))
        .toList();
  }

  Future<List<MediaItem>> search(String query, MediaType type) async {
    if (query.isEmpty) return [];

    final endpoint = type == MediaType.movie ? 'search/movie' : 'search/tv';
    final data = await _get(endpoint, {'query': query});
    final results = data['results'] as List<dynamic>;

    return results
        .map((json) => MediaItem.fromJson(json as Map<String, dynamic>, type))
        .toList();
  }

  Future<MovieDetail> getMovieDetail(int tmdbId) async {
    final data = await _get('movie/$tmdbId', {});
    return MovieDetail.fromJson(data);
  }

  Future<TvDetail> getTvDetail(int tmdbId) async {
    final data = await _get('tv/$tmdbId', {});
    return TvDetail.fromJson(data);
  }

  Future<SeasonDetail> getSeason(int tvId, int seasonNumber) async {
    final data = await _get('tv/$tvId/season/$seasonNumber', {});
    return SeasonDetail.fromJson(tvId, seasonNumber, data);
  }

  Future<List<MediaItem>> getRecommendations(int id, MediaType type) async {
    final endpoint = type == MediaType.movie
        ? 'movie/$id/recommendations'
        : 'tv/$id/recommendations';
    final data = await _get(endpoint, {});
    final results = data['results'] as List<dynamic>;

    return results
        .map((json) => MediaItem.fromJson(json as Map<String, dynamic>, type))
        .toList();
  }

  // Browse categories
  Future<List<MediaItem>> getDiscover(MediaType type,
      {int page = 1, String sortBy = 'popularity.desc'}) async {
    final endpoint = type == MediaType.movie ? 'discover/movie' : 'discover/tv';
    final data = await _get(endpoint, {'page': page, 'sort_by': sortBy});
    final results = data['results'] as List<dynamic>;

    return results
        .map((json) => MediaItem.fromJson(json as Map<String, dynamic>, type))
        .toList();
  }

  Future<List<MediaItem>> getUpcoming({int page = 1}) async {
    final data = await _get('movie/upcoming', {'page': page});
    final results = data['results'] as List<dynamic>;
    return results
        .map((json) =>
            MediaItem.fromJson(json as Map<String, dynamic>, MediaType.movie))
        .toList();
  }

  Future<List<MediaItem>> getTopRated(MediaType type, {int page = 1}) async {
    final endpoint =
        type == MediaType.movie ? 'movie/top_rated' : 'tv/top_rated';
    final data = await _get(endpoint, {'page': page});
    final results = data['results'] as List<dynamic>;
    return results
        .map((json) => MediaItem.fromJson(json as Map<String, dynamic>, type))
        .toList();
  }

  Future<List<MediaItem>> getNowPlaying(MediaType type, {int page = 1}) async {
    final endpoint =
        type == MediaType.movie ? 'movie/now_playing' : 'tv/on_the_air';
    final data = await _get(endpoint, {'page': page});
    final results = data['results'] as List<dynamic>;
    return results
        .map((json) => MediaItem.fromJson(json as Map<String, dynamic>, type))
        .toList();
  }

  // Get new episodes (airing today for TV)
  Future<List<MediaItem>> getAiringTodayTv() async {
    final data = await _get('tv/airing_today', {});
    final results = data['results'] as List<dynamic>;
    return results
        .map((json) =>
            MediaItem.fromJson(json as Map<String, dynamic>, MediaType.tv))
        .toList();
  }
}
