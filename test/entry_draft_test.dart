// Las reglas de qué es un movimiento que se puede mandar.
//
// La API las comprueba también — nunca se confía en el cliente — pero estas son
// las que dan el mensaje al instante, así que tienen que decir lo mismo.

import 'package:deudas_app/domain/models/entry.dart';
import 'package:deudas_app/domain/models/entry_draft.dart';
import 'package:flutter_test/flutter_test.dart';

const hoy = '2026-09-03';

EntryDraft borrador({
  String amount = '1000',
  String day = hoy,
  String currency = 'NIO',
  String reason = '',
  String note = '',
}) =>
    EntryDraft(
      kind: EntryKind.loan,
      day: day,
      amount: amount,
      currency: currency,
      reason: reason,
      note: note,
    );

void main() {
  group('el monto', () {
    test('lee lo escrito con coma de miles, que es como se escribe aquí', () {
      expect(borrador(amount: '3,500.50').monto, 3500.5);
      expect(borrador(amount: ' 120 ').monto, 120);
    });

    test('redondea a dos decimales, como la API', () {
      expect(borrador(amount: '10.555').monto, 10.56);
    });

    test('cero, negativo, vacío y letras no son montos', () {
      for (final v in ['0', '0.00', '-5', '', '   ', 'abc', '1.2.3']) {
        expect(borrador(amount: v).monto, isNull, reason: 'con "$v"');
      }
    });

    test('un monto imposible no pasa', () {
      expect(borrador(amount: '9999999999').monto, isNull);
    });

    test('sin monto, el problema es el monto', () {
      expect(borrador(amount: '').problema(hoy: hoy), 'El monto debe ser mayor que cero.');
    });
  });

  group('la fecha', () {
    test('hoy y el pasado se pueden registrar', () {
      expect(borrador(day: hoy).problema(hoy: hoy), isNull);
      expect(borrador(day: '2024-01-15').problema(hoy: hoy), isNull);
    });

    test('mañana también: quien registra de noche puede anotar el de mañana', () {
      expect(borrador(day: '2026-09-04').problema(hoy: hoy), isNull);
    });

    test('pasado mañana ya no', () {
      expect(borrador(day: '2026-09-05').problema(hoy: hoy), 'Esa fecha todavía no llega.');
    });

    test('el día de más cruza bien el fin de mes', () {
      expect(borrador(day: '2026-10-01').problema(hoy: '2026-09-30'), isNull);
      expect(borrador(day: '2026-10-02').problema(hoy: '2026-09-30'), isNotNull);
    });

    test('una fecha que no existe no pasa', () {
      for (final d in ['2026-02-30', '2026-13-01', 'ayer', '2026-9-3']) {
        expect(borrador(day: d).problema(hoy: hoy), isNotNull, reason: 'con "$d"');
      }
    });
  });

  group('el resto', () {
    test('solo córdobas y dólares', () {
      expect(borrador(currency: 'USD').problema(hoy: hoy), isNull);
      expect(borrador(currency: 'EUR').problema(hoy: hoy), 'Moneda inválida.');
    });

    test('el motivo y la nota tienen tope, igual que en la API', () {
      expect(borrador(reason: 'x' * 120).problema(hoy: hoy), isNull);
      expect(borrador(reason: 'x' * 121).problema(hoy: hoy), 'El motivo es muy largo.');
      expect(borrador(note: 'x' * 500).problema(hoy: hoy), isNull);
      expect(borrador(note: 'x' * 501).problema(hoy: hoy), 'La nota es muy larga.');
    });
  });

  group('el comprobante', () {
    test('un movimiento nuevo no toca nada mientras no se elija una imagen', () {
      expect(borrador().receipt, isA<ComprobanteIgual>());
    });

    test('quitar y poner son cosas distintas', () {
      expect(
        borrador().copyWith(receipt: const ComprobanteQuitado()).receipt,
        isA<ComprobanteQuitado>(),
      );
      expect(
        borrador().copyWith(receipt: const ComprobanteNuevo('data:image/jpeg;base64,AA')).receipt,
        isA<ComprobanteNuevo>(),
      );
    });
  });

  group('al abrir un movimiento que ya existe', () {
    Entry existente({double amount = 3500, String? reason, String? note}) => Entry(
          id: 7,
          debtId: 1,
          kind: EntryKind.payment,
          currency: 'USD',
          day: '2026-08-01',
          amount: amount,
          reason: reason,
          note: note,
          hasReceipt: true,
          commentCount: 0,
        );

    test('el formulario arranca con lo que ya estaba', () {
      final d = EntryDraft.de(existente(reason: 'Abono de agosto'));
      expect(d.kind, EntryKind.payment);
      expect(d.day, '2026-08-01');
      expect(d.currency, 'USD');
      expect(d.reason, 'Abono de agosto');
      expect(d.monto, 3500);
    });

    test('un monto redondo se escribe sin decimales, y con ellos si los tiene', () {
      expect(EntryDraft.de(existente(amount: 3500)).amount, '3500');
      expect(EntryDraft.de(existente(amount: 3500.5)).amount, '3500.50');
    });

    test('el comprobante que ya tiene no se toca hasta que se pida', () {
      expect(EntryDraft.de(existente()).receipt, isA<ComprobanteIgual>());
    });

    test('un motivo vacío llega como texto vacío, no como "null"', () {
      final d = EntryDraft.de(existente());
      expect(d.reason, '');
      expect(d.note, '');
    });
  });
}
