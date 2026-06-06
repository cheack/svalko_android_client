abstract final class Config {
  static String _baseUrl = 'https://svalko.org';

  static String get baseUrl => _baseUrl;
  static String lastUrl({int skip = 0}) =>
      skip > 0 ? '$_baseUrl/last.html?skip=$skip' : '$_baseUrl/last.html';
  static String get tagsUrl => '$_baseUrl/tags.html';
  static String get imagesUrl => '$_baseUrl/images.html';
  static String get rssUrl => '$_baseUrl/rss.php';
  static String get rssCommentsUrl => '$rssUrl?comments=1';

  // ignore: use_setters_to_change_properties
  static void setBaseUrl(String url) => _baseUrl = url;

  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  static const String charset = 'windows-1251';

  static const Duration pageCacheTtl = Duration(minutes: 5);
}
