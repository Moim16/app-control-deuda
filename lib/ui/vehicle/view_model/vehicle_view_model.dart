// =============================================================================
//  El estado de la pantalla del vehículo.
//
//  Lo que uno viene a saber al abrir esto es qué le toca ya, así que eso se
//  calcula primero y va arriba. El historial es consulta.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/dia.dart';
import '../../../domain/mantenimiento.dart';
import '../../../domain/models/vehicle.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class VehicleViewModel extends ChangeNotifier {
  VehicleViewModel({required VehicleRepository vehiculos}) : _repo = vehiculos {
    load = Command0<VehicleData>(_load);
    refresh = Command0<VehicleData>(() => _load(force: true));
    _repo.addListener(notifyListeners);
  }

  final VehicleRepository _repo;

  late final Command0<VehicleData> load;
  late final Command0<VehicleData> refresh;

  VehicleData? get data => _repo.data;

  String get hoy => data?.today ?? diaDe(DateTime.now());

  int? _vehId;

  /// El vehículo que se está mirando: el pedido si existe, si no el primero
  /// activo, si no el primero que haya.
  Vehicle? get vehiculo {
    final d = data;
    if (d == null || d.vehicles.isEmpty) return null;
    final pedido = d.vehiculo(_vehId);
    if (pedido != null) return pedido;
    return d.activos.isNotEmpty ? d.activos.first : d.vehicles.first;
  }

  List<Vehicle> get vehiculos => data?.vehicles ?? const [];

  bool get vacio => data?.vehicles.isEmpty ?? true;

  /* --------------------------------------------------------- mantenimiento -- */

  /// Las tareas del vehículo, lo más urgente primero.
  List<EstadoTarea> get tareas {
    final v = vehiculo;
    final d = data;
    if (v == null || d == null) return const [];
    return tareasOrdenadas(
      vehiculo: v,
      tareas: d.tareasDe(v.id),
      servicios: d.serviciosDe(v.id),
      hoy: hoy,
    );
  }

  /// Lo que ya toca. Es lo único de la pantalla sobre lo que hay que hacer algo.
  List<EstadoTarea> get pendientes => tareas.where((t) => t.toca).toList();

  List<Service> get mantenimientos {
    final v = vehiculo;
    return v == null ? const [] : (data?.mantenimientosDe(v.id) ?? const []);
  }

  List<Service> get accesorios {
    final v = vehiculo;
    return v == null ? const [] : (data?.accesoriosDe(v.id) ?? const []);
  }

  /// Lo invertido en accesorios, por moneda. Es lo que uno quiere saber de
  /// ellos: no cuándo toca, sino cuánto lleva puesto.
  Map<String, double> get gastadoEnAccesorios {
    final out = <String, double>{};
    for (final a in accesorios) {
      if (a.cost == null) continue;
      out[a.currency] = (out[a.currency] ?? 0) + a.cost!;
    }
    return out;
  }

  /// Las monedas en las que hay algo gastado, córdobas primero.
  List<String> get monedasGastadas {
    final v = vehiculo;
    if (v == null) return const [];
    final out = <String>[];
    for (final c in const ['NIO', 'USD']) {
      if ((v.spent[c] ?? 0) > 0) out.add(c);
    }
    return out;
  }

  /// Lo gastado en el vehiculo por mes, para el grafico. En la moneda con mas
  /// gasto: mezclar cordobas y dolares en una barra seria inventar un total.
  ({List<String> meses, List<double> gastado, String moneda}) get porMes {
    final v = vehiculo;
    final d = data;
    final cur = monedasGastadas.isEmpty ? 'NIO' : monedasGastadas.first;
    if (v == null || d == null) return (meses: const [], gastado: const [], moneda: cur);

    final meses = ultimosMeses(12, hoy: hoy);
    final servicios = d.serviciosDe(v.id).where((s) => s.currency == cur).toList();
    return (
      meses: meses,
      gastado: [
        for (final m in meses)
          servicios
              .where((s) => mesDe(s.day) == m)
              .fold<double>(0, (a, s) => a + (s.cost ?? 0)),
      ],
      moneda: cur,
    );
  }

  void mostrar(int vehicleId) {
    if (_vehId == vehicleId) return;
    _vehId = vehicleId;
    notifyListeners();
  }

  Future<Result<VehicleData>> _load({bool force = false}) => _repo.load(force: force);

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    load.dispose();
    refresh.dispose();
    super.dispose();
  }
}
