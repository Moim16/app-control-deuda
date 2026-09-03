// =============================================================================
//  La única cuenta que hace la app: cuándo toca el próximo pago.
//
//  Está en `domain` justamente para poder probarla así, sin levantar una
//  pantalla ni un servidor. Todo lo demás (saldos, totales) llega ya calculado
//  de la API y lo prueban las 223 pruebas del proyecto web.
// =============================================================================

import 'package:deudas_app/domain/models/debt.dart';
import 'package:deudas_app/domain/pago_esperado.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una deuda de mentira, con lo justo para esta prueba.
Debt _deuda({
  DueEvery? cada,
  double monto = 1000,
  String? desde,
  String? ultimoPago,
  double saldo = 4000,
}) {
  return Debt(
    id: 1,
    name: 'Primo Carlos',
    kind: DebtKind.person,
    currency: 'NIO',
    direction: DebtDirection.owed,
    active: true,
    totals: {'NIO': Totals(loaned: 6000, paid: 6000 - saldo, balance: saldo)},
    currencies: const ['NIO'],
    entryCount: 3,
    lastPaymentDay: ultimoPago,
    plan: (cada == null || desde == null)
        ? null
        : PaymentPlan(every: cada, amount: monto, from: desde),
  );
}

void main() {
  group('próximo pago', () {
    test('sin acuerdo cargado no hay nada que recordar', () {
      expect(proximoPago(_deuda(), '2026-09-03'), isNull);
    });

    test('un cobro saldado tampoco recuerda nada', () {
      final d = _deuda(cada: DueEvery.monthly, desde: '2026-01-15', saldo: 0);
      expect(proximoPago(d, '2026-09-03'), isNull);
    });

    test('nunca pagó: toca la primera fecha del acuerdo, y está atrasada', () {
      final d = _deuda(cada: DueEvery.monthly, desde: '2026-07-15');
      final p = proximoPago(d, '2026-09-03')!;
      expect(p.day, '2026-07-15');
      expect(p.overdue, isTrue);
      expect(p.daysLate, 50);
      expect(p.amount, 1000);
    });

    test('ya pagó: toca la siguiente fecha después de ese pago', () {
      final d = _deuda(
        cada: DueEvery.monthly,
        desde: '2026-01-15',
        ultimoPago: '2026-08-20',
      );
      final p = proximoPago(d, '2026-09-03')!;
      expect(p.day, '2026-09-15');
      expect(p.overdue, isFalse);
      expect(p.daysLeft, 12);
    });

    test('el que toca hoy se cuenta como que toca hoy, no como pasado', () {
      final d = _deuda(cada: DueEvery.monthly, desde: '2026-09-03');
      final p = proximoPago(d, '2026-09-03')!;
      expect(p.day, '2026-09-03');
      expect(p.daysLeft, 0);
      expect(p.overdue, isFalse);
    });

    test('semanal y quincenal avanzan de siete en siete y de catorce en catorce', () {
      final semanal = proximoPago(
        _deuda(cada: DueEvery.weekly, desde: '2026-08-06', ultimoPago: '2026-08-25'),
        '2026-09-03',
      )!;
      expect(semanal.day, '2026-08-27');

      final quincenal = proximoPago(
        _deuda(cada: DueEvery.biweekly, desde: '2026-08-06', ultimoPago: '2026-08-25'),
        '2026-09-03',
      )!;
      expect(quincenal.day, '2026-09-03');
    });

    test('un acuerdo del día 31 cae en el último día de los meses cortos', () {
      // Enero 31 + 1 mes tiene que ser el 28 de febrero, no el 3 de marzo.
      final d = _deuda(
        cada: DueEvery.monthly,
        desde: '2026-01-31',
        ultimoPago: '2026-02-01',
      );
      expect(proximoPago(d, '2026-02-10')!.day, '2026-02-28');
    });

    test('un acuerdo viejísimo no deja la app dando vueltas', () {
      // Semanal desde 2015 y sin pagos: tiene que terminar y devolver algo.
      final d = _deuda(cada: DueEvery.weekly, desde: '2015-01-01');
      final p = proximoPago(d, '2026-09-03');
      expect(p, isNotNull);
    });
  });
}
