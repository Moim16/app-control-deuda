// Los días son texto "YYYY-MM-DD" en toda la app. Estas son las trampas del
// calendario que la app tiene que sortear.

import 'package:deudas_app/domain/dia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diaValido', () {
    test('un día normal pasa', () {
      expect(diaValido('2026-09-03'), isTrue);
      expect(diaValido('2024-02-29'), isTrue, reason: '2024 fue bisiesto');
    });

    test('el 30 de febrero NO pasa, aunque Dart lo acepte', () {
      // `DateTime.parse('2026-02-30')` no falla: devuelve el 2 de marzo. Sin la
      // ida y vuelta, se guardaría un día distinto del que se escribió.
      expect(DateTime.parse('2026-02-30').day, 2, reason: 'así se porta Dart');
      expect(diaValido('2026-02-30'), isFalse);
      expect(diaValido('2026-13-01'), isFalse);
      expect(diaValido('2025-02-29'), isFalse, reason: '2025 no fue bisiesto');
    });

    test('el formato tiene que ser exacto', () {
      for (final v in ['2026-9-3', '03/09/2026', 'ayer', '', '2026-09-03T10:00', null]) {
        expect(diaValido(v), isFalse, reason: 'con "$v"');
      }
    });
  });

  group('masDias', () {
    test('cruza el fin de mes y el fin de año', () {
      expect(masDias('2026-09-30', 1), '2026-10-01');
      expect(masDias('2026-12-31', 1), '2027-01-01');
      expect(masDias('2026-01-01', -1), '2025-12-31');
    });

    test('salta bien el 29 de febrero', () {
      expect(masDias('2024-02-28', 1), '2024-02-29');
      expect(masDias('2025-02-28', 1), '2025-03-01');
    });
  });

  group('masMeses', () {
    test('un mes normal', () {
      expect(masMeses('2026-01-15', 1), '2026-02-15');
      expect(masMeses('2026-11-15', 2), '2027-01-15');
    });

    test('un acuerdo del día 31 cae en el último día de los meses cortos', () {
      // Y no se salta al 3 de marzo, que es lo que haría sumar días.
      expect(masMeses('2026-01-31', 1), '2026-02-28');
      expect(masMeses('2024-01-31', 1), '2024-02-29');
      expect(masMeses('2026-01-31', 3), '2026-04-30');
    });

    test('el día 31 vuelve a ser 31 cuando el mes lo tiene', () {
      expect(masMeses('2026-01-31', 2), '2026-03-31');
    });

    test('hacia atrás cruza bien enero', () {
      // `d.month + n` se descuadraba aquí: enero menos un mes daba diciembre
      // del MISMO año, porque `~/` trunca hacia cero.
      expect(masMeses('2026-01-15', -1), '2025-12-15');
      expect(masMeses('2026-01-15', -13), '2024-12-15');
      expect(masMeses('2026-03-15', -12), '2025-03-15');
      expect(masMeses('2026-01-31', -11), '2025-02-28');
    });

    test('los últimos meses acaban en el de hoy', () {
      expect(ultimosMeses(3, hoy: '2026-01-15'), ['2025-11', '2025-12', '2026-01']);
      expect(ultimosMeses(1, hoy: '2026-09-03'), ['2026-09']);
      expect(ultimosMeses(12, hoy: '2026-09-03').first, '2025-10');
      expect(ultimosMeses(12, hoy: '2026-09-03').last, '2026-09');
    });

    test('muchos meses de golpe no se descuadran', () {
      expect(masMeses('2026-03-15', 12), '2027-03-15');
      expect(masMeses('2026-03-15', 25), '2028-04-15');
    });
  });

  test('diaDe rellena con ceros', () {
    expect(diaDe(DateTime(2026, 9, 3)), '2026-09-03');
    expect(diaDe(DateTime(2026, 12, 31)), '2026-12-31');
  });
}
