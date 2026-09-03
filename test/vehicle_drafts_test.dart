// Los formularios del vehículo: qué se puede guardar y qué se manda.

import 'package:deudas_app/domain/models/vehicle.dart';
import 'package:deudas_app/domain/models/vehicle_drafts.dart';
import 'package:flutter_test/flutter_test.dart';

const hoy = '2026-09-03';

void main() {
  group('el vehículo', () {
    test('solo hace falta el nombre', () {
      expect(const VehicleDraft(name: 'Mi moto').problema, isNull);
      expect(const VehicleDraft().problema, 'Ponle un nombre al vehículo.');
    });

    test('el año, si se pone, tiene que ser un año', () {
      expect(const VehicleDraft(name: 'X', year: '2020').problema, isNull);
      expect(const VehicleDraft(name: 'X', year: '').problema, isNull);
      expect(const VehicleDraft(name: 'X', year: '1800').problema, 'El año no es válido.');
      expect(const VehicleDraft(name: 'X', year: 'ayer').problema, 'El año no es válido.');
    });

    test('al crear no se manda `active`', () {
      expect(const VehicleDraft(name: 'X').aJson(nuevo: true).containsKey('active'), isFalse);
      expect(const VehicleDraft(name: 'X').aJson(nuevo: false)['active'], isTrue);
    });
  });

  group('una tarea', () {
    TaskDraft d({String name = 'Aceite', String km = '', String meses = ''}) =>
        TaskDraft(vehicleId: 1, name: name, everyKm: km, everyMonths: meses);

    test('se guarda sin intervalos, pero se avisa', () {
      // Una tarea sin intervalo existe igual; lo que no se puede es avisar.
      expect(d().problema, isNull);
      expect(d().sinIntervalo, isTrue);
      expect(d(km: '3000').sinIntervalo, isFalse);
    });

    test('los intervalos tienen que ser enteros positivos', () {
      expect(d(km: '3000', meses: '6').problema, isNull);
      expect(d(km: '0').problema, 'Los kilómetros deben ser un número entero.');
      expect(d(meses: '-1').problema, 'Los meses deben ser un número entero.');
    });

    test('la coma de los miles no estorba', () {
      expect(d(km: '3,000').km, 3000);
    });

    test('al crear se manda el vehículo; al editar, no', () {
      expect(d().aJson(nueva: true)['vehicleId'], 1);
      expect(d().aJson(nueva: false).containsKey('vehicleId'), isFalse);
    });
  });

  group('un servicio', () {
    ServiceDraft d({
      String title = 'Mantenimiento',
      String cost = '',
      String odometer = '',
      String day = hoy,
      ServiceKind kind = ServiceKind.service,
      List<int> tareas = const [],
    }) =>
        ServiceDraft(
          vehicleId: 1,
          day: day,
          title: title,
          cost: cost,
          odometer: odometer,
          kind: kind,
          taskIds: tareas,
        );

    test('hace falta decir qué se le hizo', () {
      expect(d().problema(hoy: hoy), isNull);
      expect(d(title: '').problema(hoy: hoy), 'Escribe qué se le hizo.');
    });

    test('el costo es opcional: pudo ser en garantía', () {
      expect(d().monto, isNull);
      expect(d().problema(hoy: hoy), isNull);
      expect(d(cost: '1,500.50').monto, 1500.5);
      expect(d(cost: 'gratis').problema(hoy: hoy), 'El costo no es válido.');
    });

    test('el kilometraje es opcional pero tiene que ser entero', () {
      expect(d(odometer: '').km, isNull);
      expect(d(odometer: '12,500').km, 12500);
      expect(
        d(odometer: '12.5').problema(hoy: hoy),
        'El kilometraje debe ser un número entero.',
      );
    });

    test('no se anota un servicio de pasado mañana', () {
      expect(d(day: '2026-09-05').problema(hoy: hoy), 'Esa fecha todavía no llega.');
    });

    group('las tareas que cubre', () {
      test('se marcan y se desmarcan', () {
        var x = d();
        x = x.alternarTarea(5);
        x = x.alternarTarea(7);
        expect(x.taskIds, [5, 7]);
        x = x.alternarTarea(5);
        expect(x.taskIds, [7]);
      });

      test('un accesorio no cubre ninguna, aunque estuvieran marcadas', () {
        // Un accesorio no es algo que haya que repetir.
        final x = d(tareas: [1, 2]).copyWith(kind: ServiceKind.accessory);
        expect(x.taskIds, isEmpty);
        expect(x.esAccesorio, isTrue);
      });

      test('van en el cuerpo tal cual, para que el servidor las reemplace', () {
        expect(d(tareas: [3, 4]).aJson(nuevo: true)['taskIds'], [3, 4]);
        expect(d().aJson(nuevo: false)['taskIds'], isEmpty);
      });
    });

    group('el enlace con el gasto del hogar', () {
      test('la categoría se manda solo al crear', () {
        // El PUT del servidor no acepta `categoryId`: mueve el gasto enlazado
        // por su cuenta, y mandarla otra vez crearía un gasto duplicado.
        final x = d().copyWith(categoryId: 2);
        expect(x.aJson(nuevo: true)['categoryId'], 2);
        expect(x.aJson(nuevo: false).containsKey('categoryId'), isFalse);
      });

      test('sin categoría se manda en vacío', () {
        expect(d().aJson(nuevo: true)['categoryId'], '');
      });

      test('se puede quitar después de haberla puesto', () {
        final x = d().copyWith(categoryId: 2).copyWith(sinCategoria: true);
        expect(x.categoryId, isNull);
      });
    });

    test('al abrir uno que existe se trae todo menos la categoría', () {
      final s = Service(
        id: 9,
        vehicleId: 1,
        kind: ServiceKind.service,
        taskIds: const [3, 4],
        expenseId: 55,
        day: '2026-08-01',
        odometer: 11000,
        title: 'Mantenimiento de los 11 mil',
        cost: 2500,
        currency: 'NIO',
        place: 'La casa comercial',
        hasReceipt: true,
      );
      final x = ServiceDraft.de(s);

      expect(x.title, 'Mantenimiento de los 11 mil');
      expect(x.taskIds, [3, 4]);
      expect(x.cost, '2500');
      expect(x.odometer, '11000');
      expect(x.place, 'La casa comercial');
      expect(x.receipt, isA<FacturaIgual>());
      // Ni se propone: el gasto ya existe y el servidor lo mueve solo.
      expect(x.categoryId, isNull);
    });

    test('un servicio en garantía abre el formulario con el costo vacío', () {
      final s = Service(
        id: 9,
        vehicleId: 1,
        kind: ServiceKind.service,
        taskIds: const [],
        day: '2026-08-01',
        title: 'Cambio bajo garantía',
        currency: 'NIO',
        hasReceipt: false,
      );
      expect(ServiceDraft.de(s).cost, '');
      expect(ServiceDraft.de(s).monto, isNull);
    });

    test('la factura distingue no tocarla, quitarla y cambiarla', () {
      expect(d().aJson(nuevo: false).containsKey('receipt'), isFalse);
      expect(
        d().copyWith(receipt: const FacturaQuitada()).aJson(nuevo: false)['receipt'],
        isNull,
      );
      expect(
        d().copyWith(receipt: const FacturaNueva('data:image/jpeg;base64,AA'))
            .aJson(nuevo: false)['receipt'],
        'data:image/jpeg;base64,AA',
      );
    });
  });
}
