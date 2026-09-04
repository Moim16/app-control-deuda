// =============================================================================
//  Lo unico que sabe de HTTP.
//
//  Pone el token en la cabecera, manda y devuelve JSON. No sabe que es una
//  deuda ni un abono: de eso se encargan los repositorios. Si mañana hay que
//  cambiar de `http` a otra cosa, se cambia aqui y nada mas se entera.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Lo que lanza este cliente. El mensaje viene de la API, que responde en
/// español y pensado para leerse ("Usuario o contraseña incorrectos"), asi que
/// se puede mostrar tal cual.
class ApiException implements Exception {
  ApiException(this.message, {this.status = 0});

  final String message;
  final int status;

  /// La sesion ya no vale: no es un error que reintentar.
  bool get sessionExpired => status == 401;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// De donde cuelga la API. Lo fija el repositorio de sesion al arrancar.
  String baseUrl = '';

  /// El token de la sesion en curso, o null.
  String? token;

  /// Cuantas peticiones hay ahora mismo en el aire.
  ///
  /// Sirve para una sola cosa: pintar la barrita de carga arriba. Va aqui —
  /// donde de verdad se sabe — y no en cada ViewModel contando a mano, que es
  /// como se acaba con una pantalla que dice que esta cargando cuando ya
  /// termino.
  final ValueNotifier<int> enVuelo = ValueNotifier(0);

  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body}) async {
    if (baseUrl.isEmpty) {
      throw ApiException('Falta decir dónde está el servidor.');
    }

    enVuelo.value++;
    late http.Response res;
    try {
      final req = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers['content-type'] = 'application/json'
        ..body = body == null ? '' : jsonEncode(body);
      if (token != null) req.headers['x-session-token'] = token!;
      res = await http.Response.fromStream(await _client.send(req)).timeout(_timeout);
    } catch (_) {
      // La peticion no llego a salir: sin señal, o el servidor no contesta. Se
      // dice asi, no "SocketException".
      throw ApiException('Sin conexión. Revisa tu internet e intenta de nuevo.');
    } finally {
      // En el `finally`: si la peticion falla, la barrita tiene que parar
      // igual. Si no, se queda girando para siempre.
      enVuelo.value--;
    }

    final data = _decode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(
        (data['error'] as String?) ?? 'Error ${res.statusCode}',
        status: res.statusCode,
      );
    }
    return data;
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      // Un cuerpo que no es JSON solo pasa si algo esta muy mal; el codigo de
      // estado ya dijo lo suyo.
      return {};
    }
  }

  void close() => _client.close();
}
