// =============================================================================
//  Result: salió bien, o salió mal con un mensaje que se puede mostrar.
//
//  Los servicios lanzan excepciones (es lo natural en `http`), pero una
//  excepcion que cruza tres capas termina en un `try/catch` dentro de un
//  widget, y eso es como se pierde el control de los errores. Los repositorios
//  las atrapan y devuelven esto.
//
//  Asi la UI nunca hace `try/catch`: pregunta si salio bien.
//
//    switch (await repo.summary()) {
//      Ok(:final value)   => _mostrar(value),
//      Err(:final message) => _error(message),
//    }
// =============================================================================

sealed class Result<T> {
  const Result();

  /// Envuelve una llamada que puede lanzar. `alMensaje` traduce la excepcion a
  /// algo que una persona pueda leer.
  static Future<Result<T>> guard<T>(
    Future<T> Function() accion, {
    required String Function(Object error) alMensaje,
    bool Function(Object error)? esSesionVencida,
  }) async {
    try {
      return Ok(await accion());
    } catch (e) {
      return Err(alMensaje(e), sessionExpired: esSesionVencida?.call(e) ?? false);
    }
  }

  bool get isOk => this is Ok<T>;

  /// El valor si salio bien; null si no. Para cuando no importa el motivo.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.message, {this.sessionExpired = false});

  /// Ya escrito para mostrarse tal cual: viene de la API, que responde en
  /// español ("Usuario o contraseña incorrectos").
  final String message;

  /// La sesion caduco: no es un error que reintentar, hay que volver a entrar.
  final bool sessionExpired;
}
