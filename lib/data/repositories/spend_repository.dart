// =============================================================================
//  Los gastos del hogar: categorías, gastos e ingresos.
//
//  Todo cuelga de una sola llamada (`/api/expenses`), que es lo que necesita la
//  pantalla para pintarse entera: las categorías, los gastos del último año y
//  los ingresos completos. Después de cualquier escritura se vuelve a pedir:
//  cambiar un gasto mueve el total del mes, el % del presupuesto, la capacidad
//  de pago y el gráfico, así que no vale la pena parchear la copia local.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../domain/models/spend.dart';
import '../../utils/result.dart';
import '../services/api_client.dart';

class SpendRepository extends ChangeNotifier {
  SpendRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  SpendData? _data;
  SpendData? get data => _data;

  Future<Result<SpendData>> load({bool force = false}) async {
    if (_data != null && !force) return Ok(_data!);
    return Result.guard<SpendData>(
      () async {
        // 13 meses: el año de gráficos más el mes en curso.
        _data = SpendData.fromJson(await _api.get('/api/expenses?months=13'));
        notifyListeners();
        return _data!;
      },
      alMensaje: _mensaje,
      esSesionVencida: _vencida,
    );
  }

  /* ---------------------------------------------------------------- gastos -- */

  Future<Result<void>> addExpense(Map<String, Object?> body) =>
      _escribir(() => _api.post('/api/expenses', body));

  Future<Result<void>> updateExpense(int id, Map<String, Object?> body) =>
      _escribir(() => _api.put('/api/expenses?id=$id', body));

  Future<Result<void>> deleteExpense(int id) =>
      _escribir(() => _api.delete('/api/expenses?id=$id'));

  /// La captura de un gasto (data URI JPEG). No se guarda en memoria: son
  /// cientos de KB y se ven una vez.
  Future<Result<String>> receipt(int id) => Result.guard<String>(
        () async => (await _api.get('/api/expenses?id=$id&receipt=1'))['image'] as String,
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /* ----------------------------------------------------------- categorias -- */

  Future<Result<void>> addCategory(Map<String, Object?> body) =>
      _escribir(() => _api.post('/api/categories', body));

  Future<Result<void>> updateCategory(int id, Map<String, Object?> body) =>
      _escribir(() => _api.put('/api/categories?id=$id', body));

  /// Archiva la categoría. Con `conTodo` la borra de verdad, y entonces sus
  /// gastos quedan "sin categoría": no se borran, porque la plata se gastó.
  Future<Result<void>> deleteCategory(int id, {bool conTodo = false}) => _escribir(
        () => _api.delete('/api/categories?id=$id${conTodo ? '&hard=1' : ''}'),
      );

  /// Crea las categorías típicas de una casa. Solo funciona si la cuenta no
  /// tiene ninguna todavía.
  Future<Result<void>> seedCategories() =>
      _escribir(() => _api.post('/api/categories?seed=1'));

  /* -------------------------------------------------------------- ingresos -- */

  Future<Result<void>> addIncome(Map<String, Object?> body) =>
      _escribir(() => _api.post('/api/incomes', body));

  Future<Result<void>> updateIncome(int id, Map<String, Object?> body) =>
      _escribir(() => _api.put('/api/incomes?id=$id', body));

  Future<Result<void>> deleteIncome(int id) =>
      _escribir(() => _api.delete('/api/incomes?id=$id'));

  /* ------------------------------------------------------------------------ */

  /// Escribe y vuelve a pedir todo. Es una llamada de más a cambio de no tener
  /// que recalcular a mano cuatro cosas que dependen del mismo dato.
  Future<Result<void>> _escribir(Future<void> Function() accion) => Result.guard<void>(
        () async {
          await accion();
          await load(force: true);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  void clear() {
    _data = null;
    notifyListeners();
  }

  static String _mensaje(Object e) =>
      e is ApiException ? e.message : 'Algo salió mal. Intenta de nuevo.';

  static bool _vencida(Object e) => e is ApiException && e.sessionExpired;
}
