// Cuándo toca cada mantenimiento. "Faltan 300 km" y "pasado por 300 km" son la
// misma cuenta con el signo cambiado, y eso es justo lo que se equivoca solo.

import 'package:deudas_app/domain/mantenimiento.dart';
import 'package:deudas_app/domain/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

const hoy = '2026-09-03';

Vehicle moto({int? km}) => Vehicle(
      id: 1,
      name: 'Mi moto',
      kind: VehicleKind.moto,
      active: true,
      odometer: km,
      services: 0,
      spent: const {},
    );

VehicleTask tarea({int id = 10, int? cadaKm, int? cadaMeses, String nombre = 'Aceite'}) =>
    VehicleTask(
      id: id,
      vehicleId: 1,
      name: nombre,
      everyKm: cadaKm,
      everyMonths: cadaMeses,
      active: true,
    );

Service servicio({
  int id = 100,
  required String dia,
  int? km,
  List<int> tareas = const [10],
  ServiceKind kind = ServiceKind.service,
}) =>
    Service(
      id: id,
      vehicleId: 1,
      kind: kind,
      taskIds: tareas,
      day: dia,
      odometer: km,
      title: 'Mantenimiento',
      currency: 'NIO',
      hasReceipt: false,
    );

EstadoTarea estado({
  required VehicleTask t,
  required Vehicle v,
  List<Service> servicios = const [],
}) =>
    estadoDeTarea(tarea: t, vehiculo: v, servicios: servicios, hoy: hoy);

void main() {
  group('por kilómetros', () {
    test('faltan los que faltan', () {
      final st = estado(
        t: tarea(cadaKm: 3000),
        v: moto(km: 12000),
        servicios: [servicio(dia: '2026-06-01', km: 10000)],
      );

      expect(st.kmFaltan, 1000, reason: '10000 + 3000 - 12000');
      expect(st.toca, isFalse);
      expect(st.porQue, PorQue.todavia);
    });

    test('pasado el intervalo, los km salen en negativo y ya toca', () {
      final st = estado(
        t: tarea(cadaKm: 3000),
        v: moto(km: 13500),
        servicios: [servicio(dia: '2026-06-01', km: 10000)],
      );

      expect(st.kmFaltan, -500);
      expect(st.toca, isTrue);
      expect(st.porQue, PorQue.km);
    });

    test('justo en el intervalo ya toca', () {
      final st = estado(
        t: tarea(cadaKm: 3000),
        v: moto(km: 13000),
        servicios: [servicio(dia: '2026-06-01', km: 10000)],
      );
      expect(st.kmFaltan, 0);
      expect(st.toca, isTrue);
    });

    test('sin kilometraje del vehículo no se inventa un número', () {
      // Decir "faltan 3,000 km" sin saber en cuántos va es inventar.
      final st = estado(
        t: tarea(cadaKm: 3000),
        v: moto(),
        servicios: [servicio(dia: '2026-06-01', km: 10000)],
      );
      expect(st.kmFaltan, isNull);
      expect(st.toca, isFalse);
    });

    test('sin kilometraje en el último servicio, tampoco', () {
      final st = estado(
        t: tarea(cadaKm: 3000),
        v: moto(km: 12000),
        servicios: [servicio(dia: '2026-06-01')],
      );
      expect(st.kmFaltan, isNull);
    });
  });

  group('por tiempo', () {
    test('cuenta los días hasta la próxima fecha', () {
      final st = estado(
        t: tarea(cadaMeses: 6),
        v: moto(),
        servicios: [servicio(dia: '2026-06-03')],
      );
      // 2026-06-03 + 6 meses = 2026-12-03; de hoy (2026-09-03) faltan 91 días.
      expect(st.diasFaltan, 91);
      expect(st.toca, isFalse);
    });

    test('pasada la fecha, ya toca', () {
      final st = estado(
        t: tarea(cadaMeses: 6),
        v: moto(),
        servicios: [servicio(dia: '2025-06-03')],
      );
      expect(st.diasFaltan, lessThan(0));
      expect(st.porQue, PorQue.fecha);
    });

    test('un servicio del día 31 no descuadra el intervalo', () {
      final st = estado(
        t: tarea(cadaMeses: 1),
        v: moto(),
        servicios: [servicio(dia: '2026-01-31')],
      );
      // Un mes después del 31 de enero es el 28 de febrero, no el 3 de marzo.
      expect(st.diasFaltan, DateTime.parse('2026-02-28').difference(DateTime.parse(hoy)).inDays);
    });
  });

  group('las dos cosas a la vez', () {
    test('manda la que llegue primero', () {
      // Los km ya se pasaron aunque falte tiempo: toca por km.
      final st = estado(
        t: tarea(cadaKm: 3000, cadaMeses: 6),
        v: moto(km: 14000),
        servicios: [servicio(dia: '2026-08-01', km: 10000)],
      );
      expect(st.porQue, PorQue.km);
      expect(st.toca, isTrue);
    });

    test('y al revés', () {
      final st = estado(
        t: tarea(cadaKm: 3000, cadaMeses: 6),
        v: moto(km: 10500),
        servicios: [servicio(dia: '2025-01-01', km: 10000)],
      );
      expect(st.porQue, PorQue.fecha);
    });
  });

  group('un servicio que cubre varias tareas', () {
    test('pone al día TODAS las que cubrió', () {
      // Es la razón de ser del módulo: en la casa comercial se paga un solo
      // monto por aceite, filtro y cadena.
      final servicios = [
        servicio(dia: '2026-08-01', km: 10000, tareas: [10, 11, 12]),
      ];
      for (final id in [10, 11, 12]) {
        final st = estado(
          t: tarea(id: id, cadaKm: 3000),
          v: moto(km: 10500),
          servicios: servicios,
        );
        expect(st.ultimo, isNotNull, reason: 'tarea $id');
        expect(st.kmFaltan, 2500);
      }
    });

    test('una tarea que ese servicio no cubrió sigue sin hacerse', () {
      final st = estado(
        t: tarea(id: 99, cadaKm: 3000),
        v: moto(km: 10500),
        servicios: [servicio(dia: '2026-08-01', km: 10000, tareas: [10, 11])],
      );
      expect(st.nunca, isTrue);
    });

    test('de varios servicios se toma el más reciente', () {
      final st = estado(
        t: tarea(cadaKm: 3000),
        v: moto(km: 13000),
        servicios: [
          servicio(id: 1, dia: '2026-01-01', km: 5000),
          servicio(id: 2, dia: '2026-08-01', km: 11000),
        ],
      );
      expect(st.ultimo!.id, 2);
      expect(st.kmFaltan, 1000);
    });

    test('con dos del mismo día manda el de id más alto: es el último anotado', () {
      final st = estado(
        t: tarea(cadaKm: 3000),
        v: moto(km: 13000),
        servicios: [
          servicio(id: 5, dia: '2026-08-01', km: 11000),
          servicio(id: 7, dia: '2026-08-01', km: 11500),
        ],
      );
      expect(st.ultimo!.id, 7);
    });
  });

  group('lo que nunca se ha hecho', () {
    test('toca, y es lo más urgente que hay', () {
      final st = estado(t: tarea(cadaKm: 3000), v: moto(km: 5000));
      expect(st.nunca, isTrue);
      expect(st.toca, isTrue);
      expect(st.urgencia, -1, reason: 'por delante de cualquier otra');
      expect(st.ultimo, isNull);
    });
  });

  group('el orden por urgencia', () {
    test('la fracción del intervalo manda, no los km sueltos', () {
      // 500 km de 3,000 aprieta más que 500 de 15,000, aunque sean los mismos
      // 500 km: es lo que hace comparables las dos escalas.
      final aceite = estado(
        t: tarea(id: 1, cadaKm: 3000),
        v: moto(km: 12500),
        servicios: [servicio(id: 1, dia: '2026-08-01', km: 10000, tareas: [1])],
      );
      final llantas = estado(
        t: tarea(id: 2, cadaKm: 15000),
        v: moto(km: 12500),
        servicios: [servicio(id: 2, dia: '2026-08-01', km: 10000, tareas: [2])],
      );

      expect(aceite.urgencia, lessThan(llantas.urgencia));
    });

    test('las tareas salen ordenadas, lo urgente primero', () {
      final v = moto(km: 13500);
      final servicios = [
        servicio(id: 1, dia: '2026-08-01', km: 10000, tareas: [1]),
        servicio(id: 2, dia: '2026-08-01', km: 10000, tareas: [2]),
      ];
      final lista = tareasOrdenadas(
        vehiculo: v,
        tareas: [
          tarea(id: 1, cadaKm: 3000, nombre: 'Aceite'), // pasado
          tarea(id: 2, cadaKm: 15000, nombre: 'Llantas'), // lejos
          tarea(id: 3, cadaKm: 8000, nombre: 'Cadena'), // nunca
        ],
        servicios: servicios,
        hoy: hoy,
      );

      expect(lista.map((x) => x.tarea.name), ['Cadena', 'Aceite', 'Llantas']);
    });
  });

  group('cómo se dice', () {
    String texto(EstadoTarea st) => textoDeTarea(
          st,
          numero: (n) => n.toString(),
          plural: (n, uno, varios) => '$n ${n == 1 ? uno : varios}',
        );

    test('lo que nunca se hizo', () {
      expect(texto(estado(t: tarea(cadaKm: 3000), v: moto(km: 100))),
          'Nunca se le ha hecho');
    });

    test('los km que faltan y los pasados', () {
      final falta = estado(
        t: tarea(cadaKm: 3000),
        v: moto(km: 12000),
        servicios: [servicio(dia: '2026-08-01', km: 10000)],
      );
      expect(texto(falta), 'faltan 1000 km');

      final pasado = estado(
        t: tarea(cadaKm: 3000),
        v: moto(km: 13500),
        servicios: [servicio(dia: '2026-08-01', km: 10000)],
      );
      expect(texto(pasado), '500 km pasados');
    });

    test('más allá de mes y medio se cuenta en meses, no en días', () {
      // "faltan 213 días" es peor que "faltan 7 meses".
      final st = estado(
        t: tarea(cadaMeses: 12),
        v: moto(),
        servicios: [servicio(dia: '2026-06-03')],
      );
      expect(texto(st), 'faltan 9 meses');
    });

    test('cerca sí se cuenta en días', () {
      final st = estado(
        t: tarea(cadaMeses: 3),
        v: moto(),
        servicios: [servicio(dia: '2026-06-15')],
      );
      expect(texto(st), 'faltan 12 días');
    });

    test('las dos cosas se dicen juntas', () {
      final st = estado(
        t: tarea(cadaKm: 3000, cadaMeses: 6),
        v: moto(km: 12000),
        servicios: [servicio(dia: '2026-08-01', km: 10000)],
      );
      expect(texto(st), contains('faltan 1000 km'));
      expect(texto(st), contains('·'));
    });

    test('una tarea sin intervalo lo dice', () {
      final st = estado(
        t: tarea(),
        v: moto(km: 12000),
        servicios: [servicio(dia: '2026-08-01', km: 10000)],
      );
      expect(texto(st), 'Sin intervalo');
    });
  });
}
