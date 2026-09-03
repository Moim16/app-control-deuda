// El formato de los montos: la regla de no mezclar monedas se ve aquí.

import 'package:deudas_app/ui/core/formato.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('montos', () {
    test('el símbolo va pegado al monto de SU moneda', () {
      expect(plata(3500, 'NIO'), 'C\$3,500');
      expect(plata(250, 'USD'), 'US\$250');
    });

    test('sin decimales cuando el monto es redondo', () {
      expect(plata(1200, 'NIO'), 'C\$1,200');
      expect(plata(1200.5, 'NIO'), 'C\$1,200.5');
    });

    test('un negativo lleva el signo delante del símbolo', () {
      expect(plata(-500, 'NIO'), '-C\$500');
    });

    test('los centavos que no llegan a un centavo se muestran como cero', () {
      expect(plata(0.001, 'NIO'), 'C\$0');
    });

    test('compacto para los ejes de un gráfico', () {
      // A partir de 10.000 se redondea: en un eje, "13k" se lee mejor que
      // "12.9k" y la diferencia no cambia nada.
      expect(compacto(12900), '13k');
      expect(compacto(8500), '8.5k');
      expect(compacto(1500000), '1.5M');
      expect(compacto(850), '850');
    });

    test('el porcentaje no se pasa de 100 aunque uno abone de más', () {
      expect(porcentaje(120, 100), 100);
      expect(porcentaje(50, 200), 25);
      // Sin nada prestado no hay porcentaje que calcular: cero, no infinito.
      expect(porcentaje(50, 0), 0);
    });
  });

  group('fechas', () {
    test('sin el punto de la abreviatura', () {
      expect(fecha('2026-09-03'), '3 sept');
      expect(fecha('2026-09-03', conAno: true), '3 sept 2026');
    });

    test('una fecha vacía o inválida no revienta', () {
      expect(fecha(null), '—');
      expect(fecha(''), '—');
      expect(fecha('no-es-fecha'), '—');
    });
  });

  group('plural', () {
    test('uno y varios', () {
      expect(plural(1, 'día', 'días'), '1 día');
      expect(plural(3, 'día', 'días'), '3 días');
      expect(plural(0, 'día', 'días'), '0 días');
    });
  });
}
