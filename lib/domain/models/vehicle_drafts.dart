// Los formularios del vehículo: el vehículo, una tarea de mantenimiento y un
// servicio.

import '../dia.dart';
import 'spend_drafts.dart' show montoDe;
import 'vehicle.dart';

/// El cambio de la factura de un servicio: igual, quitada o nueva.
sealed class CambioFactura {
  const CambioFactura();
}

class FacturaIgual extends CambioFactura {
  const FacturaIgual();
}

class FacturaQuitada extends CambioFactura {
  const FacturaQuitada();
}

class FacturaNueva extends CambioFactura {
  const FacturaNueva(this.dataUri);
  final String dataUri;
}

/* ============================================================== vehículo == */

class VehicleDraft {
  const VehicleDraft({
    this.name = '',
    this.kind = VehicleKind.moto,
    this.plate = '',
    this.year = '',
    this.note = '',
    this.active = true,
  });

  final String name;
  final VehicleKind kind;
  final String plate;
  final String year;
  final String note;
  final bool active;

  VehicleDraft copyWith({
    String? name,
    VehicleKind? kind,
    String? plate,
    String? year,
    String? note,
    bool? active,
  }) =>
      VehicleDraft(
        name: name ?? this.name,
        kind: kind ?? this.kind,
        plate: plate ?? this.plate,
        year: year ?? this.year,
        note: note ?? this.note,
        active: active ?? this.active,
      );

  /// El año en número; `-1` si lo escrito no sirve, para poder distinguirlo de
  /// "vacío".
  int? get ano {
    final s = year.trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    return (n == null || n < 1900 || n > 2100) ? -1 : n;
  }

  String? get problema {
    if (name.trim().isEmpty) return 'Ponle un nombre al vehículo.';
    if (name.trim().length > 60) return 'El nombre es muy largo.';
    if (ano == -1) return 'El año no es válido.';
    if (plate.trim().length > 20) return 'Esa placa es muy larga.';
    if (note.trim().length > 300) return 'La nota es muy larga.';
    return null;
  }

  bool get esValido => problema == null;

  Map<String, Object?> aJson({required bool nuevo}) => {
        'name': name.trim(),
        'kind': kind.wire,
        'plate': plate.trim(),
        'year': year.trim(),
        'note': note.trim(),
        if (!nuevo) 'active': active,
      };

  factory VehicleDraft.de(Vehicle v) => VehicleDraft(
        name: v.name,
        kind: v.kind,
        plate: v.plate ?? '',
        year: v.year?.toString() ?? '',
        note: v.note ?? '',
        active: v.active,
      );
}

/* ================================================================= tarea == */

class TaskDraft {
  const TaskDraft({
    required this.vehicleId,
    this.name = '',
    this.everyKm = '',
    this.everyMonths = '',
    this.note = '',
    this.active = true,
  });

  final int vehicleId;
  final String name;

  /// Los dos intervalos son opcionales, y se pueden poner los dos: entonces
  /// manda el que llegue primero.
  final String everyKm;
  final String everyMonths;

  final String note;
  final bool active;

  TaskDraft copyWith({
    String? name,
    String? everyKm,
    String? everyMonths,
    String? note,
    bool? active,
  }) =>
      TaskDraft(
        vehicleId: vehicleId,
        name: name ?? this.name,
        everyKm: everyKm ?? this.everyKm,
        everyMonths: everyMonths ?? this.everyMonths,
        note: note ?? this.note,
        active: active ?? this.active,
      );

  static int? _entero(String s) {
    final v = s.replaceAll(',', '').trim();
    if (v.isEmpty) return null;
    final n = int.tryParse(v);
    return (n == null || n <= 0) ? -1 : n;
  }

  int? get km => _entero(everyKm);
  int? get meses => _entero(everyMonths);

  String? get problema {
    if (name.trim().isEmpty) return 'Ponle un nombre a la tarea.';
    if (name.trim().length > 60) return 'El nombre es muy largo.';
    if (km == -1) return 'Los kilómetros deben ser un número entero.';
    if (meses == -1) return 'Los meses deben ser un número entero.';
    if (note.trim().length > 300) return 'La nota es muy larga.';
    return null;
  }

  bool get esValido => problema == null;

  /// Sin ningún intervalo la tarea existe igual, pero no se puede decir cuándo
  /// toca. La pantalla lo avisa en vez de impedirlo.
  bool get sinIntervalo => km == null && meses == null;

  Map<String, Object?> aJson({required bool nueva}) => {
        if (nueva) 'vehicleId': vehicleId,
        'name': name.trim(),
        'everyKm': everyKm.trim(),
        'everyMonths': everyMonths.trim(),
        'note': note.trim(),
        if (!nueva) 'active': active,
      };

  factory TaskDraft.de(VehicleTask t) => TaskDraft(
        vehicleId: t.vehicleId,
        name: t.name,
        everyKm: t.everyKm?.toString() ?? '',
        everyMonths: t.everyMonths?.toString() ?? '',
        note: t.note ?? '',
        active: t.active,
      );
}

/* ============================================================== servicio == */

class ServiceDraft {
  const ServiceDraft({
    required this.vehicleId,
    required this.day,
    this.kind = ServiceKind.service,
    this.taskIds = const [],
    this.odometer = '',
    this.title = '',
    this.cost = '',
    this.currency = 'NIO',
    this.place = '',
    this.note = '',
    this.categoryId,
    this.receipt = const FacturaIgual(),
  });

  final int vehicleId;
  final String day;
  final ServiceKind kind;

  /// Las tareas que cubre. Un accesorio no cubre ninguna: no es algo que haya
  /// que repetir.
  final List<int> taskIds;

  final String odometer;
  final String title;

  /// Opcional: un servicio en garantía no costó nada.
  final String cost;

  final String currency;
  final String place;
  final String note;

  /// Si se pone, el servicio se anota TAMBIÉN como gasto del hogar en esa
  /// categoría, y queda enlazado: la plata figura una sola vez.
  final int? categoryId;

  final CambioFactura receipt;

  ServiceDraft copyWith({
    String? day,
    ServiceKind? kind,
    List<int>? taskIds,
    String? odometer,
    String? title,
    String? cost,
    String? currency,
    String? place,
    String? note,
    int? categoryId,
    bool sinCategoria = false,
    CambioFactura? receipt,
  }) =>
      ServiceDraft(
        vehicleId: vehicleId,
        day: day ?? this.day,
        kind: kind ?? this.kind,
        // Un accesorio nunca lleva tareas, aunque se hubieran marcado antes de
        // cambiar el tipo.
        taskIds: (kind ?? this.kind) == ServiceKind.accessory
            ? const []
            : (taskIds ?? this.taskIds),
        odometer: odometer ?? this.odometer,
        title: title ?? this.title,
        cost: cost ?? this.cost,
        currency: currency ?? this.currency,
        place: place ?? this.place,
        note: note ?? this.note,
        categoryId: sinCategoria ? null : (categoryId ?? this.categoryId),
        receipt: receipt ?? this.receipt,
      );

  bool get esAccesorio => kind == ServiceKind.accessory;

  /// El costo; null si está vacío (válido), `double.nan` si no sirve.
  double? get monto {
    final s = cost.trim();
    if (s.isEmpty) return null;
    return montoDe(s) ?? double.nan;
  }

  /// Los km; null si vacío, -1 si no sirve.
  int? get km {
    final s = odometer.replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    return (n == null || n < 0) ? -1 : n;
  }

  ServiceDraft alternarTarea(int taskId) => copyWith(
        taskIds: taskIds.contains(taskId)
            ? (taskIds.where((x) => x != taskId).toList())
            : [...taskIds, taskId],
      );

  String? problema({required String hoy}) {
    if (title.trim().isEmpty) return 'Escribe qué se le hizo.';
    if (title.trim().length > 120) return 'Eso es muy largo.';
    if (!diaValido(day)) return 'La fecha no es válida.';
    if (day.compareTo(masDias(hoy, 1)) > 0) return 'Esa fecha todavía no llega.';
    final c = monto;
    if (c != null && c.isNaN) return 'El costo no es válido.';
    if (km == -1) return 'El kilometraje debe ser un número entero.';
    if (place.trim().length > 120) return 'Ese nombre es muy largo.';
    if (note.trim().length > 500) return 'La nota es muy larga.';
    return null;
  }

  bool esValido({required String hoy}) => problema(hoy: hoy) == null;

  Map<String, Object?> aJson({required bool nuevo}) => {
        if (nuevo) 'vehicleId': vehicleId,
        'kind': kind.wire,
        'taskIds': taskIds,
        'day': day,
        'odometer': odometer.replaceAll(',', '').trim(),
        'title': title.trim(),
        'cost': cost.trim(),
        'currency': currency,
        'place': place.trim(),
        'note': note.trim(),
        // Solo al crear. El PUT del servidor no acepta `categoryId`: si el
        // servicio ya tiene un gasto enlazado, lo mueve solo, y mandar la
        // categoría otra vez crearía un gasto duplicado.
        if (nuevo) 'categoryId': categoryId ?? '',
        ...switch (receipt) {
          FacturaIgual() => const <String, Object?>{},
          FacturaQuitada() => const {'receipt': null},
          FacturaNueva(:final dataUri) => {'receipt': dataUri},
        },
      };

  factory ServiceDraft.de(Service s) => ServiceDraft(
        vehicleId: s.vehicleId,
        day: s.day,
        kind: s.kind,
        taskIds: s.taskIds,
        odometer: s.odometer?.toString() ?? '',
        title: s.title,
        cost: s.cost == null
            ? ''
            : (s.cost! == s.cost!.roundToDouble()
                ? s.cost!.toStringAsFixed(0)
                : s.cost!.toStringAsFixed(2)),
        currency: s.currency,
        place: s.place ?? '',
        note: s.note ?? '',
        // La categoría del gasto enlazado no viene en el servicio: al editar no
        // se puede proponer, y volver a marcarla crearía un gasto duplicado.
      );
}
