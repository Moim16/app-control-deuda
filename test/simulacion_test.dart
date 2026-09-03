// El simulador contesta "cuándo se acaba esto". Si la cuenta está mal, la
// respuesta es una fecha equivocada y nadie se entera.

import 'package:deudas_app/domain/models/debt.dart';
import 'package:deudas_app/domain/simulacion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sin interés', () {
    test('la cuenta es la que uno haría a mano', () {
      final r = simular(
        saldo: 1000,
        cuota: 250,
        cada: DueEvery.monthly,
        desde: '2026-01-15',
      );

      expect(r.pagos, 4);
      expect(r.nunca, isFalse);
      expect(r.pagado, 1000);
      expect(r.interes, 0);
      expect(r.hasta, '2026-04-15');
      expect(r.cuotas.last.balance, 0);
    });

    test('el último pago es solo lo que falta, no la cuota entera', () {
      final r = simular(
        saldo: 1000,
        cuota: 400,
        cada: DueEvery.monthly,
        desde: '2026-01-15',
      );

      expect(r.pagos, 3);
      expect(r.cuotas.last.payment, 200);
      expect(r.pagado, 1000, reason: 'no se paga de más');
    });

    test('el primer pago es el día de arranque, no el mes siguiente', () {
      final r = simular(saldo: 100, cuota: 100, cada: DueEvery.monthly, desde: '2026-03-01');
      expect(r.cuotas.single.day, '2026-03-01');
    });

    test('semanal y quincenal avanzan de siete en siete y de catorce en catorce', () {
      final sem = simular(saldo: 300, cuota: 100, cada: DueEvery.weekly, desde: '2026-01-01');
      expect(sem.cuotas.map((c) => c.day), ['2026-01-01', '2026-01-08', '2026-01-15']);

      final quin = simular(saldo: 300, cuota: 100, cada: DueEvery.biweekly, desde: '2026-01-01');
      expect(quin.cuotas.map((c) => c.day), ['2026-01-01', '2026-01-15', '2026-01-29']);
    });

    test('un plan del día 31 cae en el último día de los meses cortos', () {
      final r = simular(saldo: 300, cuota: 100, cada: DueEvery.monthly, desde: '2026-01-31');
      expect(r.cuotas.map((c) => c.day), ['2026-01-31', '2026-02-28', '2026-03-31']);
    });
  });

  group('con interés', () {
    test('se paga más que el saldo, y el interés se contabiliza aparte', () {
      final r = simular(
        saldo: 1000,
        cuota: 200,
        cada: DueEvery.monthly,
        desde: '2026-01-01',
        rate: 12,
      );

      expect(r.nunca, isFalse);
      expect(r.pagado, greaterThan(1000));
      expect(r.interes, greaterThan(0));
      // Lo pagado es el saldo más el interés que corrió.
      expect(r.pagado, closeTo(1000 + r.interes, 0.01));
    });

    test('el primer pago no lleva interés: no ha pasado ningún día', () {
      final r = simular(
        saldo: 1000,
        cuota: 200,
        cada: DueEvery.monthly,
        desde: '2026-01-01',
        rate: 24,
      );
      expect(r.cuotas.first.interest, 0);
      expect(r.cuotas[1].interest, greaterThan(0));
    });

    test('una cuota que no cubre el interés se avisa en vez de dar vueltas', () {
      // C$10,000 al 60% anual generan ~C$500 al mes: con C$100 esto no baja
      // nunca, y decirlo es justo lo útil.
      final r = simular(
        saldo: 10000,
        cuota: 100,
        cada: DueEvery.monthly,
        desde: '2026-01-01',
        rate: 60,
      );

      expect(r.nunca, isTrue);
      expect(r.pagos, lessThan(10), reason: 'se corta enseguida, no en 1200 vueltas');
    });
  });

  group('los casos raros', () {
    test('una cuota de cero no simula nada', () {
      final r = simular(saldo: 1000, cuota: 0, cada: DueEvery.monthly, desde: '2026-01-01');
      expect(r.cuotas, isEmpty);
      expect(r.nunca, isTrue);
      expect(r.hasta, '2026-01-01', reason: 'sin pagos, el "hasta" es el arranque');
    });

    test('un saldo ya en cero tampoco', () {
      final r = simular(saldo: 0, cuota: 500, cada: DueEvery.monthly, desde: '2026-01-01');
      expect(r.cuotas, isEmpty);
      expect(r.nunca, isFalse);
    });

    test('una cuota gigante lo paga de una vez', () {
      final r = simular(saldo: 500, cuota: 99999, cada: DueEvery.monthly, desde: '2026-01-01');
      expect(r.pagos, 1);
      expect(r.pagado, 500);
    });

    test('un plan larguísimo no deja la app dando vueltas', () {
      final r = simular(saldo: 100000, cuota: 1, cada: DueEvery.weekly, desde: '2026-01-01');
      expect(r.pagos, lessThanOrEqualTo(1200));
      expect(r.nunca, isTrue, reason: 'a ese ritmo no se acaba');
    });
  });

  group('tiempoHumano', () {
    test('en semanas cuando es poco', () {
      expect(tiempoHumano('2026-01-01', '2026-01-08'), '1 semana');
      expect(tiempoHumano('2026-01-01', '2026-01-22'), '3 semanas');
    });

    test('en meses hasta los dos años', () {
      expect(tiempoHumano('2026-01-01', '2026-07-01'), '6 meses');
      expect(tiempoHumano('2026-01-01', '2027-06-01'), '17 meses');
    });

    test('en años y meses cuando es mucho: nadie dice "27 meses"', () {
      expect(tiempoHumano('2026-01-01', '2028-04-01'), '2 años y 3 meses');
      expect(tiempoHumano('2026-01-01', '2028-01-01'), '2 años');
    });

    test('el mismo día no dice "0 semanas"', () {
      expect(tiempoHumano('2026-01-01', '2026-01-01'), '1 semana');
    });
  });
}
