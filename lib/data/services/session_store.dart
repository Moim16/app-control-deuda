// =============================================================================
//  Lo unico que sabe de almacenamiento en el telefono: el token de sesion.
//
//  La direccion del servidor NO se guarda ni se pregunta. Antes habia un campo
//  "Cambiar el servidor" en la pantalla de entrada, y era un pie de foto de una
//  app de desarrollo: quien la usa no tiene por que saber que existe una URL, y
//  equivocarse ahi deja la app sin poder entrar sin decir por que.
//
//  Para apuntar a la maquina de desarrollo se compila con
//  `--dart-define=API_URL=http://192.168.x.x:3000`, que es donde vive esa
//  decision.
// =============================================================================

import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _tokenKey = 'dd_token';

  /// Donde vive la API.
  static const produccion = 'https://control-deuda.vercel.app';

  static const compiledUrl = String.fromEnvironment('API_URL', defaultValue: produccion);

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> readToken() async => (await _prefs).getString(_tokenKey);

  Future<void> writeToken(String token) async => (await _prefs).setString(_tokenKey, token);

  Future<void> clearToken() async => (await _prefs).remove(_tokenKey);

  /// Sin barra al final, para que `$baseUrl/api/...` no quede con doble barra.
  String get url => compiledUrl.trim().replaceAll(RegExp(r'/+$'), '');
}
