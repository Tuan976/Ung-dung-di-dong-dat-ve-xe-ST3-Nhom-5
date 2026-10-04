import 'dart:html' as html;
void saveWebToken(String key, String token) { html.window.localStorage[key] = token; }
String? getWebToken(String key) { return html.window.localStorage[key]; }
void deleteWebToken(String key) { html.window.localStorage.remove(key); }
