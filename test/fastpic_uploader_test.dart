import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/core/result.dart';
import 'package:svalko_client/data/fastpic_uploader.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

const _sessionUrl = 'https://fastpic.org/session/2026/1006/abc.html';
const _sessionHtml = '''
<input value="https://i128.fastpic.org/big/2026/1006/3d/abc.jpeg">
[URL=https://fastpic.org/view/128/abc.html][IMG]https://i128.fastpic.org/thumb/2026/1006/3d/abc.jpeg[/IMG][/URL]
''';

void main() {
  group('parsers', () {
    test('session url is taken from the Refresh header', () {
      expect(parseFastpicSessionUrl('0;url=$_sessionUrl'), _sessionUrl);
      expect(parseFastpicSessionUrl(null), isNull);
      expect(parseFastpicSessionUrl('0'), isNull);
    });

    test('direct url is the big image, not the thumbnail', () {
      expect(parseFastpicDirectUrl(_sessionHtml),
          'https://i128.fastpic.org/big/2026/1006/3d/abc.jpeg');
      expect(parseFastpicDirectUrl('<html></html>'), isNull);
    });
  });

  group('FastpicUploader.upload', () {
    late File image;

    setUp(() {
      image = File('${Directory.systemTemp.path}/fastpic_test_${DateTime.now().microsecondsSinceEpoch}.png')
        ..writeAsBytesSync([1, 2, 3]);
    });
    tearDown(() => image.deleteSync());

    Dio dioWith(_FakeAdapter adapter) => Dio(BaseOptions(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400,
        ))
          ..httpClientAdapter = adapter;

    test('posts the file to uploadmulti and follows the session page', () async {
      final adapter = _FakeAdapter((o) {
        if (o.uri.path == '/uploadmulti') {
          return ResponseBody.fromString('', 200, headers: {
            'refresh': ['0;url=$_sessionUrl'],
          });
        }
        return ResponseBody.fromString(_sessionHtml, 200);
      });

      final result = await FastpicUploader(dio: dioWith(adapter)).upload(image.path);

      expect(result.valueOrNull, 'https://i128.fastpic.org/big/2026/1006/3d/abc.jpeg');
      expect(adapter.requests.first.uri.toString(), 'https://fastpic.org/uploadmulti');
      final form = adapter.requests.first.data as FormData;
      expect(form.files.single.key, 'file[]');
      final fields = Map.fromEntries(form.fields);
      expect(fields['check_thumb'], 'text');
      for (final k in ['check_orig_resize', 'res_select', 'orig_resize', 'check_optimization', 'jpeg_quality']) {
        expect(fields.containsKey(k), isFalse, reason: '$k would shrink or recompress the original');
      }
      expect(adapter.requests.last.uri.toString(), _sessionUrl);
    });

    test('missing Refresh header is an error', () async {
      final adapter = _FakeAdapter((_) => ResponseBody.fromString('', 200));
      final result = await FastpicUploader(dio: dioWith(adapter)).upload(image.path);
      expect(result.isErr, isTrue);
    });

    test('image too big to hotlink is re-uploaded shrunk to 1200px', () async {
      var uploads = 0;
      final adapter = _FakeAdapter((o) {
        if (o.uri.path == '/uploadmulti') {
          uploads++;
          return ResponseBody.fromString('', 200, headers: {
            'refresh': ['0;url=$_sessionUrl'],
          });
        }
        // First session page has no direct link, the second does.
        return ResponseBody.fromString(uploads == 1 ? '<html>нельзя</html>' : _sessionHtml, 200);
      });

      final result = await FastpicUploader(dio: dioWith(adapter)).upload(image.path);

      expect(result.valueOrNull, 'https://i128.fastpic.org/big/2026/1006/3d/abc.jpeg');
      final uploadsSent = adapter.requests.where((r) => r.uri.path == '/uploadmulti').toList();
      expect(uploadsSent, hasLength(2));
      expect(Map.fromEntries((uploadsSent[0].data as FormData).fields).containsKey('orig_resize'), isFalse);
      expect(Map.fromEntries((uploadsSent[1].data as FormData).fields)['orig_resize'], '1200');
    });

    test('no direct link even after shrinking is a parse failure', () async {
      final adapter = _FakeAdapter((o) => o.uri.path == '/uploadmulti'
          ? ResponseBody.fromString('', 200, headers: {
              'refresh': ['0;url=$_sessionUrl'],
            })
          : ResponseBody.fromString('<html></html>', 200));
      final result = await FastpicUploader(dio: dioWith(adapter)).upload(image.path);
      expect((result as Err).error, AppError.parseFailure);
    });

    test('server error maps to a network error', () async {
      final adapter = _FakeAdapter((_) => ResponseBody.fromString('', 500));
      final result = await FastpicUploader(dio: dioWith(adapter)).upload(image.path);
      expect((result as Err).error, AppError.network);
    });
  });
}
