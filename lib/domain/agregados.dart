// =============================================================================
//  Lo que hace falta para los gráficos: agrupar movimientos por mes.
//
//  Son cuentas de presentación, no saldos: los saldos vienen de la API. Aquí
//  solo se reparte por mes lo que ya llegó, y por eso se puede hacer en el
//  teléfono sin miedo a decir algo distinto que la web.
//
//  Todo entra ya filtrado POR MONEDA. Sumar córdobas con dólares no pasa ni
//  aquí ni en ningún otro sitio de la app.
// =============================================================================

import 'dia.dart';
import 'models/entry.dart';

/// El saldo acumulado al cierre de cada mes: todo lo prestado menos todo lo
/// abonado hasta el final de ese mes.
///
/// Es acumulado y no el movimiento del mes: la pregunta que contesta la curva
/// es "cuánto debía en marzo", no "cuánto se movió en marzo".
List<double> saldoAlCierre(List<Entry> movimientos, List<String> meses) => [
      for (final m in meses)
        movimientos.fold<double>(
          0,
          (a, e) => mesDe(e.day).compareTo(m) <= 0 ? a + e.signed : a,
        ),
    ];

/// Cuánto se prestó y cuánto se abonó en cada mes.
({List<double> prestado, List<double> abonado}) flujoPorMes(
  List<Entry> movimientos,
  List<String> meses,
) {
  final prestado = List<double>.filled(meses.length, 0);
  final abonado = List<double>.filled(meses.length, 0);
  for (final e in movimientos) {
    final i = meses.indexOf(mesDe(e.day));
    if (i < 0) continue;
    if (e.isLoan) {
      prestado[i] += e.amount;
    } else {
      abonado[i] += e.amount;
    }
  }
  return (prestado: prestado, abonado: abonado);
}
