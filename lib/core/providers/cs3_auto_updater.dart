import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'repo_fetcher.dart';

/// Provider for CS3AutoUpdater
final cs3AutoUpdaterProvider = Provider<CS3AutoUpdater>((ref) {
  return CS3AutoUpdater();
});

/// Update check result
class UpdateCheckResult {
  final String internalName;
  final bool hasUpdate;
  final int currentVersion;
  final int newVersion;

  UpdateCheckResult({
    required this.internalName,
    required this.hasUpdate,
    required this.currentVersion,
    required this.newVersion,
  });
}

/// CS3 Auto Updater
/// Downloads and updates CS3 provider files
class CS3AutoUpdater {
  late final Dio _dio;

  CS3AutoUpdater() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ));
  }

  /// Get the CS3 storage directory for the current platform
  Future<Directory> get _cs3Directory async {
    final appDir = await getApplicationDocumentsDirectory();
    final cs3Dir = Directory('${appDir.path}/cs3_providers');
    if (!await cs3Dir.exists()) {
      await cs3Dir.create(recursive: true);
    }
    return cs3Dir;
  }

  /// Check for updates and download if needed
  /// Returns list of update results
  Future<List<UpdateCheckResult>> checkAndUpdate(
    List<PluginInfo> plugins,
  ) async {
    final results = <UpdateCheckResult>[];
    final cs3Dir = await _cs3Directory;

    for (final plugin in plugins) {
      final currentVersion = await getLocalVersion(plugin.internalName);
      final needsUpdate = currentVersion < plugin.version;

      results.add(UpdateCheckResult(
        internalName: plugin.internalName,
        hasUpdate: needsUpdate,
        currentVersion: currentVersion,
        newVersion: plugin.version,
      ));

      if (needsUpdate) {
        await downloadProvider(plugin, cs3Dir);
      }
    }

    return results;
  }

  /// Download a provider file
  Future<void> downloadProvider(
    PluginInfo plugin,
    Directory targetDir,
  ) async {
    try {
      final fileName = '${plugin.internalName}.jar';
      final filePath = '${targetDir.path}/$fileName';

      debugPrint('Downloading provider ${plugin.name} to $filePath');

      await _dio.download(
        plugin.url,
        filePath,
        options: Options(
          headers: {
            'Accept': '*/*',
          },
        ),
      );

      // Create metadata file
      final metaPath = '${targetDir.path}/${plugin.internalName}.meta';
      final metaFile = File(metaPath);
      await metaFile.writeAsString(
        '${plugin.version}|${DateTime.now().toIso8601String()}',
      );

      debugPrint('Downloaded ${plugin.name} v${plugin.version}');
    } catch (e) {
      debugPrint('Error downloading ${plugin.name}: $e');
      rethrow;
    }
  }

  /// Get local version of a provider, returns 0 if not installed
  Future<int> getLocalVersion(String internalName) async {
    try {
      final cs3Dir = await _cs3Directory;
      final metaFile = File('${cs3Dir.path}/$internalName.meta');
      
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final parts = content.split('|');
        if (parts.isNotEmpty) {
          return int.tryParse(parts[0]) ?? 0;
        }
      }
    } catch (e) {
      debugPrint('Error reading local version for $internalName: $e');
    }
    return 0;
  }

  /// Get path to a local provider file
  Future<String?> getProviderPath(String internalName) async {
    final cs3Dir = await _cs3Directory;
    final filePath = '${cs3Dir.path}/$internalName.jar';
    final file = File(filePath);
    
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  /// Get all installed providers
  Future<List<String>> getInstalledProviders() async {
    final cs3Dir = await _cs3Directory;
    final installed = <String>[];
    
    try {
      await for (final entity in cs3Dir.list()) {
        if (entity is File && entity.path.endsWith('.jar')) {
          final name = entity.path
              .split('/')
              .last
              .replaceAll('.jar', '');
          installed.add(name);
        }
      }
    } catch (e) {
      debugPrint('Error listing providers: $e');
    }
    
    return installed;
  }

  /// Delete a provider
  Future<void> deleteProvider(String internalName) async {
    final cs3Dir = await _cs3Directory;
    
    final jarFile = File('${cs3Dir.path}/$internalName.jar');
    if (await jarFile.exists()) {
      await jarFile.delete();
    }
    
    final metaFile = File('${cs3Dir.path}/$internalName.meta');
    if (await metaFile.exists()) {
      await metaFile.delete();
    }
  }

  /// Clear all providers
  Future<void> clearAllProviders() async {
    final cs3Dir = await _cs3Directory;
    
    try {
      await for (final entity in cs3Dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('Error clearing providers: $e');
    }
  }
}
