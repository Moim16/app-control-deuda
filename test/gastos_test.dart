// Las reglas del gasto del hogar. Ninguna es obvia y todas cambian números que
// se leen como si fueran verdad.

import 'package:deudas_app/domain/gastos.dart';
import 'package:deudas_app/domain/models/debt.dart';
import 'package:deudas_app/domain/models/entry.dart';
import 'package:deudas_app/domain/models/spend.dart';
import 'package:flutter_test/flutter_test.dart';

Income sueldo(String desde, double monto, {String cur = 'NIO'}) => Income(
      id: desde.hashCode & 0xffff,
      kind: IncomeKind.monthly,
      amount: monto,
      currency: cur,
      day: desde,
    );

Income extra(String dia, double monto, {String cur = 'NIO'}) => Income(
      id: dia.hashCode & 0xffff,
      kind: IncomeKind.once,
      amount: monto,
      currency: cur,
      day: dia,
    );

Expense gasto(String dia, double monto, {int? cat, String cur = 'NIO'}) => Expense(
      id: (dia + monto.toString()).hashCode & 0xffff,
      categoryId: cat,
      day: dia,
      amount: monto,
      currency: cur,
      hasReceipt: false,
    );

ExpenseCategory categoria(int id, String nombre, {double? tope, String cur = 'NIO'}) =>
    ExpenseCategory(
      id: id,
      name: nombre,
      budget: tope,
      currency: cur,
      active: true,
      expenses: 0,
    );

void main() {
  group('el sueldo de un mes', () {
    final ingresos = [
      sueldo('2025-01-01', 10000),
      sueldo('2026-03-15', 14000), // un aumento
    ];

    test('es el vigente ese mes, no el último registrado', () {
      // La clave del módulo: los meses viejos siguen contando lo que se ganaba
      // entonces, no lo que se gana hoy.
      expect(ingresoDe(ingresos, '2026-01', 'NIO').sueldo, 10000);
      expect(ingresoDe(ingresos, '2026-02', 'NIO').sueldo, 10000);
      expect(ingresoDe(ingresos, '2026-03', 'NIO').sueldo, 14000);
      expect(ingresoDe(ingresos, '2026-09', 'NIO').sueldo, 14000);
    });

    test('un mes ANTERIOR al primer sueldo cuenta ese primero', () {
      // Uno anota su sueldo hoy y espera que los meses de atrás no salgan en
      // cero. Es la misma regla que el pago por día en asistencia-obra.
      expect(ingresoDe(ingresos, '2024-06', 'NIO').sueldo, 10000);
    });

    test('el aumento rige desde su mes completo, aunque sea el día 15', () {
      expect(ingresoDe(ingresos, '2026-03', 'NIO').sueldoDesde, '2026-03-15');
    });

    test('sin sueldo en esa moneda, cero', () {
      expect(ingresoDe(ingresos, '2026-09', 'USD').sueldo, 0);
      expect(ingresoDe(ingresos, '2026-09', 'USD').hay, isFalse);
    });

    test('un sueldo del día 31 cuenta en su mes', () {
      // El fin de mes se compara como "2026-01-31": el día existe o no, pero
      // la comparación de texto tiene que dejarlo pasar igual.
      expect(ingresoDe([sueldo('2026-01-31', 9000)], '2026-01', 'NIO').sueldo, 9000);
    });
  });

  group('los ingresos de una sola vez', () {
    test('cuentan solo en el mes en que cayeron', () {
      final ing = [sueldo('2026-01-01', 10000), extra('2026-12-15', 8000)];
      expect(ingresoDe(ing, '2026-12', 'NIO').total, 18000);
      expect(ingresoDe(ing, '2026-11', 'NIO').total, 10000);
    });

    test('se suman entre ellos', () {
      final ing = [extra('2026-12-01', 1000), extra('2026-12-20', 500)];
      final r = ingresoDe(ing, '2026-12', 'NIO');
      expect(r.extra, 1500);
      expect(r.extras.length, 2);
      expect(r.hay, isTrue, reason: 'sin sueldo pero con extras, hay algo que decir');
    });

    test('no se mezclan monedas', () {
      final ing = [extra('2026-12-01', 100, cur: 'USD'), extra('2026-12-02', 1000)];
      expect(ingresoDe(ing, '2026-12', 'USD').extra, 100);
      expect(ingresoDe(ing, '2026-12', 'NIO').extra, 1000);
    });
  });

  group('la capacidad de pago', () {
    final ingresos = [sueldo('2025-01-01', 10000)];
    // Meses cerrados con datos: junio, julio y agosto.
    final gastos = [
      gasto('2026-06-10', 6000),
      gasto('2026-07-10', 7000),
      gasto('2026-08-10', 8000),
      // El mes en curso, a medias: NO tiene que entrar en el promedio.
      gasto('2026-09-01', 500),
    ];

    test('promedia los meses CERRADOS, nunca el mes en curso', () {
      final cap = capacidadDe(
        ingresos: ingresos,
        gastos: gastos,
        moneda: 'NIO',
        hoy: '2026-09-03',
      )!;

      expect(cap.gasto, 7000, reason: '(6000+7000+8000)/3, sin el mes en curso');
      expect(cap.ingreso, 10000);
      expect(cap.libre, 3000);
      expect(cap.meses, 3);
    });

    test('un mes sin gastos anotados no hunde el promedio', () {
      // Un mes sin datos no es un mes de gasto cero.
      final cap = capacidadDe(
        ingresos: ingresos,
        gastos: [gasto('2026-08-10', 8000)],
        moneda: 'NIO',
        hoy: '2026-09-03',
      )!;

      expect(cap.gasto, 8000);
      expect(cap.meses, 1, reason: 'y se dice que es de un solo mes');
    });

    test('sin sueldo no se puede decir nada', () {
      expect(
        capacidadDe(ingresos: const [], gastos: gastos, moneda: 'NIO', hoy: '2026-09-03'),
        isNull,
      );
    });

    test('sin ningún gasto anotado, todo el sueldo está libre', () {
      final cap = capacidadDe(
        ingresos: ingresos,
        gastos: const [],
        moneda: 'NIO',
        hoy: '2026-09-03',
      )!;
      expect(cap.gasto, 0);
      expect(cap.libre, 10000);
      expect(cap.meses, 0);
    });

    test('gastar más de lo que se gana deja la capacidad en negativo', () {
      final cap = capacidadDe(
        ingresos: ingresos,
        gastos: [gasto('2026-08-10', 12000)],
        moneda: 'NIO',
        hoy: '2026-09-03',
      )!;
      expect(cap.libre, -2000);
    });

    test('no se mezclan monedas', () {
      final cap = capacidadDe(
        ingresos: [sueldo('2025-01-01', 500, cur: 'USD')],
        gastos: [gasto('2026-08-10', 8000), gasto('2026-08-11', 100, cur: 'USD')],
        moneda: 'USD',
        hoy: '2026-09-03',
      )!;
      expect(cap.ingreso, 500);
      expect(cap.gasto, 100, reason: 'los córdobas no entran');
    });
  });

  group('el flujo de deudas del mes', () {
    final deudas = [
      Debt(
        id: 1,
        name: 'Hermano',
        kind: DebtKind.person,
        currency: 'NIO',
        direction: DebtDirection.owe,
        active: true,
        totals: const {},
        currencies: const ['NIO'],
        entryCount: 0,
      ),
      Debt(
        id: 2,
        name: 'Primo',
        kind: DebtKind.person,
        currency: 'NIO',
        direction: DebtDirection.owed,
        active: true,
        totals: const {},
        currencies: const ['NIO'],
        entryCount: 0,
      ),
    ];

    Entry mov(int debtId, String dia, EntryKind k, double monto) => Entry(
          id: (debtId.toString() + dia).hashCode & 0xffff,
          debtId: debtId,
          kind: k,
          currency: 'NIO',
          day: dia,
          amount: monto,
          hasReceipt: false,
          commentCount: 0,
        );

    test('lo que abono sale y lo que me pagan entra', () {
      final f = flujoDeudas(
        movimientos: [
          mov(1, '2026-09-05', EntryKind.payment, 1000), // yo abono
          mov(2, '2026-09-06', EntryKind.payment, 400), // me pagan
        ],
        deudas: deudas,
        mes: '2026-09',
        moneda: 'NIO',
      );

      expect(f.pagado, 1000);
      expect(f.recibido, 400);
    });

    test('los préstamos no son flujo de caja del mes', () {
      // Un préstamo que me hacen no es plata que yo mueva: sube el saldo, no
      // sale del bolsillo.
      final f = flujoDeudas(
        movimientos: [mov(1, '2026-09-05', EntryKind.loan, 5000)],
        deudas: deudas,
        mes: '2026-09',
        moneda: 'NIO',
      );
      expect(f.pagado, 0);
      expect(f.recibido, 0);
    });

    test('solo el mes que se mira', () {
      final f = flujoDeudas(
        movimientos: [mov(1, '2026-08-05', EntryKind.payment, 1000)],
        deudas: deudas,
        mes: '2026-09',
        moneda: 'NIO',
      );
      expect(f.pagado, 0);
    });
  });

  group('el gasto por categoría', () {
    final cats = [
      categoria(1, 'Comida', tope: 5000),
      categoria(2, 'Casa'),
      categoria(3, 'Ahorro', tope: 100, cur: 'USD'),
    ];

    test('va de mayor a menor: es como uno se lo pregunta', () {
      final r = porCategoria(
        categorias: cats,
        gastosDelMes: [
          gasto('2026-09-01', 1000, cat: 1),
          gasto('2026-09-02', 3000, cat: 2),
        ],
        moneda: 'NIO',
      );

      expect(r.first.nombre, 'Casa');
      expect(r.first.total, 3000);
      expect(r[1].nombre, 'Comida');
    });

    test('una categoría con tope aparece aunque no se haya gastado nada', () {
      // Un tope sin gasto es información: "todavía no he tocado esa".
      final r = porCategoria(categorias: cats, gastosDelMes: const [], moneda: 'NIO');
      expect(r.map((x) => x.nombre), ['Comida']);
      expect(r.first.total, 0);
    });

    test('el tope de otra moneda no cuenta como tope de esta', () {
      final r = porCategoria(categorias: cats, gastosDelMes: const [], moneda: 'NIO');
      expect(r.map((x) => x.nombre), isNot(contains('Ahorro')));

      final enUsd = porCategoria(categorias: cats, gastosDelMes: const [], moneda: 'USD');
      expect(enUsd.map((x) => x.nombre), ['Ahorro']);
      expect(enUsd.first.topeEn('USD'), 100);
      expect(enUsd.first.topeEn('NIO'), isNull);
    });

    test('los gastos sin categoría se agrupan aparte', () {
      final r = porCategoria(
        categorias: cats,
        gastosDelMes: [gasto('2026-09-01', 700), gasto('2026-09-02', 300)],
        moneda: 'NIO',
      );
      final sin = r.firstWhere((x) => x.categoria == null);
      expect(sin.nombre, 'Sin categoría');
      expect(sin.total, 1000);
      expect(sin.cuantos, 2);
    });

    test('una categoría archivada no aparece', () {
      final r = porCategoria(
        categorias: [
          ExpenseCategory(
            id: 9,
            name: 'Vieja',
            budget: 100,
            currency: 'NIO',
            active: false,
            expenses: 3,
          ),
        ],
        gastosDelMes: const [],
        moneda: 'NIO',
      );
      expect(r, isEmpty);
    });
  });

  group('el mes', () {
    test('los días de cada mes, con año bisiesto', () {
      expect(diasDelMes('2026-02'), 28);
      expect(diasDelMes('2024-02'), 29);
      expect(diasDelMes('2026-04'), 30);
      expect(diasDelMes('2026-12'), 31);
    });

    test('cuánto ha pasado del mes en curso', () {
      // Es el número que hace útil el % del presupuesto: "llevo el 60%" no
      // dice nada hasta saber si va el 20% o el 90% del mes.
      expect(porcentajeDelMes('2026-09', '2026-09-15'), 50);
      expect(porcentajeDelMes('2026-09', '2026-09-30'), 100);
      expect(porcentajeDelMes('2026-09', '2026-09-01'), 3);
    });

    test('un mes que no es el de hoy ya está entero', () {
      expect(porcentajeDelMes('2026-08', '2026-09-15'), 100);
    });
  });
}
