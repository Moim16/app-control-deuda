// El texto que se manda por WhatsApp. Se prueba porque sale de la app hacia
// otra persona: un saldo mal escrito ahí es una conversación incómoda.

import 'package:deudas_app/domain/models/debt.dart';
import 'package:deudas_app/domain/pago_esperado.dart';
import 'package:deudas_app/domain/resumen_texto.dart';
import 'package:flutter_test/flutter_test.dart';

String plataFalsa(num m, String c) => '${c == 'USD' ? 'US\$' : 'C\$'}${m.toStringAsFixed(0)}';
String fechaFalsa(String d) => d;

Debt deuda({
  String name = 'Mi hermano',
  String? counterpart,
  DebtDirection direction = DebtDirection.owe,
  Map<String, Totals>? totals,
}) =>
    Debt(
      id: 1,
      name: name,
      kind: DebtKind.person,
      currency: 'NIO',
      direction: direction,
      counterpart: counterpart,
      active: true,
      totals: totals ?? const {'NIO': Totals(loaned: 5000, paid: 1500, balance: 3500)},
      currencies: (totals ?? const {'NIO': Totals(loaned: 0, paid: 0, balance: 0)}).keys.toList(),
      entryCount: 2,
    );

String texto({
  required Debt d,
  bool cobro = false,
  PagoEsperado? pago,
  List<({double amount, String currency, String day, bool isLoan, String? reason})> movs =
      const [],
}) =>
    resumenTexto(
      debt: d,
      movimientos: movs,
      cobro: cobro,
      hoy: '2026-09-03',
      pago: pago,
      palabra: (esPrestamo) => esPrestamo ? 'Préstamo' : 'Abono',
      etiquetaPrestado: cobro ? 'Presté' : 'Prestado',
      etiquetaAbonado: cobro ? 'Me han pagado' : 'Abonado',
      plata: plataFalsa,
      fecha: fechaFalsa,
    );

void main() {
  group('una deuda propia', () {
    test('lleva el nombre, la fecha y los totales', () {
      final t = texto(d: deuda());
      expect(t, contains('*Mi hermano*'));
      expect(t, contains('Al 2026-09-03'));
      expect(t, contains('Prestado: C\$5000'));
      expect(t, contains('Abonado: C\$1500'));
      expect(t, contains('*Saldo: C\$3500*'));
    });

    test('no arranca con recordatorio aunque haya un pago pendiente', () {
      // El texto de una deuda propia es para uno mismo: un "Hola" dirigido a
      // quien te prestó no tiene sentido aquí.
      final t = texto(
        d: deuda(counterpart: 'Juan'),
        pago: const PagoEsperado(day: '2026-09-01', daysLeft: -2, amount: 500, currency: 'NIO'),
      );
      expect(t, isNot(contains('Hola')));
      expect(t.split('\n').first, '*Mi hermano* (Juan)');
    });
  });

  group('un cobro', () {
    test('arranca con el recordatorio y el nombre de pila', () {
      final t = texto(
        d: deuda(name: 'Carlos', counterpart: 'Carlos Alberto Martínez',
            direction: DebtDirection.owed),
        cobro: true,
        pago: const PagoEsperado(day: '2026-09-10', daysLeft: 7, amount: 500, currency: 'NIO'),
      );

      expect(t, startsWith('Hola Carlos, recordatorio del pago de C\$500'));
      expect(t, contains('que toca en 7 días'));
      expect(t, isNot(contains('Alberto')), reason: 'solo el nombre de pila');
    });

    test('con el pago atrasado lo dice de otra forma', () {
      final t = texto(
        d: deuda(direction: DebtDirection.owed),
        cobro: true,
        pago: const PagoEsperado(day: '2026-08-01', daysLeft: -33, amount: 500, currency: 'NIO'),
      );

      expect(t, startsWith('Hola, te escribo por el pago de C\$500'));
      expect(t, contains('que quedó para el 2026-08-01'));
      expect(t, contains('(33 días atrás)'));
    });

    test('el que toca hoy y el de mañana se dicen con esas palabras', () {
      final hoy = texto(
        d: deuda(direction: DebtDirection.owed),
        cobro: true,
        pago: const PagoEsperado(day: '2026-09-03', daysLeft: 0, amount: 500, currency: 'NIO'),
      );
      expect(hoy, contains('que toca hoy'));

      final manana = texto(
        d: deuda(direction: DebtDirection.owed),
        cobro: true,
        pago: const PagoEsperado(day: '2026-09-04', daysLeft: 1, amount: 500, currency: 'NIO'),
      );
      expect(manana, contains('que toca mañana'));
    });

    test('sin pago pendiente no hay recordatorio', () {
      final t = texto(d: deuda(direction: DebtDirection.owed), cobro: true);
      expect(t, isNot(contains('Hola')));
      expect(t, startsWith('*Mi hermano*'));
    });

    test('el saldo se llama "pendiente" y no se repite el nombre del deudor', () {
      final t = texto(
        d: deuda(counterpart: 'Carlos', direction: DebtDirection.owed),
        cobro: true,
      );
      expect(t, contains('*Saldo pendiente: C\$3500*'));
      // En un cobro el mensaje va PARA Carlos: ponerle su nombre al lado del
      // título sería hablarle de sí mismo en tercera persona.
      expect(t, isNot(contains('*Mi hermano* (Carlos)')));
    });
  });

  group('dos monedas', () {
    test('se cuentan por separado, con su encabezado', () {
      final t = texto(
        d: deuda(totals: const {
          'NIO': Totals(loaned: 5000, paid: 1500, balance: 3500),
          'USD': Totals(loaned: 200, paid: 50, balance: 150),
        }),
      );

      expect(t, contains('_En córdobas_'));
      expect(t, contains('_En dólares_'));
      expect(t, contains('*Saldo: C\$3500*'));
      expect(t, contains('*Saldo: US\$150*'));
      // Y en ningún sitio la suma de las dos.
      expect(t, isNot(contains('3650')));
    });

    test('con una sola moneda no se pone el encabezado', () {
      expect(texto(d: deuda()), isNot(contains('_En ')));
    });
  });

  group('los últimos movimientos', () {
    final muchos = [
      for (var i = 1; i <= 8; i++)
        (day: '2026-08-0$i', reason: 'Movimiento $i', amount: 100.0 * i, currency: 'NIO',
            isLoan: i.isOdd),
    ];

    test('van los cinco primeros de la lista y no más', () {
      final t = texto(d: deuda(), movs: muchos);
      expect(t, contains('Últimos movimientos:'));
      expect(t, contains('Movimiento 1'));
      expect(t, contains('Movimiento 5'));
      expect(t, isNot(contains('Movimiento 6')));
    });

    test('el signo dice si subió o bajó el saldo', () {
      final t = texto(d: deuda(), movs: muchos);
      expect(t, contains('＋ 2026-08-01 · Movimiento 1 · C\$100'));
      expect(t, contains('－ 2026-08-02 · Movimiento 2 · C\$200'));
    });

    test('sin motivo se pone la palabra del tipo de movimiento', () {
      final t = texto(d: deuda(), movs: [
        (day: '2026-08-01', reason: null, amount: 100.0, currency: 'NIO', isLoan: true),
        (day: '2026-08-02', reason: '   ', amount: 50.0, currency: 'NIO', isLoan: false),
      ]);
      expect(t, contains('Préstamo · C\$100'));
      expect(t, contains('Abono · C\$50'));
    });

    test('sin movimientos no aparece el encabezado', () {
      expect(texto(d: deuda()), isNot(contains('Últimos movimientos')));
    });
  });

  test('un saldo a favor no se escribe en negativo', () {
    final t = texto(
      d: deuda(totals: const {'NIO': Totals(loaned: 1000, paid: 1200, balance: -200)}),
    );
    expect(t, contains('*Saldo: C\$0*'));
    expect(t, isNot(contains('-200')));
  });
}
