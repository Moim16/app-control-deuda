// =============================================================================
//  La sesion: quien entro, y de que servidor.
//
//  Es la fuente de verdad de "hay alguien dentro". Las pantallas no preguntan
//  por el token: preguntan por `me`.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../domain/models/me.dart';
import '../../utils/result.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

class AuthRepository extends ChangeNotifier {
  AuthRepository({required ApiClient api, required SessionStore store})
      : _api = api,
        _store = store;

  final ApiClient _api;
  final SessionStore _store;

  Me? _me;
  Me? get me => _me;
  bool get signedIn => _me != null;

  String get baseUrl => _api.baseUrl;
  bool get hasServer => _api.baseUrl.isNotEmpty;

  /// Recupera lo guardado y comprueba con el servidor que la sesion siga
  /// valiendo. Devuelve `Ok(null)` si simplemente no habia sesion: eso no es
  /// un error, es la primera vez.
  Future<Result<Me?>> restore() async {
    _api.baseUrl = await _store.readUrl();
    _api.token = await _store.readToken();
    if (_api.token == null || _api.baseUrl.isEmpty) return const Ok(null);

    final r = await _fetchMe();
    if (r case Err<Me?> e when e.sessionExpired) {
      // El token caduco o se lo revocaron: se limpia y se pide entrar de nuevo,
      // sin mostrar un error.
      await _clear();
      return const Ok(null);
    }
    return r;
  }

  Future<Result<Me?>> _fetchMe() => Result.guard<Me?>(
        () async {
          final j = await _api.get('/api/auth');
          _me = Me.fromJson(
            j['me'] as Map<String, dynamic>,
            account: j['account'] as Map<String, dynamic>?,
          );
          notifyListeners();
          return _me;
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  Future<Result<Me>> signIn({
    required String user,
    required String password,
    String? serverUrl,
  }) =>
      Result.guard<Me>(
        () async {
          if (serverUrl != null && serverUrl.trim() != _api.baseUrl) {
            await _store.writeUrl(serverUrl);
            _api.baseUrl = await _store.readUrl();
          }
          final j = await _api.post('/api/auth', {'name': user, 'password': password});
          _api.token = j['token'] as String;
          await _store.writeToken(_api.token!);
          _me = Me.fromJson(
            j['user'] as Map<String, dynamic>,
            account: j['account'] as Map<String, dynamic>?,
          );
          notifyListeners();
          return _me!;
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  Future<void> signOut() => _clear();

  Future<void> _clear() async {
    _api.token = null;
    _me = null;
    await _store.clearToken();
    notifyListeners();
  }

  static String _mensaje(Object e) =>
      e is ApiException ? e.message : 'Algo salió mal. Intenta de nuevo.';

  static bool _vencida(Object e) => e is ApiException && e.sessionExpired;
}
