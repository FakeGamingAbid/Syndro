import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonplex/core/database/app_database.dart';
import 'package:moonplex/core/tmdb/tmdb_service.dart';

/// Canonical provider for the app database.
/// Override in ProviderScope with a real instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden at app startup');
});

/// Canonical provider for the TMDB service.
final tmdbServiceProvider = Provider<TmdbService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TmdbService(db);
});

/// Re-export providerManagerProvider from provider_manager.dart
/// so consumers can import from a single location.
/// The canonical definition lives in provider_manager.dart as a
/// StateNotifierProvider<ProviderManager, ProviderManagerState>.
