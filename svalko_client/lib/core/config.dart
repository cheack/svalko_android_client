abstract final class Config {
  static const String baseUrl = 'https://svalko.org';
  static const String pdaBaseUrl = 'https://pda.svalko.org';
  static const String tagsUrl = '$baseUrl/tags.html';
  static const String rssUrl = '$baseUrl/rss.php';
  static const String rssCommentsUrl = '$rssUrl?comments=1';

  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const String charset = 'windows-1251';

  static const Duration pageCacheTtl = Duration(minutes: 5);
}
