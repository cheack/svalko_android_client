import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

final favoritesBoxProvider =
    Provider<Box<String>>((_) => throw UnimplementedError());

final favoriteCommentsBoxProvider =
    Provider<Box<String>>((_) => throw UnimplementedError());

abstract class _Favoritable {
  int get id;
  DateTime get addedAt;
  Map<String, dynamic> toJson();
}

class FavoritePost implements _Favoritable {
  const FavoritePost({
    required this.id,
    required this.authorName,
    required this.publishedAt,
    required this.addedAt,
    this.firstImageUrl,
    this.previewText,
  });

  @override final int id;
  final String authorName;
  final DateTime publishedAt;
  @override final DateTime addedAt;
  final String? firstImageUrl;
  final String? previewText;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'publishedAt': publishedAt.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
        if (firstImageUrl != null) 'firstImageUrl': firstImageUrl,
        if (previewText != null) 'previewText': previewText,
      };

  factory FavoritePost.fromJson(Map<String, dynamic> json) => FavoritePost(
        id: json['id'] as int,
        authorName: json['authorName'] as String,
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        addedAt: DateTime.parse(json['addedAt'] as String),
        firstImageUrl: json['firstImageUrl'] as String?,
        previewText: json['previewText'] as String?,
      );
}

class FavoriteComment implements _Favoritable {
  const FavoriteComment({
    required this.id,
    required this.postId,
    required this.commentPage,
    required this.authorName,
    required this.publishedAt,
    required this.addedAt,
    this.authorProfileUrl = '',
    this.previewText,
    this.textHtml,
    this.imageUrls = const [],
    this.videoUrls = const [],
    this.isKum = false,
  });

  @override final int id;
  final int postId;
  final int commentPage;
  final String authorName;
  final DateTime publishedAt;
  @override final DateTime addedAt;
  final String authorProfileUrl;
  final String? previewText;
  final String? textHtml;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final bool isKum;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'commentPage': commentPage,
        'authorName': authorName,
        if (authorProfileUrl.isNotEmpty) 'authorProfileUrl': authorProfileUrl,
        'publishedAt': publishedAt.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
        if (previewText != null) 'previewText': previewText,
        if (textHtml != null) 'textHtml': textHtml,
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (videoUrls.isNotEmpty) 'videoUrls': videoUrls,
        if (isKum) 'isKum': isKum,
      };

  factory FavoriteComment.fromJson(Map<String, dynamic> json) =>
      FavoriteComment(
        id: json['id'] as int,
        postId: json['postId'] as int,
        commentPage: json['commentPage'] as int,
        authorName: json['authorName'] as String,
        authorProfileUrl: json['authorProfileUrl'] as String? ?? '',
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        addedAt: DateTime.parse(json['addedAt'] as String),
        previewText: json['previewText'] as String?,
        textHtml: json['textHtml'] as String?,
        imageUrls: (json['imageUrls'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
        videoUrls: (json['videoUrls'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
        isKum: json['isKum'] == true,
      );
}

// ---------------------------------------------------------------------------
// Shared base notifier
// ---------------------------------------------------------------------------

abstract class _FavoriteNotifier<T extends _Favoritable>
    extends Notifier<List<T>> {
  Provider<Box<String>> get _boxProvider;
  T _fromJson(Map<String, dynamic> json);

  static int _byAddedAt(_Favoritable a, _Favoritable b) =>
      b.addedAt.compareTo(a.addedAt);

  @override
  List<T> build() {
    final box = ref.watch(_boxProvider);
    return box.values
        .map((v) {
          try {
            return _fromJson(jsonDecode(v) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<T>()
        .toList()
      ..sort(_byAddedAt);
  }

  bool isFavorite(int id) => state.any((f) => f.id == id);

  void add(T item) {
    ref.read(_boxProvider).put('${item.id}', jsonEncode(item.toJson()));
    state = [item, ...state.where((f) => f.id != item.id)]
      ..sort(_byAddedAt);
  }

  void remove(int id) {
    ref.read(_boxProvider).delete('$id');
    state = state.where((f) => f.id != id).toList();
  }

  void toggle(T item) {
    if (isFavorite(item.id)) {
      remove(item.id);
    } else {
      add(item);
    }
  }

  List<Map<String, dynamic>> exportList() =>
      state.map((f) => f.toJson()).toList();

  int importList(List<dynamic> list) {
    final incoming = list
        .map((e) {
          try {
            return _fromJson(e as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<T>()
        .toList();
    final existingIds = state.map((f) => f.id).toSet();
    final newItems =
        incoming.where((f) => !existingIds.contains(f.id)).toList();
    final box = ref.read(_boxProvider);
    for (final f in newItems) {
      box.put('${f.id}', jsonEncode(f.toJson()));
    }
    if (newItems.isNotEmpty) {
      state = [...newItems, ...state]..sort(_byAddedAt);
    }
    return newItems.length;
  }
}

// ---------------------------------------------------------------------------
// Favorite posts
// ---------------------------------------------------------------------------

class FavoritesNotifier extends _FavoriteNotifier<FavoritePost> {
  @override
  Provider<Box<String>> get _boxProvider => favoritesBoxProvider;

  @override
  FavoritePost _fromJson(Map<String, dynamic> json) =>
      FavoritePost.fromJson(json);

  /// Returns JSON string with all favorite posts (legacy single-type export).
  String exportJson() => jsonEncode(exportList());

  /// Merges favorites from a JSON string (legacy format). Returns count added.
  int importJson(String json) => importList(jsonDecode(json) as List<dynamic>);
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<FavoritePost>>(
        FavoritesNotifier.new);

// ---------------------------------------------------------------------------
// Favorite comments
// ---------------------------------------------------------------------------

class FavoriteCommentsNotifier extends _FavoriteNotifier<FavoriteComment> {
  @override
  Provider<Box<String>> get _boxProvider => favoriteCommentsBoxProvider;

  @override
  FavoriteComment _fromJson(Map<String, dynamic> json) =>
      FavoriteComment.fromJson(json);
}

final favoriteCommentsProvider =
    NotifierProvider<FavoriteCommentsNotifier, List<FavoriteComment>>(
        FavoriteCommentsNotifier.new);
