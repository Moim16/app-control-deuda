// =============================================================================
//  El vehículo: sus tareas de mantenimiento y sus servicios.
//
//  Todo cuelga de una sola llamada (`/api/vehicles`). Después de escribir se
//  vuelve a pedir todo: un servicio nuevo mueve el kilometraje del vehículo, el
//  "cuándo toca" de varias tareas a la vez y los totales gastados, así que
//  parchear la copia local sería reimplementar el servidor.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../domain/models/vehicle.dart';
import '../../utils/result.dart';
import '../services/api_client.dart';

class VehicleRepository extends ChangeNotifier {
  VehicleRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  VehicleData? _data;
  VehicleData? get data => _data;

  Future<Result<VehicleData>> load({bool force = false}) async {
    if (_data != null && !force) return Ok(_data!);
    return Result.guard<VehicleData>(
      () async {
        // `all=1` trae también los archivados: se tienen que poder mirar.
        _data = VehicleData.fromJson(await _api.get('/api/vehicles?all=1'));
        notifyListeners();
        return _data!;
      },
      alMensaje: _mensaje,
      esSesionVencida: _vencida,
    );
  }

  /* ------------------------------------------------------------- vehiculos -- */

  /// Crea el vehículo y, con él, las tareas típicas de ese tipo (aceite,
  /// llantas, seguro…): empezar con una lista en blanco no le sirve a nadie.
  Future<Result<void>> addVehicle(Map<String, Object?> body) =>
      _escribir(() => _api.post('/api/vehicles', body));

  Future<Result<void>> updateVehicle(int id, Map<String, Object?> body) =>
      _escribir(() => _api.put('/api/vehicles?id=$id', body));

  /// Archiva el vehículo; con `conTodo` lo borra con su historial.
  Future<Result<void>> deleteVehicle(int id, {bool conTodo = false}) => _escribir(
        () => _api.delete('/api/vehicles?id=$id${conTodo ? '&hard=1' : ''}'),
      );

  /* ----------------------------------------------------------------- tareas -- */

  Future<Result<void>> addTask(Map<String, Object?> body) =>
      _escribir(() => _api.post('/api/vehicles?task=1', body));

  Future<Result<void>> updateTask(int id, Map<String, Object?> body) =>
      _escribir(() => _api.put('/api/vehicles?task=$id', body));

  /// Archiva la tarea; con `conTodo` la borra, y entonces sus servicios quedan
  /// sin tarea: no se borran, porque el trabajo se hizo igual.
  Future<Result<void>> deleteTask(int id, {bool conTodo = false}) => _escribir(
        () => _api.delete('/api/vehicles?task=$id${conTodo ? '&hard=1' : ''}'),
      );

  /* -------------------------------------------------------------- servicios -- */

  Future<Result<void>> addService(Map<String, Object?> body) =>
      _escribir(() => _api.post('/api/vehicles?service=1', body));

  Future<Result<void>> updateService(int id, Map<String, Object?> body) =>
      _escribir(() => _api.put('/api/vehicles?service=$id', body));

  Future<Result<void>> deleteService(int id) =>
      _escribir(() => _api.delete('/api/vehicles?service=$id'));

  /// La factura de un servicio (data URI JPEG).
  Future<Result<String>> receipt(int serviceId) => Result.guard<String>(
        () async =>
            (await _api.get('/api/vehicles?id=$serviceId&receipt=1'))['image'] as String,
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /* ------------------------------------------------------------------------ */

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
