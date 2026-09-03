/// Substitutes server-sent placeholders in push notification text with
/// values only known on the client — the server has no account system, so
/// it can't fill in a commenter's name itself and instead sends the literal
/// token for the app to replace.
String applyNotificationPlaceholders(String text, {required String username}) {
  if (!text.contains('%username%')) return text;
  return text.replaceAll('%username%', username.isEmpty ? 'ХЗ кто' : username);
}
