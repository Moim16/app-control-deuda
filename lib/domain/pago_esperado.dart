// =============================================================================
//  Cuando toca el proximo pago.
//
//  Es la UNICA cuenta que hace la app. Todo lo demas (saldos, totales por
//  moneda, permisos) llega ya resuelto de la API; esto se calcula aqui porque
//  el servidor manda el ACUERDO ("cada mes, C$1,000, desde el 15"), no la
//  fecha, y la fecha depende de cuando fue el ultimo pago.
//
//  Vive en `domain` justamente para poder probarla sin levantar una pantalla.
// =============================================================================

import 'models/debt.dart';

/// El proximo pago esperado y si ya se paso.
class PagoEsperado {
  const PagoEsperado({
    required this.day,
    required this.daysLeft,
    required this.amount,
    required this.currency,
  });

  /// YYYY-MM-DD del pago que toca ahora.
  final String day;

  /// Dias que faltan; negativo si ya se paso.
  final int daysLeft;

  final double amount;
  final String currency;

  bool get overdue => daysLeft < 0;
  bool get soon => daysLeft >= 0 && daysLeft <= 7;

  /// Cuantos dias de atraso lleva (0 si no esta atrasado).
  int get daysLate => overdue ? -daysLeft : 0;
}

/// Calcula el proximo pago de una deuda, o null si no hay nada que recordar.
///
/// La regla: se avanza por las fechas del acuerdo hasta pasar el ULTIMO PAGO
/// recibido; si nunca pago, hasta llegar a hoy. Asi, quien va al dia ve la
/// fecha que viene, y quien debe tres meses ve el que dejo de pagar.
///
/// Si el saldo esta en cero no se devuelve nada: no hay nada que reclamar.
PagoEsperado? proximoPago(Debt debt, String today) {
  final plan = debt.plan;
  if (plan == null) return null;

  final pendiente = debt.currencies.fold<double>(0, (a, c) => a + debt.pendingIn(c));
  if (pendiente <= 0) return null;

  // Lo que toca es el PRIMER pago que no se ha hecho:
  //
  //   - si nunca pago, el primero del acuerdo (y si ya paso, esta atrasado);
  //   - si ya pago, el primero posterior a ese pago.
  //
  // Avanzar hasta hoy seria lo facil, pero a quien acordo pagar cada mes desde
  // julio y no ha pagado nada le diria "toca en 12 dias" en vez de "atrasado
  // 50 dias", que es justo lo que uno necesita saber.
  final ultimoPago = debt.lastPaymentDay;
  var day = plan.from;
  if (ultimoPago != null && ultimoPago.compareTo(plan.from) >= 0) {
    var i = 0;
    // El tope de 600 vueltas es para que un acuerdo semanal viejisimo no deje
    // la app dando vueltas: son mas de 11 años de pagos semanales.
    while (i++ < 600 && day.compareTo(ultimoPago) <= 0) {
      day = switch (plan.every) {
        DueEvery.monthly => _addMonths(plan.from, i),
        DueEvery.weekly => _fmt(_parse(plan.from).add(Duration(days: 7 * i))),
        DueEvery.biweekly => _fmt(_parse(plan.from).add(Duration(days: 14 * i))),
      };
    }
  }

  return PagoEsperado(
    day: day,
    daysLeft: _parse(day).difference(_parse(today)).inDays,
    amount: plan.amount,
    currency: debt.currency,
  );
}

DateTime _parse(String yyyymmdd) => DateTime.parse(yyyymmdd);

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Sumar meses respetando el fin de mes: el 31 mas un mes cae en el ultimo dia
/// de febrero, no en el 3 de marzo.
String _addMonths(String day, int months) {
  final d = _parse(day);
  final destino = DateTime(d.year, d.month + months, 1);
  final ultimoDelMes = DateTime(destino.year, destino.month + 1, 0).day;
  return _fmt(DateTime(destino.year, destino.month, d.day < ultimoDelMes ? d.day : ultimoDelMes));
}
