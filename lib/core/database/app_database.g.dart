// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, Profile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _avatarMoonPhaseMeta =
      const VerificationMeta('avatarMoonPhase');
  @override
  late final GeneratedColumn<int> avatarMoonPhase = GeneratedColumn<int>(
      'avatar_moon_phase', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _pinHashMeta =
      const VerificationMeta('pinHash');
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
      'pin_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, avatarMoonPhase, pinHash, createdAt, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<Profile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_moon_phase')) {
      context.handle(
          _avatarMoonPhaseMeta,
          avatarMoonPhase.isAcceptableOrUnknown(
              data['avatar_moon_phase']!, _avatarMoonPhaseMeta));
    }
    if (data.containsKey('pin_hash')) {
      context.handle(_pinHashMeta,
          pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Profile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Profile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      avatarMoonPhase: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}avatar_moon_phase'])!,
      pinHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pin_hash']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class Profile extends DataClass implements Insertable<Profile> {
  final int id;
  final String name;
  final int avatarMoonPhase;
  final String? pinHash;
  final DateTime createdAt;
  final bool isActive;
  const Profile(
      {required this.id,
      required this.name,
      required this.avatarMoonPhase,
      this.pinHash,
      required this.createdAt,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['avatar_moon_phase'] = Variable<int>(avatarMoonPhase);
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      avatarMoonPhase: Value(avatarMoonPhase),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      createdAt: Value(createdAt),
      isActive: Value(isActive),
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Profile(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatarMoonPhase: serializer.fromJson<int>(json['avatarMoonPhase']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'avatarMoonPhase': serializer.toJson<int>(avatarMoonPhase),
      'pinHash': serializer.toJson<String?>(pinHash),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Profile copyWith(
          {int? id,
          String? name,
          int? avatarMoonPhase,
          Value<String?> pinHash = const Value.absent(),
          DateTime? createdAt,
          bool? isActive}) =>
      Profile(
        id: id ?? this.id,
        name: name ?? this.name,
        avatarMoonPhase: avatarMoonPhase ?? this.avatarMoonPhase,
        pinHash: pinHash.present ? pinHash.value : this.pinHash,
        createdAt: createdAt ?? this.createdAt,
        isActive: isActive ?? this.isActive,
      );
  Profile copyWithCompanion(ProfilesCompanion data) {
    return Profile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatarMoonPhase: data.avatarMoonPhase.present
          ? data.avatarMoonPhase.value
          : this.avatarMoonPhase,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Profile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarMoonPhase: $avatarMoonPhase, ')
          ..write('pinHash: $pinHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, avatarMoonPhase, pinHash, createdAt, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatarMoonPhase == this.avatarMoonPhase &&
          other.pinHash == this.pinHash &&
          other.createdAt == this.createdAt &&
          other.isActive == this.isActive);
}

class ProfilesCompanion extends UpdateCompanion<Profile> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> avatarMoonPhase;
  final Value<String?> pinHash;
  final Value<DateTime> createdAt;
  final Value<bool> isActive;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarMoonPhase = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.avatarMoonPhase = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Profile> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? avatarMoonPhase,
    Expression<String>? pinHash,
    Expression<DateTime>? createdAt,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatarMoonPhase != null) 'avatar_moon_phase': avatarMoonPhase,
      if (pinHash != null) 'pin_hash': pinHash,
      if (createdAt != null) 'created_at': createdAt,
      if (isActive != null) 'is_active': isActive,
    });
  }

  ProfilesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<int>? avatarMoonPhase,
      Value<String?>? pinHash,
      Value<DateTime>? createdAt,
      Value<bool>? isActive}) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarMoonPhase: avatarMoonPhase ?? this.avatarMoonPhase,
      pinHash: pinHash ?? this.pinHash,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarMoonPhase.present) {
      map['avatar_moon_phase'] = Variable<int>(avatarMoonPhase.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarMoonPhase: $avatarMoonPhase, ')
          ..write('pinHash: $pinHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $WatchHistoryTable extends WatchHistory
    with TableInfo<$WatchHistoryTable, WatchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterPathMeta =
      const VerificationMeta('posterPath');
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
      'poster_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _watchedAtMeta =
      const VerificationMeta('watchedAt');
  @override
  late final GeneratedColumn<DateTime> watchedAt = GeneratedColumn<DateTime>(
      'watched_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
      'tmdb_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        profileId,
        contentId,
        title,
        posterPath,
        mediaType,
        watchedAt,
        tmdbId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_history';
  @override
  VerificationContext validateIntegrity(Insertable<WatchHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
          _posterPathMeta,
          posterPath.isAcceptableOrUnknown(
              data['poster_path']!, _posterPathMeta));
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('watched_at')) {
      context.handle(_watchedAtMeta,
          watchedAt.isAcceptableOrUnknown(data['watched_at']!, _watchedAtMeta));
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(_tmdbIdMeta,
          tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchHistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}profile_id'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_path']),
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      watchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}watched_at'])!,
      tmdbId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tmdb_id']),
    );
  }

  @override
  $WatchHistoryTable createAlias(String alias) {
    return $WatchHistoryTable(attachedDatabase, alias);
  }
}

class WatchHistoryData extends DataClass
    implements Insertable<WatchHistoryData> {
  final int id;
  final int profileId;
  final String contentId;
  final String title;
  final String? posterPath;
  final String mediaType;
  final DateTime watchedAt;
  final int? tmdbId;
  const WatchHistoryData(
      {required this.id,
      required this.profileId,
      required this.contentId,
      required this.title,
      this.posterPath,
      required this.mediaType,
      required this.watchedAt,
      this.tmdbId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['content_id'] = Variable<String>(contentId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    map['media_type'] = Variable<String>(mediaType);
    map['watched_at'] = Variable<DateTime>(watchedAt);
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    return map;
  }

  WatchHistoryCompanion toCompanion(bool nullToAbsent) {
    return WatchHistoryCompanion(
      id: Value(id),
      profileId: Value(profileId),
      contentId: Value(contentId),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      mediaType: Value(mediaType),
      watchedAt: Value(watchedAt),
      tmdbId:
          tmdbId == null && nullToAbsent ? const Value.absent() : Value(tmdbId),
    );
  }

  factory WatchHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchHistoryData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      contentId: serializer.fromJson<String>(json['contentId']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      watchedAt: serializer.fromJson<DateTime>(json['watchedAt']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'contentId': serializer.toJson<String>(contentId),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'mediaType': serializer.toJson<String>(mediaType),
      'watchedAt': serializer.toJson<DateTime>(watchedAt),
      'tmdbId': serializer.toJson<int?>(tmdbId),
    };
  }

  WatchHistoryData copyWith(
          {int? id,
          int? profileId,
          String? contentId,
          String? title,
          Value<String?> posterPath = const Value.absent(),
          String? mediaType,
          DateTime? watchedAt,
          Value<int?> tmdbId = const Value.absent()}) =>
      WatchHistoryData(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        contentId: contentId ?? this.contentId,
        title: title ?? this.title,
        posterPath: posterPath.present ? posterPath.value : this.posterPath,
        mediaType: mediaType ?? this.mediaType,
        watchedAt: watchedAt ?? this.watchedAt,
        tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
      );
  WatchHistoryData copyWithCompanion(WatchHistoryCompanion data) {
    return WatchHistoryData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      title: data.title.present ? data.title.value : this.title,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      watchedAt: data.watchedAt.present ? data.watchedAt.value : this.watchedAt,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('mediaType: $mediaType, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, contentId, title, posterPath,
      mediaType, watchedAt, tmdbId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.contentId == this.contentId &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.mediaType == this.mediaType &&
          other.watchedAt == this.watchedAt &&
          other.tmdbId == this.tmdbId);
}

class WatchHistoryCompanion extends UpdateCompanion<WatchHistoryData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> contentId;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<String> mediaType;
  final Value<DateTime> watchedAt;
  final Value<int?> tmdbId;
  const WatchHistoryCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.contentId = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
  });
  WatchHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String contentId,
    required String title,
    this.posterPath = const Value.absent(),
    required String mediaType,
    this.watchedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
  })  : profileId = Value(profileId),
        contentId = Value(contentId),
        title = Value(title),
        mediaType = Value(mediaType);
  static Insertable<WatchHistoryData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? contentId,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<String>? mediaType,
    Expression<DateTime>? watchedAt,
    Expression<int>? tmdbId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (contentId != null) 'content_id': contentId,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (mediaType != null) 'media_type': mediaType,
      if (watchedAt != null) 'watched_at': watchedAt,
      if (tmdbId != null) 'tmdb_id': tmdbId,
    });
  }

  WatchHistoryCompanion copyWith(
      {Value<int>? id,
      Value<int>? profileId,
      Value<String>? contentId,
      Value<String>? title,
      Value<String?>? posterPath,
      Value<String>? mediaType,
      Value<DateTime>? watchedAt,
      Value<int?>? tmdbId}) {
    return WatchHistoryCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      mediaType: mediaType ?? this.mediaType,
      watchedAt: watchedAt ?? this.watchedAt,
      tmdbId: tmdbId ?? this.tmdbId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (watchedAt.present) {
      map['watched_at'] = Variable<DateTime>(watchedAt.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('mediaType: $mediaType, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }
}

class $WatchlistTable extends Watchlist
    with TableInfo<$WatchlistTable, WatchlistData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterPathMeta =
      const VerificationMeta('posterPath');
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
      'poster_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
      'tmdb_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, profileId, contentId, title, posterPath, mediaType, addedAt, tmdbId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist';
  @override
  VerificationContext validateIntegrity(Insertable<WatchlistData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
          _posterPathMeta,
          posterPath.isAcceptableOrUnknown(
              data['poster_path']!, _posterPathMeta));
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(_tmdbIdMeta,
          tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchlistData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}profile_id'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_path']),
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
      tmdbId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tmdb_id']),
    );
  }

  @override
  $WatchlistTable createAlias(String alias) {
    return $WatchlistTable(attachedDatabase, alias);
  }
}

class WatchlistData extends DataClass implements Insertable<WatchlistData> {
  final int id;
  final int profileId;
  final String contentId;
  final String title;
  final String? posterPath;
  final String mediaType;
  final DateTime addedAt;
  final int? tmdbId;
  const WatchlistData(
      {required this.id,
      required this.profileId,
      required this.contentId,
      required this.title,
      this.posterPath,
      required this.mediaType,
      required this.addedAt,
      this.tmdbId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['content_id'] = Variable<String>(contentId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    map['media_type'] = Variable<String>(mediaType);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    return map;
  }

  WatchlistCompanion toCompanion(bool nullToAbsent) {
    return WatchlistCompanion(
      id: Value(id),
      profileId: Value(profileId),
      contentId: Value(contentId),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      mediaType: Value(mediaType),
      addedAt: Value(addedAt),
      tmdbId:
          tmdbId == null && nullToAbsent ? const Value.absent() : Value(tmdbId),
    );
  }

  factory WatchlistData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      contentId: serializer.fromJson<String>(json['contentId']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'contentId': serializer.toJson<String>(contentId),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'mediaType': serializer.toJson<String>(mediaType),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'tmdbId': serializer.toJson<int?>(tmdbId),
    };
  }

  WatchlistData copyWith(
          {int? id,
          int? profileId,
          String? contentId,
          String? title,
          Value<String?> posterPath = const Value.absent(),
          String? mediaType,
          DateTime? addedAt,
          Value<int?> tmdbId = const Value.absent()}) =>
      WatchlistData(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        contentId: contentId ?? this.contentId,
        title: title ?? this.title,
        posterPath: posterPath.present ? posterPath.value : this.posterPath,
        mediaType: mediaType ?? this.mediaType,
        addedAt: addedAt ?? this.addedAt,
        tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
      );
  WatchlistData copyWithCompanion(WatchlistCompanion data) {
    return WatchlistData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      title: data.title.present ? data.title.value : this.title,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('mediaType: $mediaType, ')
          ..write('addedAt: $addedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, profileId, contentId, title, posterPath, mediaType, addedAt, tmdbId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.contentId == this.contentId &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.mediaType == this.mediaType &&
          other.addedAt == this.addedAt &&
          other.tmdbId == this.tmdbId);
}

class WatchlistCompanion extends UpdateCompanion<WatchlistData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> contentId;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<String> mediaType;
  final Value<DateTime> addedAt;
  final Value<int?> tmdbId;
  const WatchlistCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.contentId = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
  });
  WatchlistCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String contentId,
    required String title,
    this.posterPath = const Value.absent(),
    required String mediaType,
    this.addedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
  })  : profileId = Value(profileId),
        contentId = Value(contentId),
        title = Value(title),
        mediaType = Value(mediaType);
  static Insertable<WatchlistData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? contentId,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<String>? mediaType,
    Expression<DateTime>? addedAt,
    Expression<int>? tmdbId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (contentId != null) 'content_id': contentId,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (mediaType != null) 'media_type': mediaType,
      if (addedAt != null) 'added_at': addedAt,
      if (tmdbId != null) 'tmdb_id': tmdbId,
    });
  }

  WatchlistCompanion copyWith(
      {Value<int>? id,
      Value<int>? profileId,
      Value<String>? contentId,
      Value<String>? title,
      Value<String?>? posterPath,
      Value<String>? mediaType,
      Value<DateTime>? addedAt,
      Value<int?>? tmdbId}) {
    return WatchlistCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      mediaType: mediaType ?? this.mediaType,
      addedAt: addedAt ?? this.addedAt,
      tmdbId: tmdbId ?? this.tmdbId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('mediaType: $mediaType, ')
          ..write('addedAt: $addedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }
}

class $ContinueWatchingTable extends ContinueWatching
    with TableInfo<$ContinueWatchingTable, ContinueWatchingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContinueWatchingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterPathMeta =
      const VerificationMeta('posterPath');
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
      'poster_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionSecondsMeta =
      const VerificationMeta('positionSeconds');
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
      'position_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _episodeNumberMeta =
      const VerificationMeta('episodeNumber');
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
      'episode_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _seasonNumberMeta =
      const VerificationMeta('seasonNumber');
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
      'season_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
      'tmdb_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        profileId,
        contentId,
        title,
        posterPath,
        mediaType,
        positionSeconds,
        durationSeconds,
        episodeNumber,
        seasonNumber,
        updatedAt,
        tmdbId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'continue_watching';
  @override
  VerificationContext validateIntegrity(
      Insertable<ContinueWatchingData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
          _posterPathMeta,
          posterPath.isAcceptableOrUnknown(
              data['poster_path']!, _posterPathMeta));
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
          _positionSecondsMeta,
          positionSeconds.isAcceptableOrUnknown(
              data['position_seconds']!, _positionSecondsMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('episode_number')) {
      context.handle(
          _episodeNumberMeta,
          episodeNumber.isAcceptableOrUnknown(
              data['episode_number']!, _episodeNumberMeta));
    }
    if (data.containsKey('season_number')) {
      context.handle(
          _seasonNumberMeta,
          seasonNumber.isAcceptableOrUnknown(
              data['season_number']!, _seasonNumberMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(_tmdbIdMeta,
          tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContinueWatchingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContinueWatchingData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}profile_id'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_path']),
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      positionSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_seconds'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      episodeNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}episode_number']),
      seasonNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}season_number']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      tmdbId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tmdb_id']),
    );
  }

  @override
  $ContinueWatchingTable createAlias(String alias) {
    return $ContinueWatchingTable(attachedDatabase, alias);
  }
}

class ContinueWatchingData extends DataClass
    implements Insertable<ContinueWatchingData> {
  final int id;
  final int profileId;
  final String contentId;
  final String title;
  final String? posterPath;
  final String mediaType;
  final int positionSeconds;
  final int durationSeconds;
  final int? episodeNumber;
  final int? seasonNumber;
  final DateTime updatedAt;
  final int? tmdbId;
  const ContinueWatchingData(
      {required this.id,
      required this.profileId,
      required this.contentId,
      required this.title,
      this.posterPath,
      required this.mediaType,
      required this.positionSeconds,
      required this.durationSeconds,
      this.episodeNumber,
      this.seasonNumber,
      required this.updatedAt,
      this.tmdbId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['content_id'] = Variable<String>(contentId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    map['media_type'] = Variable<String>(mediaType);
    map['position_seconds'] = Variable<int>(positionSeconds);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    if (!nullToAbsent || episodeNumber != null) {
      map['episode_number'] = Variable<int>(episodeNumber);
    }
    if (!nullToAbsent || seasonNumber != null) {
      map['season_number'] = Variable<int>(seasonNumber);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    return map;
  }

  ContinueWatchingCompanion toCompanion(bool nullToAbsent) {
    return ContinueWatchingCompanion(
      id: Value(id),
      profileId: Value(profileId),
      contentId: Value(contentId),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      mediaType: Value(mediaType),
      positionSeconds: Value(positionSeconds),
      durationSeconds: Value(durationSeconds),
      episodeNumber: episodeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNumber),
      seasonNumber: seasonNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonNumber),
      updatedAt: Value(updatedAt),
      tmdbId:
          tmdbId == null && nullToAbsent ? const Value.absent() : Value(tmdbId),
    );
  }

  factory ContinueWatchingData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContinueWatchingData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      contentId: serializer.fromJson<String>(json['contentId']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      episodeNumber: serializer.fromJson<int?>(json['episodeNumber']),
      seasonNumber: serializer.fromJson<int?>(json['seasonNumber']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'contentId': serializer.toJson<String>(contentId),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'mediaType': serializer.toJson<String>(mediaType),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'episodeNumber': serializer.toJson<int?>(episodeNumber),
      'seasonNumber': serializer.toJson<int?>(seasonNumber),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'tmdbId': serializer.toJson<int?>(tmdbId),
    };
  }

  ContinueWatchingData copyWith(
          {int? id,
          int? profileId,
          String? contentId,
          String? title,
          Value<String?> posterPath = const Value.absent(),
          String? mediaType,
          int? positionSeconds,
          int? durationSeconds,
          Value<int?> episodeNumber = const Value.absent(),
          Value<int?> seasonNumber = const Value.absent(),
          DateTime? updatedAt,
          Value<int?> tmdbId = const Value.absent()}) =>
      ContinueWatchingData(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        contentId: contentId ?? this.contentId,
        title: title ?? this.title,
        posterPath: posterPath.present ? posterPath.value : this.posterPath,
        mediaType: mediaType ?? this.mediaType,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        episodeNumber:
            episodeNumber.present ? episodeNumber.value : this.episodeNumber,
        seasonNumber:
            seasonNumber.present ? seasonNumber.value : this.seasonNumber,
        updatedAt: updatedAt ?? this.updatedAt,
        tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
      );
  ContinueWatchingData copyWithCompanion(ContinueWatchingCompanion data) {
    return ContinueWatchingData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      title: data.title.present ? data.title.value : this.title,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContinueWatchingData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('mediaType: $mediaType, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      profileId,
      contentId,
      title,
      posterPath,
      mediaType,
      positionSeconds,
      durationSeconds,
      episodeNumber,
      seasonNumber,
      updatedAt,
      tmdbId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContinueWatchingData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.contentId == this.contentId &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.mediaType == this.mediaType &&
          other.positionSeconds == this.positionSeconds &&
          other.durationSeconds == this.durationSeconds &&
          other.episodeNumber == this.episodeNumber &&
          other.seasonNumber == this.seasonNumber &&
          other.updatedAt == this.updatedAt &&
          other.tmdbId == this.tmdbId);
}

class ContinueWatchingCompanion extends UpdateCompanion<ContinueWatchingData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> contentId;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<String> mediaType;
  final Value<int> positionSeconds;
  final Value<int> durationSeconds;
  final Value<int?> episodeNumber;
  final Value<int?> seasonNumber;
  final Value<DateTime> updatedAt;
  final Value<int?> tmdbId;
  const ContinueWatchingCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.contentId = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
  });
  ContinueWatchingCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String contentId,
    required String title,
    this.posterPath = const Value.absent(),
    required String mediaType,
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
  })  : profileId = Value(profileId),
        contentId = Value(contentId),
        title = Value(title),
        mediaType = Value(mediaType);
  static Insertable<ContinueWatchingData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? contentId,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<String>? mediaType,
    Expression<int>? positionSeconds,
    Expression<int>? durationSeconds,
    Expression<int>? episodeNumber,
    Expression<int>? seasonNumber,
    Expression<DateTime>? updatedAt,
    Expression<int>? tmdbId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (contentId != null) 'content_id': contentId,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (mediaType != null) 'media_type': mediaType,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (tmdbId != null) 'tmdb_id': tmdbId,
    });
  }

  ContinueWatchingCompanion copyWith(
      {Value<int>? id,
      Value<int>? profileId,
      Value<String>? contentId,
      Value<String>? title,
      Value<String?>? posterPath,
      Value<String>? mediaType,
      Value<int>? positionSeconds,
      Value<int>? durationSeconds,
      Value<int?>? episodeNumber,
      Value<int?>? seasonNumber,
      Value<DateTime>? updatedAt,
      Value<int?>? tmdbId}) {
    return ContinueWatchingCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      mediaType: mediaType ?? this.mediaType,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      updatedAt: updatedAt ?? this.updatedAt,
      tmdbId: tmdbId ?? this.tmdbId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContinueWatchingCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('mediaType: $mediaType, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }
}

class $CachedConfigTable extends CachedConfig
    with TableInfo<$CachedConfigTable, CachedConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _jsonDataMeta =
      const VerificationMeta('jsonData');
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
      'json_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, jsonData, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_config';
  @override
  VerificationContext validateIntegrity(Insertable<CachedConfigData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json_data')) {
      context.handle(_jsonDataMeta,
          jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta));
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedConfigData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      jsonData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json_data'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $CachedConfigTable createAlias(String alias) {
    return $CachedConfigTable(attachedDatabase, alias);
  }
}

class CachedConfigData extends DataClass
    implements Insertable<CachedConfigData> {
  final int id;
  final String jsonData;
  final DateTime cachedAt;
  const CachedConfigData(
      {required this.id, required this.jsonData, required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json_data'] = Variable<String>(jsonData);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedConfigCompanion toCompanion(bool nullToAbsent) {
    return CachedConfigCompanion(
      id: Value(id),
      jsonData: Value(jsonData),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedConfigData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedConfigData(
      id: serializer.fromJson<int>(json['id']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'jsonData': serializer.toJson<String>(jsonData),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedConfigData copyWith({int? id, String? jsonData, DateTime? cachedAt}) =>
      CachedConfigData(
        id: id ?? this.id,
        jsonData: jsonData ?? this.jsonData,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CachedConfigData copyWithCompanion(CachedConfigCompanion data) {
    return CachedConfigData(
      id: data.id.present ? data.id.value : this.id,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedConfigData(')
          ..write('id: $id, ')
          ..write('jsonData: $jsonData, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, jsonData, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedConfigData &&
          other.id == this.id &&
          other.jsonData == this.jsonData &&
          other.cachedAt == this.cachedAt);
}

class CachedConfigCompanion extends UpdateCompanion<CachedConfigData> {
  final Value<int> id;
  final Value<String> jsonData;
  final Value<DateTime> cachedAt;
  const CachedConfigCompanion({
    this.id = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  CachedConfigCompanion.insert({
    this.id = const Value.absent(),
    required String jsonData,
    this.cachedAt = const Value.absent(),
  }) : jsonData = Value(jsonData);
  static Insertable<CachedConfigData> custom({
    Expression<int>? id,
    Expression<String>? jsonData,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jsonData != null) 'json_data': jsonData,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  CachedConfigCompanion copyWith(
      {Value<int>? id, Value<String>? jsonData, Value<DateTime>? cachedAt}) {
    return CachedConfigCompanion(
      id: id ?? this.id,
      jsonData: jsonData ?? this.jsonData,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedConfigCompanion(')
          ..write('id: $id, ')
          ..write('jsonData: $jsonData, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadedContentTable extends DownloadedContent
    with TableInfo<$DownloadedContentTable, DownloadedContentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadedContentTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _contentIdMeta =
      const VerificationMeta('contentId');
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
      'content_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterPathMeta =
      const VerificationMeta('posterPath');
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
      'poster_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subtitlePathMeta =
      const VerificationMeta('subtitlePath');
  @override
  late final GeneratedColumn<String> subtitlePath = GeneratedColumn<String>(
      'subtitle_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _qualityMeta =
      const VerificationMeta('quality');
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
      'quality', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('1080p'));
  static const VerificationMeta _fileSizeBytesMeta =
      const VerificationMeta('fileSizeBytes');
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
      'file_size_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _downloadedAtMeta =
      const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
      'downloaded_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
      'tmdb_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        profileId,
        contentId,
        title,
        posterPath,
        mediaType,
        filePath,
        subtitlePath,
        quality,
        fileSizeBytes,
        downloadedAt,
        tmdbId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloaded_content';
  @override
  VerificationContext validateIntegrity(
      Insertable<DownloadedContentData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(_contentIdMeta,
          contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta));
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
          _posterPathMeta,
          posterPath.isAcceptableOrUnknown(
              data['poster_path']!, _posterPathMeta));
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('subtitle_path')) {
      context.handle(
          _subtitlePathMeta,
          subtitlePath.isAcceptableOrUnknown(
              data['subtitle_path']!, _subtitlePathMeta));
    }
    if (data.containsKey('quality')) {
      context.handle(_qualityMeta,
          quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta));
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
          _fileSizeBytesMeta,
          fileSizeBytes.isAcceptableOrUnknown(
              data['file_size_bytes']!, _fileSizeBytesMeta));
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
          _downloadedAtMeta,
          downloadedAt.isAcceptableOrUnknown(
              data['downloaded_at']!, _downloadedAtMeta));
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(_tmdbIdMeta,
          tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadedContentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadedContentData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}profile_id'])!,
      contentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_path']),
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      subtitlePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subtitle_path']),
      quality: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quality'])!,
      fileSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes'])!,
      downloadedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}downloaded_at'])!,
      tmdbId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tmdb_id']),
    );
  }

  @override
  $DownloadedContentTable createAlias(String alias) {
    return $DownloadedContentTable(attachedDatabase, alias);
  }
}

class DownloadedContentData extends DataClass
    implements Insertable<DownloadedContentData> {
  final int id;
  final int profileId;
  final String contentId;
  final String title;
  final String? posterPath;
  final String mediaType;
  final String filePath;
  final String? subtitlePath;
  final String quality;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final int? tmdbId;
  const DownloadedContentData(
      {required this.id,
      required this.profileId,
      required this.contentId,
      required this.title,
      this.posterPath,
      required this.mediaType,
      required this.filePath,
      this.subtitlePath,
      required this.quality,
      required this.fileSizeBytes,
      required this.downloadedAt,
      this.tmdbId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['content_id'] = Variable<String>(contentId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    map['media_type'] = Variable<String>(mediaType);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || subtitlePath != null) {
      map['subtitle_path'] = Variable<String>(subtitlePath);
    }
    map['quality'] = Variable<String>(quality);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    return map;
  }

  DownloadedContentCompanion toCompanion(bool nullToAbsent) {
    return DownloadedContentCompanion(
      id: Value(id),
      profileId: Value(profileId),
      contentId: Value(contentId),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      mediaType: Value(mediaType),
      filePath: Value(filePath),
      subtitlePath: subtitlePath == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitlePath),
      quality: Value(quality),
      fileSizeBytes: Value(fileSizeBytes),
      downloadedAt: Value(downloadedAt),
      tmdbId:
          tmdbId == null && nullToAbsent ? const Value.absent() : Value(tmdbId),
    );
  }

  factory DownloadedContentData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadedContentData(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      contentId: serializer.fromJson<String>(json['contentId']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      filePath: serializer.fromJson<String>(json['filePath']),
      subtitlePath: serializer.fromJson<String?>(json['subtitlePath']),
      quality: serializer.fromJson<String>(json['quality']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'contentId': serializer.toJson<String>(contentId),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'mediaType': serializer.toJson<String>(mediaType),
      'filePath': serializer.toJson<String>(filePath),
      'subtitlePath': serializer.toJson<String?>(subtitlePath),
      'quality': serializer.toJson<String>(quality),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
      'tmdbId': serializer.toJson<int?>(tmdbId),
    };
  }

  DownloadedContentData copyWith(
          {int? id,
          int? profileId,
          String? contentId,
          String? title,
          Value<String?> posterPath = const Value.absent(),
          String? mediaType,
          String? filePath,
          Value<String?> subtitlePath = const Value.absent(),
          String? quality,
          int? fileSizeBytes,
          DateTime? downloadedAt,
          Value<int?> tmdbId = const Value.absent()}) =>
      DownloadedContentData(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        contentId: contentId ?? this.contentId,
        title: title ?? this.title,
        posterPath: posterPath.present ? posterPath.value : this.posterPath,
        mediaType: mediaType ?? this.mediaType,
        filePath: filePath ?? this.filePath,
        subtitlePath:
            subtitlePath.present ? subtitlePath.value : this.subtitlePath,
        quality: quality ?? this.quality,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
      );
  DownloadedContentData copyWithCompanion(DownloadedContentCompanion data) {
    return DownloadedContentData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      title: data.title.present ? data.title.value : this.title,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      subtitlePath: data.subtitlePath.present
          ? data.subtitlePath.value
          : this.subtitlePath,
      quality: data.quality.present ? data.quality.value : this.quality,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedContentData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('mediaType: $mediaType, ')
          ..write('filePath: $filePath, ')
          ..write('subtitlePath: $subtitlePath, ')
          ..write('quality: $quality, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      profileId,
      contentId,
      title,
      posterPath,
      mediaType,
      filePath,
      subtitlePath,
      quality,
      fileSizeBytes,
      downloadedAt,
      tmdbId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadedContentData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.contentId == this.contentId &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.mediaType == this.mediaType &&
          other.filePath == this.filePath &&
          other.subtitlePath == this.subtitlePath &&
          other.quality == this.quality &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.downloadedAt == this.downloadedAt &&
          other.tmdbId == this.tmdbId);
}

class DownloadedContentCompanion
    extends UpdateCompanion<DownloadedContentData> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> contentId;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<String> mediaType;
  final Value<String> filePath;
  final Value<String?> subtitlePath;
  final Value<String> quality;
  final Value<int> fileSizeBytes;
  final Value<DateTime> downloadedAt;
  final Value<int?> tmdbId;
  const DownloadedContentCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.contentId = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.filePath = const Value.absent(),
    this.subtitlePath = const Value.absent(),
    this.quality = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
  });
  DownloadedContentCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String contentId,
    required String title,
    this.posterPath = const Value.absent(),
    required String mediaType,
    required String filePath,
    this.subtitlePath = const Value.absent(),
    this.quality = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
  })  : profileId = Value(profileId),
        contentId = Value(contentId),
        title = Value(title),
        mediaType = Value(mediaType),
        filePath = Value(filePath);
  static Insertable<DownloadedContentData> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? contentId,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<String>? mediaType,
    Expression<String>? filePath,
    Expression<String>? subtitlePath,
    Expression<String>? quality,
    Expression<int>? fileSizeBytes,
    Expression<DateTime>? downloadedAt,
    Expression<int>? tmdbId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (contentId != null) 'content_id': contentId,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (mediaType != null) 'media_type': mediaType,
      if (filePath != null) 'file_path': filePath,
      if (subtitlePath != null) 'subtitle_path': subtitlePath,
      if (quality != null) 'quality': quality,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (tmdbId != null) 'tmdb_id': tmdbId,
    });
  }

  DownloadedContentCompanion copyWith(
      {Value<int>? id,
      Value<int>? profileId,
      Value<String>? contentId,
      Value<String>? title,
      Value<String?>? posterPath,
      Value<String>? mediaType,
      Value<String>? filePath,
      Value<String?>? subtitlePath,
      Value<String>? quality,
      Value<int>? fileSizeBytes,
      Value<DateTime>? downloadedAt,
      Value<int?>? tmdbId}) {
    return DownloadedContentCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      mediaType: mediaType ?? this.mediaType,
      filePath: filePath ?? this.filePath,
      subtitlePath: subtitlePath ?? this.subtitlePath,
      quality: quality ?? this.quality,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      tmdbId: tmdbId ?? this.tmdbId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (subtitlePath.present) {
      map['subtitle_path'] = Variable<String>(subtitlePath.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedContentCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('contentId: $contentId, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('mediaType: $mediaType, ')
          ..write('filePath: $filePath, ')
          ..write('subtitlePath: $subtitlePath, ')
          ..write('quality: $quality, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }
}

class $SubtitlePreferencesTable extends SubtitlePreferences
    with TableInfo<$SubtitlePreferencesTable, SubtitlePreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtitlePreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES profiles (id)'));
  static const VerificationMeta _preferredLanguageMeta =
      const VerificationMeta('preferredLanguage');
  @override
  late final GeneratedColumn<String> preferredLanguage =
      GeneratedColumn<String>('preferred_language', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('en'));
  static const VerificationMeta _fontSizeMeta =
      const VerificationMeta('fontSize');
  @override
  late final GeneratedColumn<int> fontSize = GeneratedColumn<int>(
      'font_size', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(16));
  static const VerificationMeta _fontColorMeta =
      const VerificationMeta('fontColor');
  @override
  late final GeneratedColumn<String> fontColor = GeneratedColumn<String>(
      'font_color', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#FFFFFF'));
  static const VerificationMeta _backgroundOpacityMeta =
      const VerificationMeta('backgroundOpacity');
  @override
  late final GeneratedColumn<double> backgroundOpacity =
      GeneratedColumn<double>('background_opacity', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.5));
  static const VerificationMeta _edgeStyleMeta =
      const VerificationMeta('edgeStyle');
  @override
  late final GeneratedColumn<String> edgeStyle = GeneratedColumn<String>(
      'edge_style', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('none'));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(100));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        profileId,
        preferredLanguage,
        fontSize,
        fontColor,
        backgroundOpacity,
        edgeStyle,
        position
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtitle_preferences';
  @override
  VerificationContext validateIntegrity(Insertable<SubtitlePreference> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('preferred_language')) {
      context.handle(
          _preferredLanguageMeta,
          preferredLanguage.isAcceptableOrUnknown(
              data['preferred_language']!, _preferredLanguageMeta));
    }
    if (data.containsKey('font_size')) {
      context.handle(_fontSizeMeta,
          fontSize.isAcceptableOrUnknown(data['font_size']!, _fontSizeMeta));
    }
    if (data.containsKey('font_color')) {
      context.handle(_fontColorMeta,
          fontColor.isAcceptableOrUnknown(data['font_color']!, _fontColorMeta));
    }
    if (data.containsKey('background_opacity')) {
      context.handle(
          _backgroundOpacityMeta,
          backgroundOpacity.isAcceptableOrUnknown(
              data['background_opacity']!, _backgroundOpacityMeta));
    }
    if (data.containsKey('edge_style')) {
      context.handle(_edgeStyleMeta,
          edgeStyle.isAcceptableOrUnknown(data['edge_style']!, _edgeStyleMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubtitlePreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubtitlePreference(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}profile_id'])!,
      preferredLanguage: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preferred_language'])!,
      fontSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}font_size'])!,
      fontColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}font_color'])!,
      backgroundOpacity: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}background_opacity'])!,
      edgeStyle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}edge_style'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $SubtitlePreferencesTable createAlias(String alias) {
    return $SubtitlePreferencesTable(attachedDatabase, alias);
  }
}

class SubtitlePreference extends DataClass
    implements Insertable<SubtitlePreference> {
  final int id;
  final int profileId;
  final String preferredLanguage;
  final int fontSize;
  final String fontColor;
  final double backgroundOpacity;
  final String edgeStyle;
  final int position;
  const SubtitlePreference(
      {required this.id,
      required this.profileId,
      required this.preferredLanguage,
      required this.fontSize,
      required this.fontColor,
      required this.backgroundOpacity,
      required this.edgeStyle,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['preferred_language'] = Variable<String>(preferredLanguage);
    map['font_size'] = Variable<int>(fontSize);
    map['font_color'] = Variable<String>(fontColor);
    map['background_opacity'] = Variable<double>(backgroundOpacity);
    map['edge_style'] = Variable<String>(edgeStyle);
    map['position'] = Variable<int>(position);
    return map;
  }

  SubtitlePreferencesCompanion toCompanion(bool nullToAbsent) {
    return SubtitlePreferencesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      preferredLanguage: Value(preferredLanguage),
      fontSize: Value(fontSize),
      fontColor: Value(fontColor),
      backgroundOpacity: Value(backgroundOpacity),
      edgeStyle: Value(edgeStyle),
      position: Value(position),
    );
  }

  factory SubtitlePreference.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubtitlePreference(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      preferredLanguage: serializer.fromJson<String>(json['preferredLanguage']),
      fontSize: serializer.fromJson<int>(json['fontSize']),
      fontColor: serializer.fromJson<String>(json['fontColor']),
      backgroundOpacity: serializer.fromJson<double>(json['backgroundOpacity']),
      edgeStyle: serializer.fromJson<String>(json['edgeStyle']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'preferredLanguage': serializer.toJson<String>(preferredLanguage),
      'fontSize': serializer.toJson<int>(fontSize),
      'fontColor': serializer.toJson<String>(fontColor),
      'backgroundOpacity': serializer.toJson<double>(backgroundOpacity),
      'edgeStyle': serializer.toJson<String>(edgeStyle),
      'position': serializer.toJson<int>(position),
    };
  }

  SubtitlePreference copyWith(
          {int? id,
          int? profileId,
          String? preferredLanguage,
          int? fontSize,
          String? fontColor,
          double? backgroundOpacity,
          String? edgeStyle,
          int? position}) =>
      SubtitlePreference(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        fontSize: fontSize ?? this.fontSize,
        fontColor: fontColor ?? this.fontColor,
        backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
        edgeStyle: edgeStyle ?? this.edgeStyle,
        position: position ?? this.position,
      );
  SubtitlePreference copyWithCompanion(SubtitlePreferencesCompanion data) {
    return SubtitlePreference(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      preferredLanguage: data.preferredLanguage.present
          ? data.preferredLanguage.value
          : this.preferredLanguage,
      fontSize: data.fontSize.present ? data.fontSize.value : this.fontSize,
      fontColor: data.fontColor.present ? data.fontColor.value : this.fontColor,
      backgroundOpacity: data.backgroundOpacity.present
          ? data.backgroundOpacity.value
          : this.backgroundOpacity,
      edgeStyle: data.edgeStyle.present ? data.edgeStyle.value : this.edgeStyle,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubtitlePreference(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('preferredLanguage: $preferredLanguage, ')
          ..write('fontSize: $fontSize, ')
          ..write('fontColor: $fontColor, ')
          ..write('backgroundOpacity: $backgroundOpacity, ')
          ..write('edgeStyle: $edgeStyle, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, preferredLanguage, fontSize,
      fontColor, backgroundOpacity, edgeStyle, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtitlePreference &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.preferredLanguage == this.preferredLanguage &&
          other.fontSize == this.fontSize &&
          other.fontColor == this.fontColor &&
          other.backgroundOpacity == this.backgroundOpacity &&
          other.edgeStyle == this.edgeStyle &&
          other.position == this.position);
}

class SubtitlePreferencesCompanion extends UpdateCompanion<SubtitlePreference> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> preferredLanguage;
  final Value<int> fontSize;
  final Value<String> fontColor;
  final Value<double> backgroundOpacity;
  final Value<String> edgeStyle;
  final Value<int> position;
  const SubtitlePreferencesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.preferredLanguage = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.fontColor = const Value.absent(),
    this.backgroundOpacity = const Value.absent(),
    this.edgeStyle = const Value.absent(),
    this.position = const Value.absent(),
  });
  SubtitlePreferencesCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    this.preferredLanguage = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.fontColor = const Value.absent(),
    this.backgroundOpacity = const Value.absent(),
    this.edgeStyle = const Value.absent(),
    this.position = const Value.absent(),
  }) : profileId = Value(profileId);
  static Insertable<SubtitlePreference> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? preferredLanguage,
    Expression<int>? fontSize,
    Expression<String>? fontColor,
    Expression<double>? backgroundOpacity,
    Expression<String>? edgeStyle,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (preferredLanguage != null) 'preferred_language': preferredLanguage,
      if (fontSize != null) 'font_size': fontSize,
      if (fontColor != null) 'font_color': fontColor,
      if (backgroundOpacity != null) 'background_opacity': backgroundOpacity,
      if (edgeStyle != null) 'edge_style': edgeStyle,
      if (position != null) 'position': position,
    });
  }

  SubtitlePreferencesCompanion copyWith(
      {Value<int>? id,
      Value<int>? profileId,
      Value<String>? preferredLanguage,
      Value<int>? fontSize,
      Value<String>? fontColor,
      Value<double>? backgroundOpacity,
      Value<String>? edgeStyle,
      Value<int>? position}) {
    return SubtitlePreferencesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      edgeStyle: edgeStyle ?? this.edgeStyle,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (preferredLanguage.present) {
      map['preferred_language'] = Variable<String>(preferredLanguage.value);
    }
    if (fontSize.present) {
      map['font_size'] = Variable<int>(fontSize.value);
    }
    if (fontColor.present) {
      map['font_color'] = Variable<String>(fontColor.value);
    }
    if (backgroundOpacity.present) {
      map['background_opacity'] = Variable<double>(backgroundOpacity.value);
    }
    if (edgeStyle.present) {
      map['edge_style'] = Variable<String>(edgeStyle.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtitlePreferencesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('preferredLanguage: $preferredLanguage, ')
          ..write('fontSize: $fontSize, ')
          ..write('fontColor: $fontColor, ')
          ..write('backgroundOpacity: $backgroundOpacity, ')
          ..write('edgeStyle: $edgeStyle, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $WatchHistoryTable watchHistory = $WatchHistoryTable(this);
  late final $WatchlistTable watchlist = $WatchlistTable(this);
  late final $ContinueWatchingTable continueWatching =
      $ContinueWatchingTable(this);
  late final $CachedConfigTable cachedConfig = $CachedConfigTable(this);
  late final $DownloadedContentTable downloadedContent =
      $DownloadedContentTable(this);
  late final $SubtitlePreferencesTable subtitlePreferences =
      $SubtitlePreferencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        profiles,
        watchHistory,
        watchlist,
        continueWatching,
        cachedConfig,
        downloadedContent,
        subtitlePreferences
      ];
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  required String name,
  Value<int> avatarMoonPhase,
  Value<String?> pinHash,
  Value<DateTime> createdAt,
  Value<bool> isActive,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> avatarMoonPhase,
  Value<String?> pinHash,
  Value<DateTime> createdAt,
  Value<bool> isActive,
});

final class $$ProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $ProfilesTable, Profile> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WatchHistoryTable, List<WatchHistoryData>>
      _watchHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.watchHistory,
          aliasName:
              $_aliasNameGenerator(db.profiles.id, db.watchHistory.profileId));

  $$WatchHistoryTableProcessedTableManager get watchHistoryRefs {
    final manager = $$WatchHistoryTableTableManager($_db, $_db.watchHistory)
        .filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_watchHistoryRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WatchlistTable, List<WatchlistData>>
      _watchlistRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.watchlist,
              aliasName:
                  $_aliasNameGenerator(db.profiles.id, db.watchlist.profileId));

  $$WatchlistTableProcessedTableManager get watchlistRefs {
    final manager = $$WatchlistTableTableManager($_db, $_db.watchlist)
        .filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_watchlistRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ContinueWatchingTable, List<ContinueWatchingData>>
      _continueWatchingRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.continueWatching,
              aliasName: $_aliasNameGenerator(
                  db.profiles.id, db.continueWatching.profileId));

  $$ContinueWatchingTableProcessedTableManager get continueWatchingRefs {
    final manager =
        $$ContinueWatchingTableTableManager($_db, $_db.continueWatching)
            .filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_continueWatchingRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DownloadedContentTable,
      List<DownloadedContentData>> _downloadedContentRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.downloadedContent,
          aliasName: $_aliasNameGenerator(
              db.profiles.id, db.downloadedContent.profileId));

  $$DownloadedContentTableProcessedTableManager get downloadedContentRefs {
    final manager =
        $$DownloadedContentTableTableManager($_db, $_db.downloadedContent)
            .filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_downloadedContentRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SubtitlePreferencesTable,
      List<SubtitlePreference>> _subtitlePreferencesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.subtitlePreferences,
          aliasName: $_aliasNameGenerator(
              db.profiles.id, db.subtitlePreferences.profileId));

  $$SubtitlePreferencesTableProcessedTableManager get subtitlePreferencesRefs {
    final manager =
        $$SubtitlePreferencesTableTableManager($_db, $_db.subtitlePreferences)
            .filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_subtitlePreferencesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get avatarMoonPhase => $composableBuilder(
      column: $table.avatarMoonPhase,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pinHash => $composableBuilder(
      column: $table.pinHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  Expression<bool> watchHistoryRefs(
      Expression<bool> Function($$WatchHistoryTableFilterComposer f) f) {
    final $$WatchHistoryTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.watchHistory,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WatchHistoryTableFilterComposer(
              $db: $db,
              $table: $db.watchHistory,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> watchlistRefs(
      Expression<bool> Function($$WatchlistTableFilterComposer f) f) {
    final $$WatchlistTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.watchlist,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WatchlistTableFilterComposer(
              $db: $db,
              $table: $db.watchlist,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> continueWatchingRefs(
      Expression<bool> Function($$ContinueWatchingTableFilterComposer f) f) {
    final $$ContinueWatchingTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.continueWatching,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ContinueWatchingTableFilterComposer(
              $db: $db,
              $table: $db.continueWatching,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> downloadedContentRefs(
      Expression<bool> Function($$DownloadedContentTableFilterComposer f) f) {
    final $$DownloadedContentTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.downloadedContent,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DownloadedContentTableFilterComposer(
              $db: $db,
              $table: $db.downloadedContent,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> subtitlePreferencesRefs(
      Expression<bool> Function($$SubtitlePreferencesTableFilterComposer f) f) {
    final $$SubtitlePreferencesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.subtitlePreferences,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SubtitlePreferencesTableFilterComposer(
              $db: $db,
              $table: $db.subtitlePreferences,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get avatarMoonPhase => $composableBuilder(
      column: $table.avatarMoonPhase,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pinHash => $composableBuilder(
      column: $table.pinHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get avatarMoonPhase => $composableBuilder(
      column: $table.avatarMoonPhase, builder: (column) => column);

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> watchHistoryRefs<T extends Object>(
      Expression<T> Function($$WatchHistoryTableAnnotationComposer a) f) {
    final $$WatchHistoryTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.watchHistory,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WatchHistoryTableAnnotationComposer(
              $db: $db,
              $table: $db.watchHistory,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> watchlistRefs<T extends Object>(
      Expression<T> Function($$WatchlistTableAnnotationComposer a) f) {
    final $$WatchlistTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.watchlist,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WatchlistTableAnnotationComposer(
              $db: $db,
              $table: $db.watchlist,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> continueWatchingRefs<T extends Object>(
      Expression<T> Function($$ContinueWatchingTableAnnotationComposer a) f) {
    final $$ContinueWatchingTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.continueWatching,
        getReferencedColumn: (t) => t.profileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ContinueWatchingTableAnnotationComposer(
              $db: $db,
              $table: $db.continueWatching,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> downloadedContentRefs<T extends Object>(
      Expression<T> Function($$DownloadedContentTableAnnotationComposer a) f) {
    final $$DownloadedContentTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.downloadedContent,
            getReferencedColumn: (t) => t.profileId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$DownloadedContentTableAnnotationComposer(
                  $db: $db,
                  $table: $db.downloadedContent,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> subtitlePreferencesRefs<T extends Object>(
      Expression<T> Function($$SubtitlePreferencesTableAnnotationComposer a)
          f) {
    final $$SubtitlePreferencesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.subtitlePreferences,
            getReferencedColumn: (t) => t.profileId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$SubtitlePreferencesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.subtitlePreferences,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$ProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProfilesTable,
    Profile,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (Profile, $$ProfilesTableReferences),
    Profile,
    PrefetchHooks Function(
        {bool watchHistoryRefs,
        bool watchlistRefs,
        bool continueWatchingRefs,
        bool downloadedContentRefs,
        bool subtitlePreferencesRefs})> {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> avatarMoonPhase = const Value.absent(),
            Value<String?> pinHash = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              ProfilesCompanion(
            id: id,
            name: name,
            avatarMoonPhase: avatarMoonPhase,
            pinHash: pinHash,
            createdAt: createdAt,
            isActive: isActive,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<int> avatarMoonPhase = const Value.absent(),
            Value<String?> pinHash = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              ProfilesCompanion.insert(
            id: id,
            name: name,
            avatarMoonPhase: avatarMoonPhase,
            pinHash: pinHash,
            createdAt: createdAt,
            isActive: isActive,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ProfilesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {watchHistoryRefs = false,
              watchlistRefs = false,
              continueWatchingRefs = false,
              downloadedContentRefs = false,
              subtitlePreferencesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (watchHistoryRefs) db.watchHistory,
                if (watchlistRefs) db.watchlist,
                if (continueWatchingRefs) db.continueWatching,
                if (downloadedContentRefs) db.downloadedContent,
                if (subtitlePreferencesRefs) db.subtitlePreferences
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (watchHistoryRefs)
                    await $_getPrefetchedData<Profile, $ProfilesTable,
                            WatchHistoryData>(
                        currentTable: table,
                        referencedTable: $$ProfilesTableReferences
                            ._watchHistoryRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .watchHistoryRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (watchlistRefs)
                    await $_getPrefetchedData<Profile, $ProfilesTable,
                            WatchlistData>(
                        currentTable: table,
                        referencedTable:
                            $$ProfilesTableReferences._watchlistRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .watchlistRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (continueWatchingRefs)
                    await $_getPrefetchedData<Profile, $ProfilesTable,
                            ContinueWatchingData>(
                        currentTable: table,
                        referencedTable: $$ProfilesTableReferences
                            ._continueWatchingRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .continueWatchingRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (downloadedContentRefs)
                    await $_getPrefetchedData<Profile, $ProfilesTable,
                            DownloadedContentData>(
                        currentTable: table,
                        referencedTable: $$ProfilesTableReferences
                            ._downloadedContentRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .downloadedContentRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items),
                  if (subtitlePreferencesRefs)
                    await $_getPrefetchedData<Profile, $ProfilesTable,
                            SubtitlePreference>(
                        currentTable: table,
                        referencedTable: $$ProfilesTableReferences
                            ._subtitlePreferencesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProfilesTableReferences(db, table, p0)
                                .subtitlePreferencesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.profileId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProfilesTable,
    Profile,
    $$ProfilesTableFilterComposer,
    $$ProfilesTableOrderingComposer,
    $$ProfilesTableAnnotationComposer,
    $$ProfilesTableCreateCompanionBuilder,
    $$ProfilesTableUpdateCompanionBuilder,
    (Profile, $$ProfilesTableReferences),
    Profile,
    PrefetchHooks Function(
        {bool watchHistoryRefs,
        bool watchlistRefs,
        bool continueWatchingRefs,
        bool downloadedContentRefs,
        bool subtitlePreferencesRefs})>;
typedef $$WatchHistoryTableCreateCompanionBuilder = WatchHistoryCompanion
    Function({
  Value<int> id,
  required int profileId,
  required String contentId,
  required String title,
  Value<String?> posterPath,
  required String mediaType,
  Value<DateTime> watchedAt,
  Value<int?> tmdbId,
});
typedef $$WatchHistoryTableUpdateCompanionBuilder = WatchHistoryCompanion
    Function({
  Value<int> id,
  Value<int> profileId,
  Value<String> contentId,
  Value<String> title,
  Value<String?> posterPath,
  Value<String> mediaType,
  Value<DateTime> watchedAt,
  Value<int?> tmdbId,
});

final class $$WatchHistoryTableReferences extends BaseReferences<_$AppDatabase,
    $WatchHistoryTable, WatchHistoryData> {
  $$WatchHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
          $_aliasNameGenerator(db.watchHistory.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WatchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get watchedAt => $composableBuilder(
      column: $table.watchedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WatchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get watchedAt => $composableBuilder(
      column: $table.watchedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WatchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<DateTime> get watchedAt =>
      $composableBuilder(column: $table.watchedAt, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WatchHistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WatchHistoryTable,
    WatchHistoryData,
    $$WatchHistoryTableFilterComposer,
    $$WatchHistoryTableOrderingComposer,
    $$WatchHistoryTableAnnotationComposer,
    $$WatchHistoryTableCreateCompanionBuilder,
    $$WatchHistoryTableUpdateCompanionBuilder,
    (WatchHistoryData, $$WatchHistoryTableReferences),
    WatchHistoryData,
    PrefetchHooks Function({bool profileId})> {
  $$WatchHistoryTableTableManager(_$AppDatabase db, $WatchHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> profileId = const Value.absent(),
            Value<String> contentId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterPath = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<DateTime> watchedAt = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
          }) =>
              WatchHistoryCompanion(
            id: id,
            profileId: profileId,
            contentId: contentId,
            title: title,
            posterPath: posterPath,
            mediaType: mediaType,
            watchedAt: watchedAt,
            tmdbId: tmdbId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int profileId,
            required String contentId,
            required String title,
            Value<String?> posterPath = const Value.absent(),
            required String mediaType,
            Value<DateTime> watchedAt = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
          }) =>
              WatchHistoryCompanion.insert(
            id: id,
            profileId: profileId,
            contentId: contentId,
            title: title,
            posterPath: posterPath,
            mediaType: mediaType,
            watchedAt: watchedAt,
            tmdbId: tmdbId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WatchHistoryTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$WatchHistoryTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$WatchHistoryTableReferences._profileIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WatchHistoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WatchHistoryTable,
    WatchHistoryData,
    $$WatchHistoryTableFilterComposer,
    $$WatchHistoryTableOrderingComposer,
    $$WatchHistoryTableAnnotationComposer,
    $$WatchHistoryTableCreateCompanionBuilder,
    $$WatchHistoryTableUpdateCompanionBuilder,
    (WatchHistoryData, $$WatchHistoryTableReferences),
    WatchHistoryData,
    PrefetchHooks Function({bool profileId})>;
typedef $$WatchlistTableCreateCompanionBuilder = WatchlistCompanion Function({
  Value<int> id,
  required int profileId,
  required String contentId,
  required String title,
  Value<String?> posterPath,
  required String mediaType,
  Value<DateTime> addedAt,
  Value<int?> tmdbId,
});
typedef $$WatchlistTableUpdateCompanionBuilder = WatchlistCompanion Function({
  Value<int> id,
  Value<int> profileId,
  Value<String> contentId,
  Value<String> title,
  Value<String?> posterPath,
  Value<String> mediaType,
  Value<DateTime> addedAt,
  Value<int?> tmdbId,
});

final class $$WatchlistTableReferences
    extends BaseReferences<_$AppDatabase, $WatchlistTable, WatchlistData> {
  $$WatchlistTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
          $_aliasNameGenerator(db.watchlist.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WatchlistTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistTable> {
  $$WatchlistTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WatchlistTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistTable> {
  $$WatchlistTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WatchlistTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistTable> {
  $$WatchlistTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WatchlistTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WatchlistTable,
    WatchlistData,
    $$WatchlistTableFilterComposer,
    $$WatchlistTableOrderingComposer,
    $$WatchlistTableAnnotationComposer,
    $$WatchlistTableCreateCompanionBuilder,
    $$WatchlistTableUpdateCompanionBuilder,
    (WatchlistData, $$WatchlistTableReferences),
    WatchlistData,
    PrefetchHooks Function({bool profileId})> {
  $$WatchlistTableTableManager(_$AppDatabase db, $WatchlistTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> profileId = const Value.absent(),
            Value<String> contentId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterPath = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
          }) =>
              WatchlistCompanion(
            id: id,
            profileId: profileId,
            contentId: contentId,
            title: title,
            posterPath: posterPath,
            mediaType: mediaType,
            addedAt: addedAt,
            tmdbId: tmdbId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int profileId,
            required String contentId,
            required String title,
            Value<String?> posterPath = const Value.absent(),
            required String mediaType,
            Value<DateTime> addedAt = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
          }) =>
              WatchlistCompanion.insert(
            id: id,
            profileId: profileId,
            contentId: contentId,
            title: title,
            posterPath: posterPath,
            mediaType: mediaType,
            addedAt: addedAt,
            tmdbId: tmdbId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WatchlistTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$WatchlistTableReferences._profileIdTable(db),
                    referencedColumn:
                        $$WatchlistTableReferences._profileIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WatchlistTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WatchlistTable,
    WatchlistData,
    $$WatchlistTableFilterComposer,
    $$WatchlistTableOrderingComposer,
    $$WatchlistTableAnnotationComposer,
    $$WatchlistTableCreateCompanionBuilder,
    $$WatchlistTableUpdateCompanionBuilder,
    (WatchlistData, $$WatchlistTableReferences),
    WatchlistData,
    PrefetchHooks Function({bool profileId})>;
typedef $$ContinueWatchingTableCreateCompanionBuilder
    = ContinueWatchingCompanion Function({
  Value<int> id,
  required int profileId,
  required String contentId,
  required String title,
  Value<String?> posterPath,
  required String mediaType,
  Value<int> positionSeconds,
  Value<int> durationSeconds,
  Value<int?> episodeNumber,
  Value<int?> seasonNumber,
  Value<DateTime> updatedAt,
  Value<int?> tmdbId,
});
typedef $$ContinueWatchingTableUpdateCompanionBuilder
    = ContinueWatchingCompanion Function({
  Value<int> id,
  Value<int> profileId,
  Value<String> contentId,
  Value<String> title,
  Value<String?> posterPath,
  Value<String> mediaType,
  Value<int> positionSeconds,
  Value<int> durationSeconds,
  Value<int?> episodeNumber,
  Value<int?> seasonNumber,
  Value<DateTime> updatedAt,
  Value<int?> tmdbId,
});

final class $$ContinueWatchingTableReferences extends BaseReferences<
    _$AppDatabase, $ContinueWatchingTable, ContinueWatchingData> {
  $$ContinueWatchingTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
          $_aliasNameGenerator(db.continueWatching.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ContinueWatchingTableFilterComposer
    extends Composer<_$AppDatabase, $ContinueWatchingTable> {
  $$ContinueWatchingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ContinueWatchingTableOrderingComposer
    extends Composer<_$AppDatabase, $ContinueWatchingTable> {
  $$ContinueWatchingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ContinueWatchingTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContinueWatchingTable> {
  $$ContinueWatchingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
      column: $table.positionSeconds, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
      column: $table.episodeNumber, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ContinueWatchingTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContinueWatchingTable,
    ContinueWatchingData,
    $$ContinueWatchingTableFilterComposer,
    $$ContinueWatchingTableOrderingComposer,
    $$ContinueWatchingTableAnnotationComposer,
    $$ContinueWatchingTableCreateCompanionBuilder,
    $$ContinueWatchingTableUpdateCompanionBuilder,
    (ContinueWatchingData, $$ContinueWatchingTableReferences),
    ContinueWatchingData,
    PrefetchHooks Function({bool profileId})> {
  $$ContinueWatchingTableTableManager(
      _$AppDatabase db, $ContinueWatchingTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContinueWatchingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContinueWatchingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContinueWatchingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> profileId = const Value.absent(),
            Value<String> contentId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterPath = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<int> positionSeconds = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<int?> episodeNumber = const Value.absent(),
            Value<int?> seasonNumber = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
          }) =>
              ContinueWatchingCompanion(
            id: id,
            profileId: profileId,
            contentId: contentId,
            title: title,
            posterPath: posterPath,
            mediaType: mediaType,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            episodeNumber: episodeNumber,
            seasonNumber: seasonNumber,
            updatedAt: updatedAt,
            tmdbId: tmdbId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int profileId,
            required String contentId,
            required String title,
            Value<String?> posterPath = const Value.absent(),
            required String mediaType,
            Value<int> positionSeconds = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<int?> episodeNumber = const Value.absent(),
            Value<int?> seasonNumber = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
          }) =>
              ContinueWatchingCompanion.insert(
            id: id,
            profileId: profileId,
            contentId: contentId,
            title: title,
            posterPath: posterPath,
            mediaType: mediaType,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            episodeNumber: episodeNumber,
            seasonNumber: seasonNumber,
            updatedAt: updatedAt,
            tmdbId: tmdbId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ContinueWatchingTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$ContinueWatchingTableReferences._profileIdTable(db),
                    referencedColumn: $$ContinueWatchingTableReferences
                        ._profileIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ContinueWatchingTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContinueWatchingTable,
    ContinueWatchingData,
    $$ContinueWatchingTableFilterComposer,
    $$ContinueWatchingTableOrderingComposer,
    $$ContinueWatchingTableAnnotationComposer,
    $$ContinueWatchingTableCreateCompanionBuilder,
    $$ContinueWatchingTableUpdateCompanionBuilder,
    (ContinueWatchingData, $$ContinueWatchingTableReferences),
    ContinueWatchingData,
    PrefetchHooks Function({bool profileId})>;
typedef $$CachedConfigTableCreateCompanionBuilder = CachedConfigCompanion
    Function({
  Value<int> id,
  required String jsonData,
  Value<DateTime> cachedAt,
});
typedef $$CachedConfigTableUpdateCompanionBuilder = CachedConfigCompanion
    Function({
  Value<int> id,
  Value<String> jsonData,
  Value<DateTime> cachedAt,
});

class $$CachedConfigTableFilterComposer
    extends Composer<_$AppDatabase, $CachedConfigTable> {
  $$CachedConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedConfigTable> {
  $$CachedConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedConfigTable> {
  $$CachedConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedConfigTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedConfigTable,
    CachedConfigData,
    $$CachedConfigTableFilterComposer,
    $$CachedConfigTableOrderingComposer,
    $$CachedConfigTableAnnotationComposer,
    $$CachedConfigTableCreateCompanionBuilder,
    $$CachedConfigTableUpdateCompanionBuilder,
    (
      CachedConfigData,
      BaseReferences<_$AppDatabase, $CachedConfigTable, CachedConfigData>
    ),
    CachedConfigData,
    PrefetchHooks Function()> {
  $$CachedConfigTableTableManager(_$AppDatabase db, $CachedConfigTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> jsonData = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
          }) =>
              CachedConfigCompanion(
            id: id,
            jsonData: jsonData,
            cachedAt: cachedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String jsonData,
            Value<DateTime> cachedAt = const Value.absent(),
          }) =>
              CachedConfigCompanion.insert(
            id: id,
            jsonData: jsonData,
            cachedAt: cachedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedConfigTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedConfigTable,
    CachedConfigData,
    $$CachedConfigTableFilterComposer,
    $$CachedConfigTableOrderingComposer,
    $$CachedConfigTableAnnotationComposer,
    $$CachedConfigTableCreateCompanionBuilder,
    $$CachedConfigTableUpdateCompanionBuilder,
    (
      CachedConfigData,
      BaseReferences<_$AppDatabase, $CachedConfigTable, CachedConfigData>
    ),
    CachedConfigData,
    PrefetchHooks Function()>;
typedef $$DownloadedContentTableCreateCompanionBuilder
    = DownloadedContentCompanion Function({
  Value<int> id,
  required int profileId,
  required String contentId,
  required String title,
  Value<String?> posterPath,
  required String mediaType,
  required String filePath,
  Value<String?> subtitlePath,
  Value<String> quality,
  Value<int> fileSizeBytes,
  Value<DateTime> downloadedAt,
  Value<int?> tmdbId,
});
typedef $$DownloadedContentTableUpdateCompanionBuilder
    = DownloadedContentCompanion Function({
  Value<int> id,
  Value<int> profileId,
  Value<String> contentId,
  Value<String> title,
  Value<String?> posterPath,
  Value<String> mediaType,
  Value<String> filePath,
  Value<String?> subtitlePath,
  Value<String> quality,
  Value<int> fileSizeBytes,
  Value<DateTime> downloadedAt,
  Value<int?> tmdbId,
});

final class $$DownloadedContentTableReferences extends BaseReferences<
    _$AppDatabase, $DownloadedContentTable, DownloadedContentData> {
  $$DownloadedContentTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias(
          $_aliasNameGenerator(db.downloadedContent.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DownloadedContentTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadedContentTable> {
  $$DownloadedContentTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subtitlePath => $composableBuilder(
      column: $table.subtitlePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DownloadedContentTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadedContentTable> {
  $$DownloadedContentTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentId => $composableBuilder(
      column: $table.contentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subtitlePath => $composableBuilder(
      column: $table.subtitlePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quality => $composableBuilder(
      column: $table.quality, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tmdbId => $composableBuilder(
      column: $table.tmdbId, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DownloadedContentTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadedContentTable> {
  $$DownloadedContentTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get subtitlePath => $composableBuilder(
      column: $table.subtitlePath, builder: (column) => column);

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DownloadedContentTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadedContentTable,
    DownloadedContentData,
    $$DownloadedContentTableFilterComposer,
    $$DownloadedContentTableOrderingComposer,
    $$DownloadedContentTableAnnotationComposer,
    $$DownloadedContentTableCreateCompanionBuilder,
    $$DownloadedContentTableUpdateCompanionBuilder,
    (DownloadedContentData, $$DownloadedContentTableReferences),
    DownloadedContentData,
    PrefetchHooks Function({bool profileId})> {
  $$DownloadedContentTableTableManager(
      _$AppDatabase db, $DownloadedContentTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadedContentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadedContentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadedContentTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> profileId = const Value.absent(),
            Value<String> contentId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterPath = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String?> subtitlePath = const Value.absent(),
            Value<String> quality = const Value.absent(),
            Value<int> fileSizeBytes = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
          }) =>
              DownloadedContentCompanion(
            id: id,
            profileId: profileId,
            contentId: contentId,
            title: title,
            posterPath: posterPath,
            mediaType: mediaType,
            filePath: filePath,
            subtitlePath: subtitlePath,
            quality: quality,
            fileSizeBytes: fileSizeBytes,
            downloadedAt: downloadedAt,
            tmdbId: tmdbId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int profileId,
            required String contentId,
            required String title,
            Value<String?> posterPath = const Value.absent(),
            required String mediaType,
            required String filePath,
            Value<String?> subtitlePath = const Value.absent(),
            Value<String> quality = const Value.absent(),
            Value<int> fileSizeBytes = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int?> tmdbId = const Value.absent(),
          }) =>
              DownloadedContentCompanion.insert(
            id: id,
            profileId: profileId,
            contentId: contentId,
            title: title,
            posterPath: posterPath,
            mediaType: mediaType,
            filePath: filePath,
            subtitlePath: subtitlePath,
            quality: quality,
            fileSizeBytes: fileSizeBytes,
            downloadedAt: downloadedAt,
            tmdbId: tmdbId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DownloadedContentTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable:
                        $$DownloadedContentTableReferences._profileIdTable(db),
                    referencedColumn: $$DownloadedContentTableReferences
                        ._profileIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DownloadedContentTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DownloadedContentTable,
    DownloadedContentData,
    $$DownloadedContentTableFilterComposer,
    $$DownloadedContentTableOrderingComposer,
    $$DownloadedContentTableAnnotationComposer,
    $$DownloadedContentTableCreateCompanionBuilder,
    $$DownloadedContentTableUpdateCompanionBuilder,
    (DownloadedContentData, $$DownloadedContentTableReferences),
    DownloadedContentData,
    PrefetchHooks Function({bool profileId})>;
typedef $$SubtitlePreferencesTableCreateCompanionBuilder
    = SubtitlePreferencesCompanion Function({
  Value<int> id,
  required int profileId,
  Value<String> preferredLanguage,
  Value<int> fontSize,
  Value<String> fontColor,
  Value<double> backgroundOpacity,
  Value<String> edgeStyle,
  Value<int> position,
});
typedef $$SubtitlePreferencesTableUpdateCompanionBuilder
    = SubtitlePreferencesCompanion Function({
  Value<int> id,
  Value<int> profileId,
  Value<String> preferredLanguage,
  Value<int> fontSize,
  Value<String> fontColor,
  Value<double> backgroundOpacity,
  Value<String> edgeStyle,
  Value<int> position,
});

final class $$SubtitlePreferencesTableReferences extends BaseReferences<
    _$AppDatabase, $SubtitlePreferencesTable, SubtitlePreference> {
  $$SubtitlePreferencesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.profiles.createAlias($_aliasNameGenerator(
          db.subtitlePreferences.profileId, db.profiles.id));

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager($_db, $_db.profiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SubtitlePreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $SubtitlePreferencesTable> {
  $$SubtitlePreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferredLanguage => $composableBuilder(
      column: $table.preferredLanguage,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fontSize => $composableBuilder(
      column: $table.fontSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fontColor => $composableBuilder(
      column: $table.fontColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get backgroundOpacity => $composableBuilder(
      column: $table.backgroundOpacity,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get edgeStyle => $composableBuilder(
      column: $table.edgeStyle, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableFilterComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SubtitlePreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $SubtitlePreferencesTable> {
  $$SubtitlePreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferredLanguage => $composableBuilder(
      column: $table.preferredLanguage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fontSize => $composableBuilder(
      column: $table.fontSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fontColor => $composableBuilder(
      column: $table.fontColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get backgroundOpacity => $composableBuilder(
      column: $table.backgroundOpacity,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get edgeStyle => $composableBuilder(
      column: $table.edgeStyle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableOrderingComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SubtitlePreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubtitlePreferencesTable> {
  $$SubtitlePreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get preferredLanguage => $composableBuilder(
      column: $table.preferredLanguage, builder: (column) => column);

  GeneratedColumn<int> get fontSize =>
      $composableBuilder(column: $table.fontSize, builder: (column) => column);

  GeneratedColumn<String> get fontColor =>
      $composableBuilder(column: $table.fontColor, builder: (column) => column);

  GeneratedColumn<double> get backgroundOpacity => $composableBuilder(
      column: $table.backgroundOpacity, builder: (column) => column);

  GeneratedColumn<String> get edgeStyle =>
      $composableBuilder(column: $table.edgeStyle, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.profileId,
        referencedTable: $db.profiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProfilesTableAnnotationComposer(
              $db: $db,
              $table: $db.profiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SubtitlePreferencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SubtitlePreferencesTable,
    SubtitlePreference,
    $$SubtitlePreferencesTableFilterComposer,
    $$SubtitlePreferencesTableOrderingComposer,
    $$SubtitlePreferencesTableAnnotationComposer,
    $$SubtitlePreferencesTableCreateCompanionBuilder,
    $$SubtitlePreferencesTableUpdateCompanionBuilder,
    (SubtitlePreference, $$SubtitlePreferencesTableReferences),
    SubtitlePreference,
    PrefetchHooks Function({bool profileId})> {
  $$SubtitlePreferencesTableTableManager(
      _$AppDatabase db, $SubtitlePreferencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtitlePreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtitlePreferencesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtitlePreferencesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> profileId = const Value.absent(),
            Value<String> preferredLanguage = const Value.absent(),
            Value<int> fontSize = const Value.absent(),
            Value<String> fontColor = const Value.absent(),
            Value<double> backgroundOpacity = const Value.absent(),
            Value<String> edgeStyle = const Value.absent(),
            Value<int> position = const Value.absent(),
          }) =>
              SubtitlePreferencesCompanion(
            id: id,
            profileId: profileId,
            preferredLanguage: preferredLanguage,
            fontSize: fontSize,
            fontColor: fontColor,
            backgroundOpacity: backgroundOpacity,
            edgeStyle: edgeStyle,
            position: position,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int profileId,
            Value<String> preferredLanguage = const Value.absent(),
            Value<int> fontSize = const Value.absent(),
            Value<String> fontColor = const Value.absent(),
            Value<double> backgroundOpacity = const Value.absent(),
            Value<String> edgeStyle = const Value.absent(),
            Value<int> position = const Value.absent(),
          }) =>
              SubtitlePreferencesCompanion.insert(
            id: id,
            profileId: profileId,
            preferredLanguage: preferredLanguage,
            fontSize: fontSize,
            fontColor: fontColor,
            backgroundOpacity: backgroundOpacity,
            edgeStyle: edgeStyle,
            position: position,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SubtitlePreferencesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (profileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.profileId,
                    referencedTable: $$SubtitlePreferencesTableReferences
                        ._profileIdTable(db),
                    referencedColumn: $$SubtitlePreferencesTableReferences
                        ._profileIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SubtitlePreferencesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SubtitlePreferencesTable,
    SubtitlePreference,
    $$SubtitlePreferencesTableFilterComposer,
    $$SubtitlePreferencesTableOrderingComposer,
    $$SubtitlePreferencesTableAnnotationComposer,
    $$SubtitlePreferencesTableCreateCompanionBuilder,
    $$SubtitlePreferencesTableUpdateCompanionBuilder,
    (SubtitlePreference, $$SubtitlePreferencesTableReferences),
    SubtitlePreference,
    PrefetchHooks Function({bool profileId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$WatchHistoryTableTableManager get watchHistory =>
      $$WatchHistoryTableTableManager(_db, _db.watchHistory);
  $$WatchlistTableTableManager get watchlist =>
      $$WatchlistTableTableManager(_db, _db.watchlist);
  $$ContinueWatchingTableTableManager get continueWatching =>
      $$ContinueWatchingTableTableManager(_db, _db.continueWatching);
  $$CachedConfigTableTableManager get cachedConfig =>
      $$CachedConfigTableTableManager(_db, _db.cachedConfig);
  $$DownloadedContentTableTableManager get downloadedContent =>
      $$DownloadedContentTableTableManager(_db, _db.downloadedContent);
  $$SubtitlePreferencesTableTableManager get subtitlePreferences =>
      $$SubtitlePreferencesTableTableManager(_db, _db.subtitlePreferences);
}
