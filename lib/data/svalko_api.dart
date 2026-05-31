import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:html/parser.dart' as html_parser;
import '../core/config.dart';
import '../core/encoding.dart';
import '../core/logging_interceptor.dart';
import '../core/result.dart';
import '../models/feed_source.dart';

class CommentFormData {
  const CommentFormData({
    required this.uploadId,
    required this.uploadKey,
    required this.cookie,
    required this.suggestedAuthor,
  });
  final String uploadId;
  final String uploadKey;
  final String cookie;
  final String suggestedAuthor;
}

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
      AuthorFeed(:final profileUrl) => page == null
          ? profileUrl
          : () {
              // Extract the raw encoded ?author=... param from the profileUrl.
              final authorParam = profileUrl.contains('?author=')
                  ? profileUrl.split('?author=').last
                  : '';
              return '${Config.baseUrl}/page/$page?author=$authorParam';
            }(),
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

  Future<Result<String, AppError>> fetchTrendsPage() =>
      _get('${Config.baseUrl}/trends.html');

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

  Future<Result<CommentFormData, AppError>> fetchPostForm() =>
      _fetchForm('${Config.baseUrl}/update.html');

  Future<Result<CommentFormData, AppError>> fetchCommentForm(int postId) =>
      _fetchForm('${Config.baseUrl}/update.html?comment=$postId');

  Future<Result<CommentFormData, AppError>> _fetchForm(String url) async {
    try {
      final response = await _dio.get<dynamic>(
        url,
        options: Options(responseType: ResponseType.bytes, followRedirects: false),
      );
      final setCookies = response.headers['set-cookie'] ?? [];
      final sessionCookie = setCookies
          .map((h) => RegExp(r'PHPSESSID=[^;]+').firstMatch(h)?.group(0))
          .whereType<String>()
          .firstOrNull ?? '';
      final data = response.data;
      final bytes = data is Uint8List ? data : Uint8List.fromList(data as List<int>);
      final html = await decodeWin1251(bytes);
      final doc = html_parser.parse(html);
      final uploadId = doc.querySelector('input[name="upload_id"]')?.attributes['value'] ?? '';
      final uploadKey = doc.querySelector('input[name="upload_key"]')?.attributes['value'] ?? '';
      final suggestedAuthor = doc.querySelector('input[name="author"]')?.attributes['value'] ?? 'Аноним';
      if (uploadId.isEmpty || uploadKey.isEmpty) return const Err(AppError.parseFailure);
      return Ok(CommentFormData(
        uploadId: uploadId,
        uploadKey: uploadKey,
        cookie: sessionCookie,
        suggestedAuthor: suggestedAuthor,
      ));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  /// Fetches the list of already-uploaded files for a given upload session.
  Future<Result<String, AppError>> fetchUploadedFilesList({
    required String uploadId,
    required String uploadKey,
  }) =>
      _get(
        '${Config.baseUrl}/upload_area_handler.php'
        '?upload_id=$uploadId&upload_key=$uploadKey',
      );

  /// Uploads an image to the comment upload area.
  /// Returns the HTML listing of all uploaded files on success.
  Future<Result<String, AppError>> uploadCommentImage({
    required String uploadId,
    required String uploadKey,
    required String cookie,
    required String filePath,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'upload_id': uploadId,
        'upload_key': uploadKey,
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post<dynamic>(
        '${Config.baseUrl}/upload_area_handler.php',
        data: formData,
        options: Options(
          headers: {if (cookie.isNotEmpty) 'Cookie': cookie},
          responseType: ResponseType.bytes,
        ),
        onSendProgress: onProgress,
      );
      final data = response.data;
      final Uint8List bytes = data is Uint8List
          ? data
          : Uint8List.fromList(data as List<int>);
      return Ok(await decodeWin1251(bytes));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  /// Deletes a previously uploaded file from the upload area.
  Future<Result<void, AppError>> deleteUploadedFile({
    required String uploadId,
    required String uploadKey,
    required String cookie,
    required String deleteParam,
  }) async {
    try {
      await _dio.get<dynamic>(
        '${Config.baseUrl}/upload_area_handler.php',
        queryParameters: {
          'upload_id': uploadId,
          'upload_key': uploadKey,
          'delete': deleteParam,
        },
        options: Options(
          headers: {if (cookie.isNotEmpty) 'Cookie': cookie},
          responseType: ResponseType.bytes,
        ),
      );
      return const Ok(null);
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  Future<Result<void, AppError>> submitPost({
    required String author,
    required String text,
    required CommentFormData form,
  }) => _submitUpdate(author: author, text: text, form: form);

  Future<Result<void, AppError>> submitComment({
    required int postId,
    required String author,
    required String text,
    required CommentFormData form,
  }) => _submitUpdate(author: author, text: text, form: form, postId: postId);

  Future<Result<void, AppError>> _submitUpdate({
    required String author,
    required String text,
    required CommentFormData form,
    int? postId,
  }) async {
    try {
      final encodedAuthor = await encodeQueryWin1251(author);
      final encodedText = await encodeQueryWin1251(text);
      final encodedSubmit = await encodeQueryWin1251('Да!');
      final body = StringBuffer()
        ..write('upload_id=${Uri.encodeQueryComponent(form.uploadId)}')
        ..write('&upload_key=${Uri.encodeQueryComponent(form.uploadKey)}')
        ..write('&comment=${postId ?? 0}')
        ..write('&pre_id=0')
        ..write('&author=$encodedAuthor')
        ..write('&article=$encodedText')
        ..write('&formsubmit=$encodedSubmit');
      await _dio.post<dynamic>(
        '${Config.baseUrl}/?mode=update',
        data: body.toString(),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {if (form.cookie.isNotEmpty) 'Cookie': form.cookie},
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.bytes,
        ),
      );
      return const Ok(null);
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  Future<Result<String, AppError>> submitBanAnswer({
    required int riddleId,
    required String answer,
  }) async {
    try {
      final encodedAnswer = await encodeQueryWin1251(answer);
      final body = 'q=$riddleId&a=$encodedAnswer';
      final response = await _dio.post<dynamic>(
        Config.baseUrl,
        data: body,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.bytes,
        ),
      );
      final data = response.data;
      final Uint8List bytes = data is Uint8List
          ? data
          : Uint8List.fromList(data as List<int>);
      return Ok(await decodeWin1251(bytes));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  Future<Result<String, AppError>> vote(int postId, int vote) =>
      _action('${Config.baseUrl}/vote.php?post_id=$postId&vote=$vote&dynamic=1');

  Future<Result<String, AppError>> boroda(int postId, int dbl) =>
      _action('${Config.baseUrl}/boroda.php?boroda_id=$postId&double=$dbl&dynamic=1');

  Future<Result<String, AppError>> _action(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return Ok(response.data ?? '');
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
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
