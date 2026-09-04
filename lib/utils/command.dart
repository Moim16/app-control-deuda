// =============================================================================
//  Command: una accion que llama a la red, con su estado.
//
//  Un boton que dispara una peticion necesita siempre lo mismo: saber si esta
//  corriendo (para deshabilitarse y mostrar la ruedita), guardar el error si
//  fallo, y no dispararse dos veces si le dan doble toque.
//
//  Sin esto, cada pantalla acaba con su propio `bool _cargando` y su
//  `String? _error`, repetidos y con los mismos olvidos. Aqui esta una vez.
//
//  Es el patron que recomienda la guia de arquitectura de Flutter.
//
//  OJO CON ESTO: un Command es su PROPIO `ChangeNotifier`, asi que avisa a sus
//  oyentes y no a los del ViewModel que lo contiene. Una pantalla que hace
//  `context.watch<MiViewModel>()` y lee `vm.miComando.errorMessage` NO se
//  repinta cuando el comando falla, y el error no aparece nunca.
//
//  Por eso todo ViewModel con comandos tiene que reenviar sus avisos:
//
//      miComando = Command0<X>(_hacer)..addListener(notifyListeners);
//
//  Costo un login fallido que no decia nada: la pantalla se quedaba igual, sin
//  error y sin explicacion.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'result.dart';

/// Una accion sin argumentos.
class Command0<T> extends ChangeNotifier {
  Command0(this._accion);
  final Future<Result<T>> Function() _accion;

  bool _running = false;
  Err<T>? _error;

  bool get running => _running;
  Err<T>? get error => _error;
  String? get errorMessage => _error?.message;

  Future<void> run() async {
    // El doble toque no dispara dos peticiones.
    if (_running) return;
    _running = true;
    _error = null;
    notifyListeners();
    final r = await _accion();
    if (r case Err<T> e) _error = e;
    _running = false;
    notifyListeners();
  }

  /// Borra el error para que el mensaje no se quede pegado en pantalla cuando
  /// la persona ya corrigio lo que estaba mal.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}

/// Una accion con un argumento (entrar con usuario y clave, guardar un abono).
class Command1<T, A> extends ChangeNotifier {
  Command1(this._accion);
  final Future<Result<T>> Function(A arg) _accion;

  bool _running = false;
  Err<T>? _error;

  bool get running => _running;
  Err<T>? get error => _error;
  String? get errorMessage => _error?.message;

  Future<void> run(A arg) async {
    if (_running) return;
    _running = true;
    _error = null;
    notifyListeners();
    final r = await _accion(arg);
    if (r case Err<T> e) _error = e;
    _running = false;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
