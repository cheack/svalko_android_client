import 'package:dio/dio.dart';

import '../core/result.dart';
import 'svalko_api.dart' show mapDioError;

/// Direct link to an image already hosted on fastpic.org.
final _directUrlRe = RegExp(r'value="(https://i\d+\.fastpic\.org/big/[^"]+)"');
final _sessionUrlRe = RegExp(r'url=(\S+)');

/// Extracts the session page URL from the `Refresh` header fastpic answers an
/// upload with, e.g. `0;url=https://fastpic.org/session/2026/1006/abc.html`.
String? parseFastpicSessionUrl(String? refreshHeader) =>
    refreshHeader == null ? null : _sessionUrlRe.firstMatch(refreshHeader)?.group(1);

/// Extracts the full-size image link from the session page HTML.
String? parseFastpicDirectUrl(String sessionHtml) =>
    _directUrlRe.firstMatch(sessionHtml)?.group(1);

/// Uploads local images to fastpic.org with a text thumbnail. The original is
/// sent untouched (no resize, no JPEG recompression). fastpic refuses to
/// hotlink images larger than about 1200px, so only then is the upload repeated
/// with the original shrunk to [_hotlinkLimit].
class FastpicUploader {
  FastpicUploader({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              headers: {'User-Agent': 'Mozilla/5.0'},
              // The upload answers 200 with a Refresh header, never a redirect.
              followRedirects: false,
              validateStatus: (s) => s != null && s < 400,
            ));

  final Dio _dio;

  static const _uploadUrl = 'https://fastpic.org/uploadmulti';
  static const _hotlinkLimit = 1200;

  /// Returns the direct URL of the uploaded image.
  Future<Result<String, AppError>> upload(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final original = await _upload(filePath, onProgress: onProgress);
      if (original != null) return Ok(original);
      final shrunk = await _upload(filePath, maxSide: _hotlinkLimit, onProgress: onProgress);
      return shrunk == null ? const Err(AppError.parseFailure) : Ok(shrunk);
    } on DioException catch (e) {
      return Err(mapDioError(e));
    } catch (_) {
      return const Err(AppError.unknown);
    }
  }

  /// Null when fastpic accepted the file but offers no direct link for it.
  Future<String?> _upload(
    String filePath, {
    int? maxSide,
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'uploading': '1',
      'fp': 'not-loaded',
      'check_thumb': 'text',
      'thumb_text': 'Увеличить',
      'thumb_size': '150',
      if (maxSide != null) ...{
        'check_orig_resize': '1',
        'res_select': '$maxSide',
        'orig_resize': '$maxSide',
      },
      'file[]': await MultipartFile.fromFile(filePath),
      'submit': 'Загрузить',
    });
    final response = await _dio.post<String>(
      _uploadUrl,
      data: formData,
      options: Options(responseType: ResponseType.plain),
      onSendProgress: onProgress,
    );
    final sessionUrl = parseFastpicSessionUrl(response.headers.value('refresh'));
    if (sessionUrl == null) throw StateError('fastpic: no session url');

    final session = await _dio.get<String>(
      sessionUrl,
      options: Options(responseType: ResponseType.plain),
    );
    return parseFastpicDirectUrl(session.data ?? '');
  }
}
