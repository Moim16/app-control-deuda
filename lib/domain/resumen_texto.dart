// =============================================================================
//  El resumen de una deuda en texto, para mandarlo por WhatsApp.
//
//  Suena a adorno y es lo contrario: en un COBRO, este texto es el mensaje que
//  uno no sabe cómo empezar. Si hay un pago pendiente, arranca con el
//  recordatorio y con el nombre de pila de quien debe, porque eso es lo que
//  hace que el mensaje se mande en vez de quedarse sin escribir.
//
//  Va en `domain` y no en la pantalla porque es texto con reglas (qué se dice
//  primero, qué se calla según quién mire) y eso se prueba.
// =============================================================================

import 'models/debt.dart';
import 'pago_esperado.dart';

/// Cómo se escriben los montos y las fechas. Se pasan desde fuera para no
/// meter `intl` ni el formato de la interfaz en el dominio.
typedef Plata = String Function(num monto, String moneda);
typedef Fecha = String Function(String dia);

/// El texto del resumen. `pago` solo se usa cuando es un cobro: el recordatorio
/// va dirigido a quien debe.
String resumenTexto({
  required Debt debt,
  required List<({String day, String? reason, double amount, String currency, bool isLoan})>
      movimientos,
  required bool cobro,
  required String hoy,
  required String Function(bool isLoan) palabra,
  required String etiquetaPrestado,
  required String etiquetaAbonado,
  required Plata plata,
  required Fecha fecha,
  PagoEsperado? pago,
}) {
  final lineas = <String>[];

  // El recordatorio, solo en un cobro y solo si hay algo que recordar: en una
  // deuda propia el texto es para uno mismo y esto estorbaría.
  if (cobro && pago != null) {
    final nombre = _primerNombre(debt.counterpart);
    final saludo = 'Hola${nombre != null ? ' $nombre' : ''}';
    lineas.add(
      pago.overdue
          ? '$saludo, te escribo por el pago de ${plata(pago.amount, pago.currency)} '
              'que quedó para el ${fecha(pago.day)} '
              '(${_plural(pago.daysLate, 'día', 'días')} atrás).'
          : '$saludo, recordatorio del pago de ${plata(pago.amount, pago.currency)} '
              '${_cuando(pago)} (${fecha(pago.day)}).',
    );
    lineas.add('');
  }

  final quien = debt.counterpart?.trim();
  lineas.add(
    '*${debt.name}*'
    '${(quien != null && quien.isNotEmpty && !cobro) ? ' ($quien)' : ''}',
  );
  lineas.add('Al ${fecha(hoy)}');

  final varias = debt.currencies.length > 1;
  for (final c in debt.currencies) {
    final t = debt.totals[c];
    if (t == null) continue;
    lineas.add('');
    if (varias) lineas.add('_En ${c == 'USD' ? 'dólares' : 'córdobas'}_');
    lineas.add('$etiquetaPrestado: ${plata(t.loaned, c)}');
    lineas.add('$etiquetaAbonado: ${plata(t.paid, c)}');
    lineas.add(
      '*${cobro ? 'Saldo pendiente' : 'Saldo'}: '
      '${plata(t.balance > 0 ? t.balance : 0, c)}*',
    );
  }

  // Los últimos cinco: los suficientes para reconocer de qué se habla, sin
  // convertir el mensaje en un estado de cuenta (para eso está el PDF).
  final ultimos = movimientos.take(5).toList();
  if (ultimos.isNotEmpty) {
    lineas.add('');
    lineas.add('Últimos movimientos:');
    for (final e in ultimos) {
      final motivo = (e.reason?.trim().isNotEmpty ?? false)
          ? e.reason!.trim()
          : palabra(e.isLoan);
      lineas.add(
        '${e.isLoan ? '＋' : '－'} ${fecha(e.day)} · $motivo · '
        '${plata(e.amount, e.currency)}',
      );
    }
  }

  return lineas.join('\n');
}

/// Solo el nombre de pila: "Hola Carlos" y no "Hola Carlos Alberto Martínez".
String? _primerNombre(String? completo) {
  final s = completo?.trim() ?? '';
  if (s.isEmpty) return null;
  return s.split(RegExp(r'\s+')).first;
}

String _cuando(PagoEsperado p) {
  if (p.daysLeft == 0) return 'que toca hoy';
  if (p.daysLeft == 1) return 'que toca mañana';
  return 'que toca en ${_plural(p.daysLeft, 'día', 'días')}';
}

String _plural(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';
