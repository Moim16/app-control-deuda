// =============================================================================
//  "¿Y si abono C$500 cada mes?"
//
//  Es la segunda cuenta que hace la app por su cuenta (la otra es el próximo
//  pago), y por el mismo motivo: no hay nada que preguntarle al servidor. Es
//  aritmética sobre un saldo que ya llegó calculado.
//
//  Lo mismo sirve para lo que uno paga y para lo que espera cobrar: cambian las
//  palabras, no los números.
//
//  Va en `domain` para poder probarla sin pantalla, que es justo lo que hace
//  falta con una cuenta que decide "termino en marzo de 2028".
// =============================================================================

import 'dia.dart';
import 'models/debt.dart';

/// Un pago del plan.
class Cuota {
  const Cuota({
    required this.n,
    required this.day,
    required this.payment,
    required this.interest,
    required this.balance,
  });

  /// El número de pago, empezando en 1.
  final int n;
  final String day;
  final double payment;

  /// El interés que corrió desde el pago anterior.
  final double interest;

  /// Lo que queda después de este pago.
  final double balance;
}

/// El resultado de la simulación.
class Simulacion {
  const Simulacion({
    required this.cuotas,
    required this.nunca,
    required this.interes,
    required this.pagado,
    required this.desde,
  });

  final List<Cuota> cuotas;

  /// Con ese monto la deuda NO se termina de pagar: el abono no cubre ni el
  /// interés del período. Es el caso que hay que avisar, no esconder.
  final bool nunca;

  /// Cuánto interés se paga en total.
  final double interes;

  /// Cuánto se paga en total (capital + interés).
  final double pagado;

  final String desde;

  int get pagos => cuotas.length;

  /// El día del último pago, o el de arranque si no hay ninguno.
  String get hasta => cuotas.isEmpty ? desde : cuotas.last.day;
}

/// El tope de vueltas: 1200 pagos semanales son 23 años. Más allá de eso, lo
/// que hay que decir no es la fecha, es que así no se termina.
const _maxPagos = 1200;

/// Simula pagar `cuota` cada `cada` desde `desde` sobre un saldo.
///
/// El interés es anual y simple, y corre por los días que pasan entre pago y
/// pago; con `rate` en 0 (lo normal entre familia) no entra en la cuenta.
Simulacion simular({
  required double saldo,
  required double cuota,
  required DueEvery cada,
  required String desde,
  double rate = 0,
}) {
  final cuotas = <Cuota>[];
  var bal = saldo;
  var day = desde;
  var prev = desde;
  var interes = 0.0;
  var pagado = 0.0;

  // Con una cuota que no suma nada no hay nada que simular: se responde
  // "así no se termina" en vez de dar 1200 vueltas para descubrirlo.
  if (cuota <= 0 || saldo <= 0.005) {
    return Simulacion(
      cuotas: const [],
      nunca: saldo > 0.005,
      interes: 0,
      pagado: 0,
      desde: desde,
    );
  }

  while (bal > 0.005 && cuotas.length < _maxPagos) {
    final dias = cuotas.isEmpty ? 0 : _diasEntre(prev, day);
    final i = rate > 0 ? bal * (rate / 100) * (dias / 365) : 0.0;
    bal += i;
    interes += i;

    final pago = cuota < bal ? cuota : bal;
    bal -= pago;
    pagado += pago;
    cuotas.add(Cuota(
      n: cuotas.length + 1,
      day: day,
      payment: pago,
      interest: i,
      balance: bal > 0 ? bal : 0,
    ));

    // Si con el pago el saldo no bajó respecto al período anterior, esto no
    // termina nunca: el interés se come el abono. Se corta aquí y se dice.
    if (cuotas.length >= 2 &&
        cuotas.last.balance >= cuotas[cuotas.length - 2].balance - 0.005 &&
        bal > 0) {
      return Simulacion(
        cuotas: cuotas,
        nunca: true,
        interes: interes,
        pagado: pagado,
        desde: desde,
      );
    }

    prev = day;
    // La siguiente fecha se cuenta SIEMPRE desde el arranque, no desde la
    // anterior. Sumando un mes a la anterior, un plan del 31 pasa por el 28 de
    // febrero y se queda en el 28 para siempre: el acuerdo se corre solo. Es la
    // misma regla que usa el calculo del proximo pago.
    final k = cuotas.length;
    day = switch (cada) {
      DueEvery.monthly => masMeses(desde, k),
      DueEvery.weekly => masDias(desde, 7 * k),
      DueEvery.biweekly => masDias(desde, 14 * k),
    };
  }

  return Simulacion(
    cuotas: cuotas,
    nunca: bal > 0.005,
    interes: interes,
    pagado: pagado,
    desde: desde,
  );
}

/// "3 semanas", "8 meses", "2 años y 3 meses".
///
/// Se redondea a la unidad que la persona usaría al contarlo: nadie dice "27
/// meses", dice "dos años y tres meses".
String tiempoHumano(String a, String b) {
  final dias = _diasEntre(a, b);
  if (dias < 45) {
    final semanas = (dias / 7).round();
    return _plural(semanas < 1 ? 1 : semanas, 'semana', 'semanas');
  }
  final meses = (dias / 30.44).round();
  if (meses < 24) return _plural(meses, 'mes', 'meses');
  final anos = meses ~/ 12;
  final resto = meses % 12;
  return '${_plural(anos, 'año', 'años')}'
      '${resto > 0 ? ' y ${_plural(resto, 'mes', 'meses')}' : ''}';
}

int _diasEntre(String a, String b) =>
    DateTime.parse(b).difference(DateTime.parse(a)).inDays;

String _plural(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';
