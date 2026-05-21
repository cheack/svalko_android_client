import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import '../core/config.dart';
import '../core/encoding.dart';
import '../core/logging_interceptor.dart';
import '../core/result.dart';
import '../models/feed_source.dart';

class SvalkoApi {
  SvalkoApi({FileCacheStore? cacheStore})
      : _cacheStore = cacheStore,
        _dio = _buildDio(cacheStore);

  final FileCacheStore? _cacheStore;
  final Dio _dio;

  // Historical pages (index < totalPages-1) — immutable, cache 30 days.
  // forceCache: ignores server Cache-Control headers and caches unconditionally.
  static const _oldPagePolicy = CachePolicy.forceCache;
  static const _oldPageMaxStale = Duration(days: 30);

  // Latest page (no ?page= param) — always hit network, but store result.
  static const _latestPagePolicy = CachePolicy.refreshForceCache;

  static Dio _buildDio(FileCacheStore? store) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: Config.connectTimeout,
        receiveTimeout: Config.receiveTimeout,
        responseType: ResponseType.bytes,
        headers: {'User-Agent': Config.userAgent},
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
    dio.interceptors.add(LoggingInterceptor());
    if (store != null) {
      dio.interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(store: store, policy: CachePolicy.noCache),
        ),
      );
    }
    return dio;
  }

  /// Fetches the feed page. [page] = null → latest (homepage/tag root).
  Future<Result<String, AppError>> fetchFeedPage({
    int? page,
    FeedSource source = const MainFeed(),
  }) async {
    final url = switch (source) {
      MainFeed() => page == null
          ? Config.baseUrl
          : '${Config.baseUrl}/page/$page',
      TagFeed(:final tagId) => page == null
          ? '${Config.baseUrl}/tag/$tagId'
          : '${Config.baseUrl}/page/$page?tag_id=$tagId',
    };
    return _get(url);
  }

  Future<Result<int, AppError>> fetchRandomPostId() async {
    try {
      final response = await _dio.get<dynamic>(
        '${Config.baseUrl}/random.html',
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.bytes,
        ),
      );
      final match =
          RegExp(r'/(\d+)\.html').firstMatch(response.realUri.toString());
      final id = int.tryParse(match?.group(1) ?? '');
      if (id == null) return const Err(AppError.parseFailure);
      return Ok(id);
    } on DioException {
      return const Err(AppError.network);
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  Future<Result<String, AppError>> fetchImagesPage() =>
      _get(Config.imagesUrl);

  // Returns (postId, commentId?) — commentId from ?high=N in the redirect URL.
  Future<Result<(int, int?), AppError>> fetchImagePostId(String filename) async {
    try {
      final url =
          '${Config.imagesUrl}?find=${Uri.encodeComponent(filename)}';
      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.bytes,
        ),
      );
      final finalUri = response.realUri;
      final postMatch = RegExp(r'/(\d+)\.html').firstMatch(finalUri.toString());
      final postId = int.tryParse(postMatch?.group(1) ?? '');
      if (postId == null) return const Err(AppError.parseFailure);
      final commentId = int.tryParse(finalUri.queryParameters['high'] ?? '');
      return Ok((postId, commentId));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  Future<Result<String, AppError>> fetchTagsPage() => _get(
        Config.tagsUrl,
        cacheOptions: _cacheStore == null
            ? null
            : CacheOptions(
                store: _cacheStore,
                policy: CachePolicy.forceCache,
                maxStale: const Duration(days: 1),
              ),
      );

  /// Fetches a post page with its comments.
  /// [commentsPage] null → server default (last page).
  /// [isHistorical] true → page is not the last one; safe to cache 30 days.
  Future<Result<String, AppError>> fetchPost(
    int id, {
    int? commentsPage,
    bool isHistorical = false,
  }) async {
    final base = '${Config.baseUrl}/$id.html';
    final url =
        commentsPage != null ? '$base?page=$commentsPage' : base;
    final cacheOptions = _cacheStore == null
        ? null
        : (commentsPage != null && isHistorical)
            ? CacheOptions(
                store: _cacheStore,
                policy: _oldPagePolicy,
                maxStale: _oldPageMaxStale,
              )
            : CacheOptions(
                store: _cacheStore,
                policy: _latestPagePolicy,
                maxStale: const Duration(minutes: 15),
              );
    return _get(url, cacheOptions: cacheOptions);
  }

  Future<Result<String, AppError>> _get(
    String url, {
    CacheOptions? cacheOptions,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        url,
        options: cacheOptions?.toOptions(),
      );
      final data = response.data;
      final Uint8List bytes;
      if (data is Uint8List) {
        bytes = data;
      } else if (data is List<int>) {
        // FileCacheStore may deserialize bytes as List<int>, not Uint8List
        bytes = Uint8List.fromList(data);
      } else {
        return const Err(AppError.unknown);
      }
      final html = await decodeWin1251(bytes);
      return Ok(html);
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  AppError _mapDioError(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          AppError.timeout,
        DioExceptionType.badResponse =>
          e.response?.statusCode == 404 ? AppError.notFound : AppError.network,
        DioExceptionType.connectionError => AppError.network,
        _ => AppError.unknown,
      };
}
