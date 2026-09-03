// Las reglas de qué es una deuda que se puede guardar.
//
// La de arriba, y la que más importa: NO se pide monto. Una deuda nace con un
// nombre y se va llenando de préstamos.

import 'package:deudas_app/domain/models/debt.dart';
import 'package:deudas_app/domain/models/debt_draft.dart';
import 'package:flutter_test/flutter_test.dart';

const hoy = '2026-09-03';

DebtDraft borrador({
  String name = 'Mi hermano',
  String counterpart = '',
  String note = '',
  String interestRate = '',
  DueEvery? dueEvery,
  String dueAmount = '',
  String dueFrom = hoy,
}) =>
    DebtDraft(
      direction: DebtDirection.owe,
      name: name,
      counterpart: counterpart,
      note: note,
      interestRate: interestRate,
      dueEvery: dueEvery,
      dueAmount: dueAmount,
      dueFrom: dueFrom,
    );

void main() {
  test('con solo un nombre ya se puede crear: no hace falta el monto', () {
    expect(borrador().problema, isNull);
  });

  group('el nombre', () {
    test('es lo único obligatorio', () {
      expect(borrador(name: '').problema, 'Ponle un nombre a la deuda.');
      expect(borrador(name: '   ').problema, 'Ponle un nombre a la deuda.');
    });

    test('tiene el mismo tope que la API', () {
      expect(borrador(name: 'x' * 80).problema, isNull);
      expect(borrador(name: 'x' * 81).problema, isNotNull);
    });
  });

  group('el interés', () {
    test('vacío significa sin interés, que es lo normal entre familia', () {
      expect(borrador(interestRate: '').interes, isNull);
      expect(borrador(interestRate: '   ').interes, isNull);
      expect(borrador(interestRate: '').problema, isNull);
    });

    test('acepta el rango de la API', () {
      expect(borrador(interestRate: '0').problema, isNull);
      expect(borrador(interestRate: '12.5').problema, isNull);
      expect(borrador(interestRate: '200').problema, isNull);
    });

    test('fuera de rango o mal escrito se dice con las palabras de la API', () {
      for (final v in ['-1', '201', 'mucho']) {
        expect(
          borrador(interestRate: v).problema,
          'El interés anual debe ser un porcentaje entre 0 y 200.',
          reason: 'con "$v"',
        );
      }
    });
  });

  group('el acuerdo de pago', () {
    test('sin frecuencia no se pregunta nada más', () {
      // Un monto suelto sin frecuencia no estorba: el acuerdo no existe.
      expect(borrador(dueAmount: '500').tieneAcuerdo, isFalse);
      expect(borrador(dueAmount: '500').problema, isNull);
    });

    test('con frecuencia hacen falta el monto y la fecha', () {
      expect(
        borrador(dueEvery: DueEvery.monthly).problema,
        'Indica cuánto se paga en cada fecha.',
      );
      expect(
        borrador(dueEvery: DueEvery.monthly, dueAmount: '500', dueFrom: 'nunca').problema,
        'Indica la fecha del primer pago acordado.',
      );
      expect(
        borrador(dueEvery: DueEvery.monthly, dueAmount: '500').problema,
        isNull,
      );
    });

    test('la cuota se lee con coma de miles y redondea a dos decimales', () {
      expect(borrador(dueAmount: '1,500.555').cuota, 1500.56);
    });

    test('una cuota de cero no es un acuerdo', () {
      expect(borrador(dueEvery: DueEvery.weekly, dueAmount: '0').problema, isNotNull);
    });
  });

  group('lo que se manda a la API', () {
    test('el acuerdo va en los tres campos', () {
      final j = borrador(
        dueEvery: DueEvery.biweekly,
        dueAmount: '500',
        dueFrom: '2026-01-15',
      ).aJson(nueva: true);

      expect(j['dueEvery'], 'biweekly');
      expect(j['dueAmount'], 500);
      expect(j['dueFrom'], '2026-01-15');
    });

    test('sin acuerdo, dueEvery va vacío para que el servidor lo BORRE', () {
      // Si solo se omitiera, el acuerdo viejo se quedaría puesto y no habría
      // forma de quitarlo desde la app.
      final j = borrador().aJson(nueva: false);
      expect(j['dueEvery'], '');
      expect(j.containsKey('dueAmount'), isFalse);
    });

    test('al crear no se manda `active`: una deuda nueva nace abierta', () {
      expect(borrador().aJson(nueva: true).containsKey('active'), isFalse);
      expect(borrador().aJson(nueva: false)['active'], isTrue);
    });

    test('el nombre y la nota van sin espacios de sobra', () {
      final j = borrador(name: '  Mi hermano  ', note: ' ojo  ').aJson(nueva: true);
      expect(j['name'], 'Mi hermano');
      expect(j['note'], 'ojo');
    });
  });

  group('al abrir una deuda que ya existe', () {
    Debt existente({
      double? interestRate,
      PaymentPlan? plan,
      bool active = true,
    }) =>
        Debt(
          id: 3,
          name: 'Mi hermana',
          kind: DebtKind.person,
          currency: 'USD',
          direction: DebtDirection.owed,
          counterpart: 'Ana',
          note: 'de la moto',
          interestRate: interestRate,
          active: active,
          totals: const {},
          currencies: const ['USD'],
          entryCount: 4,
          plan: plan,
        );

    test('el formulario arranca con lo que ya estaba', () {
      final d = DebtDraft.de(existente(), hoy: hoy);
      expect(d.name, 'Mi hermana');
      expect(d.direction, DebtDirection.owed);
      expect(d.currency, 'USD');
      expect(d.counterpart, 'Ana');
      expect(d.note, 'de la moto');
      expect(d.active, isTrue);
    });

    test('un interés redondo se escribe sin decimales', () {
      expect(DebtDraft.de(existente(interestRate: 12), hoy: hoy).interestRate, '12');
      expect(DebtDraft.de(existente(interestRate: 12.5), hoy: hoy).interestRate, '12.5');
    });

    test('sin interés el campo queda vacío, no en "null"', () {
      expect(DebtDraft.de(existente(), hoy: hoy).interestRate, '');
    });

    test('sin acuerdo, la fecha del primer pago se propone hoy', () {
      final d = DebtDraft.de(existente(), hoy: hoy);
      expect(d.tieneAcuerdo, isFalse);
      expect(d.dueFrom, hoy);
    });

    test('con acuerdo se traen los tres datos', () {
      final d = DebtDraft.de(
        existente(
          plan: const PaymentPlan(every: DueEvery.monthly, amount: 1000, from: '2026-07-15'),
        ),
        hoy: hoy,
      );
      expect(d.dueEvery, DueEvery.monthly);
      expect(d.dueAmount, '1000');
      expect(d.dueFrom, '2026-07-15');
    });

    test('quitar el acuerdo deja los tres campos fuera', () {
      final d = DebtDraft.de(
        existente(
          plan: const PaymentPlan(every: DueEvery.monthly, amount: 1000, from: '2026-07-15'),
        ),
        hoy: hoy,
      ).copyWith(borrarAcuerdo: true);

      expect(d.tieneAcuerdo, isFalse);
      expect(d.aJson(nueva: false)['dueEvery'], '');
    });

    test('una deuda cerrada abre el formulario con el interruptor apagado', () {
      expect(DebtDraft.de(existente(active: false), hoy: hoy).active, isFalse);
    });
  });
}
