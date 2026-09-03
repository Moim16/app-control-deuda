// =============================================================================
//  Cuándo toca cada mantenimiento.
//
//  Una tarea puede tocar por kilómetros, por tiempo, o por las dos cosas — y
//  entonces manda la que llegue primero. Lo importante: para saber cuándo se
//  hizo por última vez NO se mira un campo del servicio, sino la lista de
//  tareas que ese servicio cubrió: en la casa comercial se paga un solo monto
//  por aceite, filtro y cadena, y eso es UN registro que cubre tres tareas.
//
//  Va en `domain` para poder probar la aritmética sin pantalla: "faltan 300 km"
//  y "pasado por 300 km" son la misma cuenta con el signo cambiado, y eso es
//  justo lo que se equivoca solo.
// =============================================================================

import 'dia.dart';
import 'models/vehicle.dart';

/// Por qué toca una tarea.
enum PorQue {
  /// Nunca se le ha hecho: toca, y es lo más urgente que hay.
  nunca,

  /// Se pasó el kilometraje.
  km,

  /// Se pasó la fecha.
  fecha,

  /// Todavía no toca.
  todavia,
}

/// El estado de una tarea de mantenimiento.
class EstadoTarea {
  const EstadoTarea({
    required this.tarea,
    this.ultimo,
    this.kmFaltan,
    this.diasFaltan,
    required this.porQue,
  });

  final VehicleTask tarea;

  /// El último servicio que la cubrió, o null si nunca se le ha hecho.
  final Service? ultimo;

  /// Km que faltan; negativo si ya se pasó. null cuando la tarea no va por km,
  /// o cuando no hay kilometraje con el que comparar.
  final int? kmFaltan;

  /// Días que faltan; negativo si ya se pasó.
  final int? diasFaltan;

  final PorQue porQue;

  bool get toca => porQue != PorQue.todavia;
  bool get nunca => porQue == PorQue.nunca;

  /// Qué tan urgente es, para ordenar y para el color. Menor = más urgente.
  ///
  /// Se mide en FRACCIÓN del intervalo, no en km ni en días: 500 km de 3,000
  /// aprietan más que 500 de 15,000, y así las dos escalas se comparan entre
  /// sí. La que esté peor manda.
  double get urgencia {
    if (nunca) return -1;
    final porKm = (kmFaltan != null && (tarea.everyKm ?? 0) > 0)
        ? kmFaltan! / tarea.everyKm!
        : 1.0;
    final porDia = (diasFaltan != null && (tarea.everyMonths ?? 0) > 0)
        ? diasFaltan! / (tarea.everyMonths! * 30.44)
        : 1.0;
    return porKm < porDia ? porKm : porDia;
  }
}

/// El estado de una tarea, con los servicios de su vehículo.
EstadoTarea estadoDeTarea({
  required VehicleTask tarea,
  required Vehicle vehiculo,
  required List<Service> servicios,
  required String hoy,
}) {
  // Los servicios que cubrieron ESTA tarea, del más viejo al más nuevo.
  final hechos = servicios.where((s) => s.taskIds.contains(tarea.id)).toList()
    ..sort((a, b) {
      final porDia = a.day.compareTo(b.day);
      return porDia != 0 ? porDia : a.id.compareTo(b.id);
    });

  if (hechos.isEmpty) {
    return EstadoTarea(tarea: tarea, porQue: PorQue.nunca);
  }

  final ultimo = hechos.last;

  int? kmFaltan;
  // Hacen falta las dos cifras: los km del servicio y los de ahora. Sin una de
  // las dos no hay nada que restar, y decir "faltan 3,000 km" sería inventar.
  if ((tarea.everyKm ?? 0) > 0 && ultimo.odometer != null && vehiculo.odometer != null) {
    kmFaltan = ultimo.odometer! + tarea.everyKm! - vehiculo.odometer!;
  }

  int? diasFaltan;
  if ((tarea.everyMonths ?? 0) > 0) {
    final proxima = masMeses(ultimo.day, tarea.everyMonths!);
    diasFaltan = DateTime.parse(proxima).difference(DateTime.parse(hoy)).inDays;
  }

  final pasadoKm = kmFaltan != null && kmFaltan <= 0;
  final pasadoFecha = diasFaltan != null && diasFaltan <= 0;

  return EstadoTarea(
    tarea: tarea,
    ultimo: ultimo,
    kmFaltan: kmFaltan,
    diasFaltan: diasFaltan,
    porQue: pasadoKm
        ? PorQue.km
        : pasadoFecha
            ? PorQue.fecha
            : PorQue.todavia,
  );
}

/// Todas las tareas de un vehículo, lo más urgente primero.
List<EstadoTarea> tareasOrdenadas({
  required Vehicle vehiculo,
  required List<VehicleTask> tareas,
  required List<Service> servicios,
  required String hoy,
}) {
  final out = [
    for (final t in tareas)
      estadoDeTarea(tarea: t, vehiculo: vehiculo, servicios: servicios, hoy: hoy),
  ];
  out.sort((a, b) => a.urgencia.compareTo(b.urgencia));
  return out;
}

/// Cómo se dice en una línea: "faltan 1,200 km · faltan 3 meses".
///
/// El formato de los números lo pone quien llama: aquí no entra `intl`.
String textoDeTarea(
  EstadoTarea st, {
  required String Function(num) numero,
  required String Function(int n, String uno, String varios) plural,
}) {
  if (st.nunca) return 'Nunca se le ha hecho';

  final partes = <String>[];
  if (st.kmFaltan case final km?) {
    partes.add(km <= 0 ? '${numero(-km)} km pasados' : 'faltan ${numero(km)} km');
  }
  if (st.diasFaltan case final d?) {
    partes.add(
      d <= 0
          ? '${plural(-d, 'día', 'días')} pasados'
          // Más allá de mes y medio, contar días deja de decir algo: "faltan
          // 213 días" es peor que "faltan 7 meses".
          : d <= 45
              ? 'faltan ${plural(d, 'día', 'días')}'
              : 'faltan ${plural((d / 30.44).round(), 'mes', 'meses')}',
    );
  }
  return partes.isEmpty ? 'Sin intervalo' : partes.join(' · ');
}
