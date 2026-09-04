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

  Recuperacion _recuperacion = const Recuperacion(tiene: false);

  /// Si hay codigo de recuperacion. Importa: sin el, olvidar la contraseña deja
  /// a la persona fuera para siempre — no hay correo configurado.
  Recuperacion get recuperacion => _recuperacion;


  /// Recupera lo guardado y comprueba con el servidor que la sesion siga
  /// valiendo. Devuelve `Ok(null)` si simplemente no habia sesion: eso no es
  /// un error, es la primera vez.
  Future<Result<Me?>> restore() async {
    _api.baseUrl = _store.url;
    _api.token = await _store.readToken();
    if (_api.token == null) return const Ok(null);

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
          _recuperacion = Recuperacion.fromJson(j['recovery'] as Map<String, dynamic>?);
          notifyListeners();
          return _me;
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  Future<Result<Me>> signIn({
    required String user,
    required String password,
  }) =>
      Result.guard<Me>(
        () async {
          _api.baseUrl = _store.url;
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

  /* ------------------------------------------------------------- la cuenta -- */

  /// Vuelve a preguntar quien soy. Se usa despues de cambiar el nombre de la
  /// cuenta o los permisos de alguien.
  Future<Result<Me?>> refrescar() => _fetchMe();

  Future<Result<void>> renombrarCuenta(String nombre) => Result.guard<void>(
        () async {
          await _api.put('/api/auth?account=1', {'name': nombre.trim()});
          await _fetchMe();
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Cambia MI contraseña. El servidor devuelve un token nuevo: la sesion sigue
  /// abierta en este telefono y se cierra en los demas, que es lo que uno
  /// espera al cambiar una contraseña.
  Future<Result<void>> cambiarPassword({
    required String actual,
    required String nueva,
  }) =>
      Result.guard<void>(
        () async {
          final j = await _api.put('/api/auth', {
            'currentPassword': actual,
            'password': nueva,
          });
          final token = j['token'] as String?;
          if (token != null) {
            _api.token = token;
            await _store.writeToken(token);
          }
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Genera (o renueva) mi codigo de recuperacion. Devuelve el codigo, que se
  /// enseña UNA sola vez.
  Future<Result<String>> generarCodigo(String password) => Result.guard<String>(
        () async {
          final j = await _api.put('/api/auth?recovery=1', {'currentPassword': password});
          _recuperacion = Recuperacion(
            tiene: true,
            desde: DateTime.now().toIso8601String(),
          );
          notifyListeners();
          return j['recovery'] as String;
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Entrar con el codigo de recuperacion y poner contraseña nueva. Devuelve el
  /// codigo NUEVO: el que se uso ya no vale.
  Future<Result<String>> recuperar({
    required String usuario,
    required String codigo,
    required String password,
  }) =>
      Result.guard<String>(
        () async {
          _api.baseUrl = _store.url;
          final j = await _api.post('/api/auth?recover=1', {
            'name': usuario.trim(),
            'code': codigo.trim(),
            'password': password,
          });
          _api.token = j['token'] as String;
          await _store.writeToken(_api.token!);
          _me = Me.fromJson(
            j['user'] as Map<String, dynamic>,
            account: j['account'] as Map<String, dynamic>?,
          );
          _recuperacion = const Recuperacion(tiene: true);
          notifyListeners();
          return (j['recovery'] as String?) ?? '';
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /* ------------------------------------------------------------- usuarios -- */

  /// Quien tiene acceso a la cuenta. Solo se lo responde el servidor al dueño.
  Future<Result<List<Usuario>>> usuarios() => Result.guard<List<Usuario>>(
        () async {
          final j = await _api.get('/api/auth');
          return ((j['users'] as List?) ?? const [])
              .map((u) => Usuario.fromJson(u as Map<String, dynamic>))
              .toList();
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  Future<Result<void>> crearUsuario(Map<String, Object?> body) => Result.guard<void>(
        () async => await _api.post('/api/auth?new=1', body),
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  Future<Result<void>> editarUsuario(int id, Map<String, Object?> body) =>
      Result.guard<void>(
        () async => await _api.put('/api/auth?id=$id', body),
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Pide el codigo de confirmacion para una cuenta nueva.
  ///
  /// Todavia no se crea nada: el servidor valida los datos, manda un codigo de
  /// seis digitos al correo y espera. Devuelve true si hay que pedir el codigo,
  /// y false si el servidor no tiene correo configurado y ya creo la cuenta
  /// (entonces la sesion queda abierta y `codigoRecuperacion` trae el suyo).
  ///
  /// El servidor puede tener el registro cerrado (ALLOW_SIGNUP=0), y entonces
  /// responde que no. Es una respuesta valida, no un fallo de la app.
  Future<Result<bool>> pedirCodigo({
    required String usuario,
    required String password,
    required String nombre,
    required String correo,
  }) =>
      Result.guard<bool>(
        () async {
          _api.baseUrl = _store.url;
          final j = await _api.post('/api/auth?signup=1', {
            'name': usuario.trim(),
            'password': password,
            'fullName': nombre.trim(),
            'email': correo.trim(),
          });
          // `pending` = el codigo va en camino. Si no viene, el servidor creo la
          // cuenta de una porque no tiene correo configurado.
          if (j['pending'] == true) return true;
          _entrar(j);
          return false;
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Confirma el codigo y crea la cuenta. Devuelve el codigo de recuperacion,
  /// que se enseña UNA sola vez: el dueño es el unico al que nadie mas puede
  /// rescatar.
  Future<Result<String>> confirmarCodigo({
    required String correo,
    required String codigo,
  }) =>
      Result.guard<String>(
        () async {
          _api.baseUrl = _store.url;
          final j = await _api.post('/api/auth?verify=1', {
            'email': correo.trim(),
            'code': codigo.trim(),
          });
          return _entrar(j);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// El codigo de recuperacion de la cuenta que se acaba de crear sin pasar por
  /// el correo. Vacio si no hubo ninguna.
  String get codigoRecuperacion => _codigoNuevo;
  String _codigoNuevo = '';

  /// Guarda la sesion que devuelve el servidor y entrega el codigo de
  /// recuperacion. Lo comparten los dos caminos que abren sesion creando cuenta.
  String _entrar(Map<String, dynamic> j) {
    _api.token = j['token'] as String;
    _store.writeToken(_api.token!);
    _me = Me.fromJson(
      j['user'] as Map<String, dynamic>,
      account: j['account'] as Map<String, dynamic>?,
    );
    _recuperacion = const Recuperacion(tiene: true);
    _codigoNuevo = (j['recovery'] as String?) ?? '';
    notifyListeners();
    return _codigoNuevo;
  }

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
