// =============================================================================
//  Las cuentas del gasto del hogar.
//
//  Aquí sí hay reglas de negocio, y no obvias:
//
//    - El SUELDO de un mes es el ingreso fijo VIGENTE ese mes: el que tenga la
//      fecha más alta que no pase del fin de ese mes. Así un aumento se anota
//      con su fecha y los meses viejos siguen contando lo que se ganaba
//      entonces.
//    - Y si el mes es ANTERIOR al primer sueldo registrado, rige ese primero
//      igual: uno anota su sueldo hoy y espera que los meses de atrás no
//      aparezcan en cero.
//    - La CAPACIDAD de pago se compara contra lo que de verdad se gasta: el
//      promedio de los meses COMPLETOS anteriores, nunca el mes en curso, que
//      va a medias y siempre se ve mejor de lo que es.
//
//  Están en `domain` porque son las mismas reglas que la web, se prueban sin
//  pantalla, y equivocarse aquí no se nota a simple vista.
// =============================================================================

import 'dia.dart';
import 'models/debt.dart';
import 'models/entry.dart';
import 'models/spend.dart';

/// Lo que entró en un mes, en una moneda.
class IngresoDelMes {
  const IngresoDelMes({
    required this.sueldo,
    this.sueldoDesde,
    required this.extras,
    required this.extra,
  });

  /// El sueldo vigente ese mes.
  final double sueldo;

  /// Desde cuándo rige ese sueldo, para poder decirlo.
  final String? sueldoDesde;

  /// Los ingresos de una sola vez que cayeron en el mes.
  final List<Income> extras;

  /// La suma de esos extras.
  final double extra;

  double get total => sueldo + extra;

  /// Si hay algo que decir: sin ningún ingreso registrado, la pantalla pide
  /// que se anote en vez de mostrar ceros.
  bool get hay => sueldo > 0 || extras.isNotEmpty;
}

/// El ingreso de un mes ("2026-09") en una moneda.
IngresoDelMes ingresoDe(List<Income> ingresos, String mes, String moneda) {
  final fijos = ingresos.where((i) => i.esSueldo && i.currency == moneda).toList()
    ..sort((a, b) => a.day.compareTo(b.day));

  // "El fin de mes" se compara como texto: cualquier día del mes es menor que
  // "2026-09-31", exista o no ese día.
  final finDeMes = '$mes-31';
  final vigentes = fijos.where((i) => i.day.compareTo(finDeMes) <= 0).toList();
  final sueldo = vigentes.isNotEmpty ? vigentes.last : (fijos.isEmpty ? null : fijos.first);

  final extras = ingresos
      .where((i) => !i.esSueldo && i.currency == moneda && mesDe(i.day) == mes)
      .toList();

  return IngresoDelMes(
    sueldo: sueldo?.amount ?? 0,
    sueldoDesde: sueldo?.day,
    extras: extras,
    extra: extras.fold<double>(0, (a, i) => a + i.amount),
  );
}

/// Lo que se movió por deudas en un mes: lo que se abonó y lo que se recibió de
/// un cobro. Sale de los movimientos que ya trae el resumen.
({double pagado, double recibido}) flujoDeudas({
  required List<Entry> movimientos,
  required List<Debt> deudas,
  required String mes,
  required String moneda,
}) {
  var pagado = 0.0;
  var recibido = 0.0;
  for (final e in movimientos) {
    if (e.isLoan || e.currency != moneda || mesDe(e.day) != mes) continue;
    final d = deudas.where((x) => x.id == e.debtId).firstOrNull;
    if (d != null && d.isReceivable) {
      recibido += e.amount;
    } else {
      pagado += e.amount;
    }
  }
  return (pagado: pagado, recibido: recibido);
}

/// Cuánto sobra al mes para abonar.
class Capacidad {
  const Capacidad({
    required this.ingreso,
    required this.gasto,
    required this.meses,
  });

  /// El sueldo del mes en curso.
  final double ingreso;

  /// El gasto promedio de los meses completos anteriores.
  final double gasto;

  /// Cuántos meses con datos entraron en el promedio. Se dice: un promedio de
  /// un solo mes no es un promedio.
  final int meses;

  double get libre => ((ingreso - gasto) * 100).round() / 100;
}

/// La capacidad de pago, o null si todavía no se puede decir.
///
/// No entra lo que ya se abona a deudas hoy: la pregunta es "de lo que me
/// queda, cuánto puedo comprometer", y lo que uno ya paga es parte de eso.
Capacidad? capacidadDe({
  required List<Income> ingresos,
  required List<Expense> gastos,
  required String moneda,
  required String hoy,
  int meses = 3,
}) {
  final mesHoy = mesDe(hoy);
  // Solo meses CERRADOS: el mes en curso va a medias y engaña.
  final previos =
      ultimosMeses(meses + 1, hoy: hoy).where((m) => m.compareTo(mesHoy) < 0).toList();
  if (previos.isEmpty) return null;

  final sueldo = ingresoDe(ingresos, mesHoy, moneda).sueldo;
  if (sueldo <= 0) return null;

  double gastoDe(String m) => gastos
      .where((e) => e.currency == moneda && mesDe(e.day) == m)
      .fold<double>(0, (a, e) => a + e.amount);

  // Un mes sin gastos anotados no es un mes de gasto cero: es un mes sin
  // datos, y meterlo en el promedio lo hunde.
  final conDatos = previos.where((m) => gastoDe(m) > 0).toList();
  final promedio = conDatos.isEmpty
      ? 0.0
      : conDatos.fold<double>(0, (a, m) => a + gastoDe(m)) / conDatos.length;

  return Capacidad(
    ingreso: sueldo,
    gasto: (promedio * 100).round() / 100,
    meses: conDatos.length,
  );
}

/// Lo gastado en una categoría dentro de un mes.
class GastoDeCategoria {
  const GastoDeCategoria({required this.categoria, required this.total, required this.cuantos});

  /// null = "Sin categoría".
  final ExpenseCategory? categoria;
  final double total;
  final int cuantos;

  String get nombre => categoria?.name ?? 'Sin categoría';

  /// El tope de la categoría, solo si es de la misma moneda que se mira.
  double? topeEn(String moneda) {
    final c = categoria;
    if (c == null || c.budget == null || c.currency != moneda) return null;
    return c.budget;
  }
}

/// El gasto del mes repartido por categoría, de mayor a menor: es el orden en
/// el que uno se pregunta "¿en qué se me fue la plata?".
///
/// Aparecen las categorías con gasto y también las que tienen tope en esta
/// moneda aunque no se haya gastado nada: un tope sin gasto es información
/// ("todavía no he tocado esa").
List<GastoDeCategoria> porCategoria({
  required List<ExpenseCategory> categorias,
  required List<Expense> gastosDelMes,
  required String moneda,
}) {
  final enMoneda = gastosDelMes.where((e) => e.currency == moneda).toList();
  final out = <GastoDeCategoria>[];

  for (final c in categorias.where((c) => c.active)) {
    final suyos = enMoneda.where((e) => e.categoryId == c.id).toList();
    final total = suyos.fold<double>(0, (a, e) => a + e.amount);
    final conTope = c.budget != null && c.currency == moneda;
    if (total > 0 || conTope) {
      out.add(GastoDeCategoria(categoria: c, total: total, cuantos: suyos.length));
    }
  }

  final sinCategoria = enMoneda.where((e) => e.categoryId == null).toList();
  if (sinCategoria.isNotEmpty) {
    out.add(GastoDeCategoria(
      categoria: null,
      total: sinCategoria.fold<double>(0, (a, e) => a + e.amount),
      cuantos: sinCategoria.length,
    ));
  }

  out.sort((a, b) => b.total.compareTo(a.total));
  return out;
}

/// Cuántos días tiene un mes ("2026-02" -> 28).
int diasDelMes(String mes) {
  final ano = int.tryParse(mes.substring(0, 4)) ?? 2000;
  final m = int.tryParse(mes.substring(5, 7)) ?? 1;
  // El día 0 del mes siguiente es el último del mes que interesa.
  return DateTime(ano, m + 1, 0).day;
}

/// Cuánto del mes ha pasado, en %.
///
/// Es el número que hace útil el porcentaje del presupuesto: "llevo el 60%" no
/// dice nada hasta saber si va el 50% o el 90% del mes.
int porcentajeDelMes(String mes, String hoy) {
  final dias = diasDelMes(mes);
  if (mesDe(hoy) != mes) return 100; // un mes pasado (o futuro) ya está entero
  final dia = int.tryParse(hoy.substring(8, 10)) ?? dias;
  return ((dia / dias) * 100).round();
}
