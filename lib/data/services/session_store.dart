// =============================================================================
//  Lo unico que sabe de almacenamiento en el telefono.
//
//  Guarda el token de sesion y la direccion del servidor, que es el equivalente
//  del localStorage de la PWA.
// =============================================================================

import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _tokenKey = 'dd_token';
  static const _urlKey = 'dd_url';

  /// La direccion con la que se compilo, si se paso
  /// (`--dart-define=API_URL=https://...`). Sirve para que la app instalada ya
  /// venga apuntando a produccion.
  static const compiledUrl = String.fromEnvironment('API_URL', defaultValue: '');

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> readToken() async => (await _prefs).getString(_tokenKey);

  Future<void> writeToken(String token) async => (await _prefs).setString(_tokenKey, token);

  Future<void> clearToken() async => (await _prefs).remove(_tokenKey);

  /// La direccion guardada; si no hay, la de compilacion.
  Future<String> readUrl() async => (await _prefs).getString(_urlKey) ?? compiledUrl;

  Future<void> writeUrl(String url) async =>
      (await _prefs).setString(_urlKey, _normalize(url));

  /// Sin espacios ni barra al final, para que `$baseUrl/api/...` no quede con
  /// doble barra.
  static String _normalize(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');
}
