// Los formularios de gastos: qué se puede guardar y qué se manda a la API.

import 'package:deudas_app/domain/models/spend.dart';
import 'package:deudas_app/domain/models/spend_drafts.dart';
import 'package:flutter_test/flutter_test.dart';

const hoy = '2026-09-03';

void main() {
  group('un gasto', () {
    ExpenseDraft d({
      String amount = '500',
      String day = hoy,
      int? cat,
      String reason = '',
    }) =>
        ExpenseDraft(amount: amount, day: day, categoryId: cat, reason: reason);

    test('con monto y fecha ya se puede guardar, sin categoría', () {
      // Anotar el gasto importa más que clasificarlo: siempre se puede
      // arreglar después.
      expect(d().problema(hoy: hoy), isNull);
      expect(d().categoryId, isNull);
    });

    test('el monto tiene que ser un monto', () {
      for (final v in ['', '0', '-5', 'mucho']) {
        expect(d(amount: v).problema(hoy: hoy), 'El monto debe ser mayor que cero.',
            reason: 'con "$v"');
      }
      expect(d(amount: '1,250.75').monto, 1250.75);
    });

    test('no se anota un gasto de pasado mañana', () {
      expect(d(day: '2026-09-04').problema(hoy: hoy), isNull);
      expect(d(day: '2026-09-05').problema(hoy: hoy), 'Esa fecha todavía no llega.');
    });

    test('el motivo tiene el tope de la API', () {
      expect(d(reason: 'x' * 120).problema(hoy: hoy), isNull);
      expect(d(reason: 'x' * 121).problema(hoy: hoy), 'El motivo es muy largo.');
    });

    group('lo que se manda', () {
      test('al anotar, los campos vacíos se dejan fuera', () {
        final j = d().aJson(nuevo: true);
        expect(j.containsKey('reason'), isFalse);
        expect(j.containsKey('note'), isFalse);
      });

      test('al corregir van siempre, para poder borrarlos', () {
        final j = d().aJson(nuevo: false);
        expect(j['reason'], '');
        expect(j['note'], '');
      });

      test('sin categoría se manda en vacío, que es lo que la API entiende', () {
        expect(d().aJson(nuevo: true)['categoryId'], '');
        expect(d(cat: 4).aJson(nuevo: true)['categoryId'], 4);
      });

      test('la captura distingue no tocarla, quitarla y cambiarla', () {
        expect(d().aJson(nuevo: false).containsKey('receipt'), isFalse);
        expect(
          d().copyWith(receipt: const CapturaQuitada()).aJson(nuevo: false)['receipt'],
          isNull,
        );
        expect(
          d().copyWith(receipt: const CapturaNueva('data:image/jpeg;base64,AA'))
              .aJson(nuevo: false)['receipt'],
          'data:image/jpeg;base64,AA',
        );
      });
    });

    test('al abrir uno que ya existe se trae todo', () {
      final e = Expense(
        id: 5,
        categoryId: 2,
        day: '2026-08-10',
        amount: 1250.5,
        currency: 'USD',
        reason: 'Súper',
        note: 'de la quincena',
        hasReceipt: true,
      );
      final x = ExpenseDraft.de(e);
      expect(x.amount, '1250.50');
      expect(x.categoryId, 2);
      expect(x.currency, 'USD');
      expect(x.reason, 'Súper');
      expect(x.receipt, isA<CapturaIgual>());
    });

    test('quitar la categoría de un gasto que la tenía', () {
      final x = ExpenseDraft(day: hoy, amount: '100', categoryId: 3)
          .copyWith(sinCategoria: true);
      expect(x.categoryId, isNull);
    });
  });

  group('una categoría', () {
    test('solo hace falta el nombre: el tope es opcional', () {
      expect(const CategoryDraft(name: 'Comida').problema, isNull);
      expect(const CategoryDraft(name: 'Comida').tope, isNull);
    });

    test('sin nombre no se crea', () {
      expect(const CategoryDraft().problema, 'Ponle un nombre a la categoría.');
      expect(const CategoryDraft(name: '   ').problema, 'Ponle un nombre a la categoría.');
    });

    test('un tope mal escrito se dice', () {
      expect(
        const CategoryDraft(name: 'Comida', budget: '0').problema,
        'El presupuesto debe ser mayor que cero.',
      );
      expect(const CategoryDraft(name: 'Comida', budget: '5,000').tope, 5000);
    });

    test('al crear no se manda `active`: nace en uso', () {
      final j = const CategoryDraft(name: 'Comida').aJson(nueva: true);
      expect(j.containsKey('active'), isFalse);
      expect(const CategoryDraft(name: 'X').aJson(nueva: false)['active'], isTrue);
    });

    test('al abrir una que existe, un tope redondo se escribe sin decimales', () {
      final c = ExpenseCategory(
        id: 1,
        name: 'Comida',
        budget: 5000,
        currency: 'NIO',
        active: true,
        expenses: 7,
      );
      expect(CategoryDraft.de(c).budget, '5000');
    });
  });

  group('un ingreso', () {
    test('el sueldo puede empezar a regir el mes que viene', () {
      // Un aumento ya acordado se anota antes de que llegue.
      const d = IncomeDraft(amount: '14000', day: '2026-10-01');
      expect(d.problema(hoy: hoy), isNull);
    });

    test('uno de una sola vez no puede ser del futuro: todavía no entró', () {
      const d = IncomeDraft(
        kind: IncomeKind.once,
        amount: '8000',
        day: '2026-10-01',
      );
      expect(d.problema(hoy: hoy), 'Esa fecha todavía no llega.');
    });

    test('sin fecha válida, el mensaje del sueldo es distinto', () {
      expect(
        const IncomeDraft(amount: '100', day: 'nunca').problema(hoy: hoy),
        'Indica desde cuándo ganas eso.',
      );
      expect(
        const IncomeDraft(kind: IncomeKind.once, amount: '100', day: 'nunca')
            .problema(hoy: hoy),
        'La fecha no es válida.',
      );
    });

    test('el monto es obligatorio', () {
      expect(
        const IncomeDraft(amount: '', day: hoy).problema(hoy: hoy),
        'El monto debe ser mayor que cero.',
      );
    });

    test('lo que se manda lleva el tipo en el nombre que espera la API', () {
      expect(const IncomeDraft(amount: '1', day: hoy).aJson()['kind'], 'monthly');
      expect(
        const IncomeDraft(kind: IncomeKind.once, amount: '1', day: hoy).aJson()['kind'],
        'once',
      );
    });
  });
}
