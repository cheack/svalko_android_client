import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [json] to a temp file and opens the share sheet for it.
Future<void> shareFavoritesJson(
  String json, {
  String subject = 'Избранное Свалочки',
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/svalko_favorites.json');
  await file.writeAsString(json);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/json')],
    subject: subject,
  );
}

/// Lets the user pick a `.json` file and returns its contents, or null if
/// the picker was cancelled.
Future<String?> pickFavoritesJsonFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  final path = result?.files.single.path;
  if (path == null) return null;
  return File(path).readAsString();
}
