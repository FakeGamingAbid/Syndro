import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Profile table for user profiles with moon phase avatars
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get avatarMoonPhase => integer().withDefault(const Constant(0))();
  TextColumn get pinHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
}

/// Watch history table
class WatchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get contentId => text()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get mediaType => text()(); // movie, tv, anime
  DateTimeColumn get watchedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get tmdbId => integer().nullable()();
}

/// Watchlist table
class Watchlist extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get contentId => text()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get mediaType => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get tmdbId => integer().nullable()();
}

/// Continue watching table for resume playback
class ContinueWatching extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get contentId => text()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get mediaType => text()();
  IntColumn get positionSeconds => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  IntColumn get episodeNumber => integer().nullable()();
  IntColumn get seasonNumber => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get tmdbId => integer().nullable()();
}

/// Cached configuration table
class CachedConfig extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jsonData => text()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Downloaded content table
class DownloadedContent extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get contentId => text()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get mediaType => text()();
  TextColumn get filePath => text()();
  TextColumn get subtitlePath => text().nullable()();
  TextColumn get quality => text().withDefault(const Constant('1080p'))();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get downloadedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get tmdbId => integer().nullable()();
}

/// Subtitle preferences table
class SubtitlePreferences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get preferredLanguage => text().withDefault(const Constant('en'))();
  IntColumn get fontSize => integer().withDefault(const Constant(16))();
  TextColumn get fontColor => text().withDefault(const Constant('#FFFFFF'))();
  RealColumn get backgroundOpacity => real().withDefault(const Constant(0.5))();
  TextColumn get edgeStyle => text().withDefault(const Constant('none'))(); // none, outline, shadow
  IntColumn get position => integer().withDefault(const Constant(100))(); // vertical position from bottom
}

@DriftDatabase(tables: [
  Profiles,
  WatchHistory,
  Watchlist,
  ContinueWatching,
  CachedConfig,
  DownloadedContent,
  SubtitlePreferences,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// Initialize the database (no-op for Drift, but called for consistency)
  Future<void> init() async {
    // Drift auto-initializes the database when created
  }

  /// Get the currently active profile (synchronous getter)
  Future<Profile?> get activeProfile async => getActiveProfile();

  // ============== Profile DAO ==============
  
  Future<List<Profile>> getAllProfiles() => select(profiles).get();
  
  Future<Profile?> getActiveProfile() => 
    (select(profiles)..where((p) => p.isActive.equals(true))).getSingleOrNull();
  
  Future<int> insertProfile(ProfilesCompanion profile) =>
    into(profiles).insert(profile);
  
  Future<bool> updateProfile(Profile profile) =>
    update(profiles).replace(profile);
  
  Future<int> deleteProfile(int id) =>
    (delete(profiles)..where((p) => p.id.equals(id))).go();
  
  Future<void> setActiveProfile(int id) async {
    await (update(profiles)..where((p) => p.isActive.equals(true)))
      .write(const ProfilesCompanion(isActive: Value(false)));
    await (update(profiles)..where((p) => p.id.equals(id)))
      .write(const ProfilesCompanion(isActive: Value(true)));
  }

  // ============== Watch History DAO ==============
  
  Future<List<WatchHistoryData>> getWatchHistory(int profileId) =>
    (select(watchHistory)
      ..where((w) => w.profileId.equals(profileId))
      ..orderBy([(w) => OrderingTerm.desc(w.watchedAt)]))
    .get();
  
  Future<int> addToWatchHistory(WatchHistoryCompanion entry) =>
    into(watchHistory).insert(entry);
  
  Future<int> clearWatchHistory(int profileId) =>
    (delete(watchHistory)..where((w) => w.profileId.equals(profileId))).go();

  // ============== Watchlist DAO ==============
  
  Future<List<WatchlistData>> getWatchlist(int profileId) =>
    (select(watchlist)
      ..where((w) => w.profileId.equals(profileId))
      ..orderBy([(w) => OrderingTerm.desc(w.addedAt)]))
    .get();
  
  Future<int> addToWatchlist(WatchlistCompanion entry) =>
    into(watchlist).insert(entry);
  
  Future<int> removeFromWatchlist(int profileId, String contentId) =>
    (delete(watchlist)
      ..where((w) => w.profileId.equals(profileId) & w.contentId.equals(contentId)))
    .go();
  
  Future<bool> isInWatchlist(int profileId, String contentId) async {
    final result = await (select(watchlist)
      ..where((w) => w.profileId.equals(profileId) & w.contentId.equals(contentId)))
      .getSingleOrNull();
    return result != null;
  }

  // ============== Continue Watching DAO ==============
  
  Future<List<ContinueWatchingData>> getContinueWatching(int profileId) =>
    (select(continueWatching)
      ..where((c) => c.profileId.equals(profileId))
      ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
    .get();
  
  Future<int> upsertContinueWatching(ContinueWatchingCompanion entry) =>
    into(continueWatching).insertOnConflictUpdate(entry);
  
  Future<int> removeFromContinueWatching(int profileId, String contentId) =>
    (delete(continueWatching)
      ..where((c) => c.profileId.equals(profileId) & c.contentId.equals(contentId)))
    .go();

  // ============== Cached Config DAO ==============
  
  Future<CachedConfigData?> getCachedConfig() =>
    (select(cachedConfig)..orderBy([(c) => OrderingTerm.desc(c.cachedAt)])..limit(1))
    .getSingleOrNull();
  
  Future<int> setCachedConfig(String jsonData) async {
    await delete(cachedConfig).go();
    return into(cachedConfig).insert(CachedConfigCompanion(
      jsonData: Value(jsonData),
      cachedAt: Value(DateTime.now()),
    ));
  }

  // ============== Downloaded Content DAO ==============
  
  Future<List<DownloadedContentData>> getDownloadedContent(int profileId) =>
    (select(downloadedContent)
      ..where((d) => d.profileId.equals(profileId))
      ..orderBy([(d) => OrderingTerm.desc(d.downloadedAt)]))
    .get();
  
  Future<int> addDownloadedContent(DownloadedContentCompanion entry) =>
    into(downloadedContent).insert(entry);
  
  Future<int> removeDownloadedContent(int id) =>
    (delete(downloadedContent)..where((d) => d.id.equals(id))).go();
  
  Future<DownloadedContentData?> getDownloadByContentId(int profileId, String contentId) =>
    (select(downloadedContent)
      ..where((d) => d.profileId.equals(profileId) & d.contentId.equals(contentId)))
    .getSingleOrNull();

  // ============== Subtitle Preferences DAO ==============
  
  Future<SubtitlePreference?> getSubtitlePreferences(int profileId) =>
    (select(subtitlePreferences)..where((s) => s.profileId.equals(profileId)))
    .getSingleOrNull();
  
  Future<int> setSubtitlePreferences(SubtitlePreferencesCompanion prefs) =>
    into(subtitlePreferences).insertOnConflictUpdate(prefs);
  
  Future<int> resetSubtitlePreferences(int profileId) =>
    into(subtitlePreferences).insertOnConflictUpdate(
      SubtitlePreferencesCompanion(
        profileId: Value(profileId),
        preferredLanguage: const Value('en'),
        fontSize: const Value(16),
        fontColor: const Value('#FFFFFF'),
        backgroundOpacity: const Value(0.5),
        edgeStyle: const Value('none'),
        position: const Value(100),
      ),
    );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'moonplex.db'));
    return NativeDatabase.createInBackground(file);
  });
}
