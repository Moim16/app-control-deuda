// El vehículo, sus tareas de mantenimiento y sus servicios.
//
// Todo es del DUEÑO: la API exige admin incluso para leer.

enum VehicleKind {
  moto,
  car,
  other;

  static VehicleKind parse(String? v) => switch (v) {
        'car' => VehicleKind.car,
        'other' => VehicleKind.other,
        _ => VehicleKind.moto,
      };

  String get wire => switch (this) {
        VehicleKind.moto => 'moto',
        VehicleKind.car => 'car',
        VehicleKind.other => 'other',
      };

  String get label => switch (this) {
        VehicleKind.moto => 'Moto',
        VehicleKind.car => 'Carro',
        VehicleKind.other => 'Otro',
      };
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.kind,
    this.plate,
    this.year,
    this.note,
    required this.active,
    this.odometer,
    required this.services,
    this.lastDay,
    required this.spent,
  });

  final int id;
  final String name;
  final VehicleKind kind;
  final String? plate;
  final int? year;
  final String? note;
  final bool active;

  /// El kilometraje: el más alto que se haya anotado en un servicio. No se
  /// pregunta aparte porque se anota cada vez que se lleva al taller.
  final int? odometer;

  final int services;
  final String? lastDay;

  /// Lo gastado, por moneda. Aquí tampoco se suman entre sí.
  final Map<String, double> spent;

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as int,
        name: j['name'] as String,
        kind: VehicleKind.parse(j['kind'] as String?),
        plate: j['plate'] as String?,
        year: (j['year'] as num?)?.toInt(),
        note: j['note'] as String?,
        active: (j['active'] as int? ?? 1) == 1,
        odometer: (j['odometer'] as num?)?.toInt(),
        services: (j['services'] as int?) ?? 0,
        lastDay: j['lastDay'] as String?,
        spent: {
          'NIO': ((j['spentNIO'] as num?) ?? 0).toDouble(),
          'USD': ((j['spentUSD'] as num?) ?? 0).toDouble(),
        },
      );
}

/// Una tarea de mantenimiento: qué hay que hacerle y cada cuánto.
class VehicleTask {
  const VehicleTask({
    required this.id,
    required this.vehicleId,
    required this.name,
    this.everyKm,
    this.everyMonths,
    this.note,
    required this.active,
  });

  final int id;
  final int vehicleId;
  final String name;

  /// Cada cuántos km, cada cuántos meses, o las dos cosas: manda la que llegue
  /// primero. Una tarea puede no tener intervalo (algo que se hace y ya).
  final int? everyKm;
  final int? everyMonths;

  final String? note;
  final bool active;

  factory VehicleTask.fromJson(Map<String, dynamic> j) => VehicleTask(
        id: j['id'] as int,
        vehicleId: j['vehicleId'] as int,
        name: j['name'] as String,
        everyKm: (j['everyKm'] as num?)?.toInt(),
        everyMonths: (j['everyMonths'] as num?)?.toInt(),
        note: j['note'] as String?,
        active: (j['active'] as int? ?? 1) == 1,
      );
}

enum ServiceKind {
  /// Mantenimiento o reparación: algo que se repite.
  service,

  /// Un accesorio: antivuelco, pescantes, llantas nuevas. No se repite, es una
  /// mejora, y lo que uno quiere saber es cuánto lleva invertido.
  accessory;

  static ServiceKind parse(String? v) =>
      v == 'accessory' ? ServiceKind.accessory : ServiceKind.service;

  String get wire => this == ServiceKind.accessory ? 'accessory' : 'service';

  String get label => this == ServiceKind.accessory ? 'Accesorio' : 'Mantenimiento';
}

/// Una visita al taller o un accesorio que se le puso.
class Service {
  const Service({
    required this.id,
    required this.vehicleId,
    required this.kind,
    required this.taskIds,
    this.expenseId,
    required this.day,
    this.odometer,
    required this.title,
    this.cost,
    required this.currency,
    this.place,
    this.note,
    required this.hasReceipt,
    this.createdBy,
    this.createdAt,
  });

  final int id;
  final int vehicleId;
  final ServiceKind kind;

  /// Las tareas que cubrió. UN registro con UN monto puede cubrir varias a la
  /// vez, que es como se hace en la casa comercial: se paga un solo monto por
  /// aceite, filtro y cadena.
  final List<int> taskIds;

  /// El gasto del hogar que se creó junto con el servicio, si se pidió. Así la
  /// plata figura una sola vez y borrar el servicio se lleva el gasto.
  final int? expenseId;

  final String day;

  /// Los km al momento del servicio.
  final int? odometer;

  final String title;

  /// Puede no haber costado nada (una garantía).
  final double? cost;

  final String currency;
  final String? place;
  final String? note;
  final bool hasReceipt;
  final String? createdBy;
  final String? createdAt;

  bool get esAccesorio => kind == ServiceKind.accessory;

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: j['id'] as int,
        vehicleId: j['vehicleId'] as int,
        kind: ServiceKind.parse(j['kind'] as String?),
        taskIds: ((j['taskIds'] as List?) ?? const []).map((x) => x as int).toList(),
        expenseId: j['expenseId'] as int?,
        day: j['day'] as String,
        odometer: (j['odometer'] as num?)?.toInt(),
        title: j['title'] as String,
        cost: (j['cost'] as num?)?.toDouble(),
        currency: (j['currency'] as String?) ?? 'NIO',
        place: j['place'] as String?,
        note: j['note'] as String?,
        hasReceipt: (j['hasReceipt'] as bool?) ?? false,
        createdBy: j['createdBy'] as String?,
        createdAt: j['createdAt'] as String?,
      );
}

/// Todo lo que devuelve `/api/vehicles` en una llamada.
class VehicleData {
  const VehicleData({
    required this.today,
    required this.vehicles,
    required this.tasks,
    required this.services,
  });

  final String today;
  final List<Vehicle> vehicles;
  final List<VehicleTask> tasks;
  final List<Service> services;

  List<Vehicle> get activos => vehicles.where((v) => v.active).toList();

  List<VehicleTask> tareasDe(int vehicleId) =>
      tasks.where((t) => t.vehicleId == vehicleId && t.active).toList();

  List<Service> serviciosDe(int vehicleId) =>
      services.where((s) => s.vehicleId == vehicleId).toList();

  /// Los mantenimientos y las reparaciones.
  List<Service> mantenimientosDe(int vehicleId) =>
      serviciosDe(vehicleId).where((s) => !s.esAccesorio).toList();

  List<Service> accesoriosDe(int vehicleId) =>
      serviciosDe(vehicleId).where((s) => s.esAccesorio).toList();

  Vehicle? vehiculo(int? id) {
    if (id == null) return null;
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  VehicleTask? tarea(int id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  factory VehicleData.fromJson(Map<String, dynamic> j) => VehicleData(
        today: j['today'] as String,
        vehicles: (j['vehicles'] as List)
            .map((v) => Vehicle.fromJson(v as Map<String, dynamic>))
            .toList(),
        tasks: (j['tasks'] as List)
            .map((t) => VehicleTask.fromJson(t as Map<String, dynamic>))
            .toList(),
        services: (j['services'] as List)
            .map((s) => Service.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
