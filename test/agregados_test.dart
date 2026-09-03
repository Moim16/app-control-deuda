// Lo que alimenta los gráficos. Un mes corrido de sitio no se nota a simple
// vista, así que se prueba.

import 'package:deudas_app/domain/agregados.dart';
import 'package:deudas_app/domain/models/entry.dart';
import 'package:flutter_test/flutter_test.dart';

Entry mov(String day, EntryKind kind, double amount, {String currency = 'NIO'}) => Entry(
      id: day.hashCode & 0xffff,
      debtId: 1,
      kind: kind,
      currency: currency,
      day: day,
      amount: amount,
      hasReceipt: false,
      commentCount: 0,
    );

const meses = ['2026-01', '2026-02', '2026-03'];

void main() {
  group('saldoAlCierre', () {
    test('es acumulado: dice cuánto se debía al final de cada mes', () {
      final r = saldoAlCierre([
        mov('2026-01-10', EntryKind.loan, 1000),
        mov('2026-02-05', EntryKind.payment, 300),
        mov('2026-03-20', EntryKind.loan, 500),
      ], meses);

      expect(r, [1000, 700, 1200]);
    });

    test('lo de antes del primer mes cuenta igual: es un saldo, no un flujo', () {
      final r = saldoAlCierre([
        mov('2025-11-01', EntryKind.loan, 800),
        mov('2026-02-01', EntryKind.payment, 800),
      ], meses);

      expect(r, [800, 0, 0]);
    });

    test('lo posterior al último mes no se cuela hacia atrás', () {
      final r = saldoAlCierre([
        mov('2026-01-10', EntryKind.loan, 100),
        mov('2026-08-10', EntryKind.loan, 900),
      ], meses);

      expect(r, [100, 100, 100]);
    });

    test('un abono de más deja el saldo negativo, no en cero', () {
      // Es un saldo a favor de verdad y el gráfico tiene que decirlo.
      final r = saldoAlCierre([
        mov('2026-01-10', EntryKind.loan, 100),
        mov('2026-02-10', EntryKind.payment, 250),
      ], meses);

      expect(r, [100, -150, -150]);
    });

    test('sin movimientos, todo en cero', () {
      expect(saldoAlCierre(const [], meses), [0, 0, 0]);
    });
  });

  group('flujoPorMes', () {
    test('reparte préstamos y abonos en su mes', () {
      final r = flujoPorMes([
        mov('2026-01-10', EntryKind.loan, 1000),
        mov('2026-01-25', EntryKind.loan, 200),
        mov('2026-02-05', EntryKind.payment, 300),
        mov('2026-03-01', EntryKind.payment, 100),
        mov('2026-03-15', EntryKind.loan, 50),
      ], meses);

      expect(r.prestado, [1200, 0, 50]);
      expect(r.abonado, [0, 300, 100]);
    });

    test('lo de fuera del rango no aparece en ningún mes', () {
      final r = flujoPorMes([
        mov('2025-12-31', EntryKind.loan, 999),
        mov('2026-04-01', EntryKind.loan, 999),
      ], meses);

      expect(r.prestado, [0, 0, 0]);
      expect(r.abonado, [0, 0, 0]);
    });

    test('sin movimientos, dos listas de ceros del largo de los meses', () {
      final r = flujoPorMes(const [], meses);
      expect(r.prestado, [0, 0, 0]);
      expect(r.abonado, [0, 0, 0]);
    });
  });
}
