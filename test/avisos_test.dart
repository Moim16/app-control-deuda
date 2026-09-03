// Qué recordatorios se programan y cuándo. Es la razón de tener una app
// nativa, así que conviene que avise de lo que toca y no de lo que ya se pagó.

import 'package:deudas_app/domain/avisos.dart';
import 'package:deudas_app/domain/models/debt.dart';
import 'package:deudas_app/domain/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

const hoy = '2026-09-03';

String plataFalsa(num m, String c) => '${c == 'USD' ? 'US\$' : 'C\$'}${m.toStringAsFixed(0)}';
String fechaFalsa(String d) => d;

Debt deuda({
  int id = 1,
  String name = 'Mi hermano',
  DebtDirection direction = DebtDirection.owe,
  PaymentPlan? plan,
  String? ultimoPago,
  bool active = true,
  double saldo = 3500,
}) =>
    Debt(
      id: id,
      name: name,
      kind: DebtKind.person,
      currency: 'NIO',
      direction: direction,
      active: active,
      totals: {'NIO': Totals(loaned: 5000, paid: 5000 - saldo, balance: saldo)},
      currencies: const ['NIO'],
      entryCount: 3,
      plan: plan,
      lastPaymentDay: ultimoPago,
    );

List<Aviso> deDeudas(List<Debt> ds, {bool cobro = false}) => avisosDeDeudas(
      deudas: ds,
      hoy: hoy,
      esCobro: (_) => cobro,
      plata: plataFalsa,
      fecha: fechaFalsa,
    );

void main() {
  group('sin nada que recordar', () {
    test('una deuda sin acuerdo de pago no genera avisos', () {
      // No hay fecha: no hay nada que programar.
      expect(deDeudas([deuda()]), isEmpty);
    });

    test('una deuda cerrada tampoco', () {
      expect(
        deDeudas([
          deuda(
            active: false,
            plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-01-15'),
          ),
        ]),
        isEmpty,
      );
    });

    test('una deuda saldada tampoco: no hay nada que reclamar', () {
      expect(
        deDeudas([
          deuda(
            saldo: 0,
            plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-01-15'),
          ),
        ]),
        isEmpty,
      );
    });
  });

  group('el pago que viene', () {
    // Toca el 15; hoy es 3.
    final conPlan = deuda(
      plan: const PaymentPlan(every: DueEvery.monthly, amount: 1000, from: '2026-09-15'),
    );

    test('avisa tres días antes y el mismo día', () {
      final avisos = deDeudas([conPlan]);
      expect(avisos.map((a) => a.dia), ['2026-09-12', '2026-09-15']);
    });

    test('el aviso del día lo dice con el monto', () {
      final delDia = deDeudas([conPlan]).last;
      expect(delDia.titulo, contains('Mi hermano'));
      expect(delDia.cuerpo, contains('C\$1000'));
    });

    test('si faltan menos de tres días, solo queda el del día', () {
      final avisos = deDeudas([
        deuda(
          plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-09-04'),
        ),
      ]);
      // El "tres días antes" ya pasó: programarlo para atrás no sirve.
      expect(avisos.map((a) => a.dia), ['2026-09-04']);
    });

    test('el que toca hoy se avisa hoy', () {
      final avisos = deDeudas([
        deuda(
          plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: hoy),
        ),
      ]);
      expect(avisos.single.dia, hoy);
      expect(avisos.single.titulo, contains('Hoy'));
    });
  });

  group('el pago atrasado', () {
    final atrasada = deuda(
      plan: const PaymentPlan(every: DueEvery.monthly, amount: 1000, from: '2026-07-15'),
    );

    test('se recuerda HOY, no en la fecha que ya pasó', () {
      final avisos = deDeudas([atrasada]);
      expect(avisos.single.dia, hoy);
      expect(avisos.single.titulo, contains('atrasado'));
    });

    test('dice cuántos días lleva', () {
      expect(deDeudas([atrasada]).single.cuerpo, contains('días'));
    });

    test('y entonces no se programa además el que viene', () {
      // Uno solo por deuda: repetir lo mismo dos veces es ruido.
      expect(deDeudas([atrasada]).length, 1);
    });
  });

  group('un cobro se cuenta al revés', () {
    final cobro = deuda(
      direction: DebtDirection.owed,
      name: 'Carlos',
      plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-09-15'),
    );

    test('el que viene dice que te pagan', () {
      final a = deDeudas([cobro], cobro: true).last;
      expect(a.titulo, contains('cobrar'));
      expect(a.titulo, isNot(contains('toca el pago')));
    });

    test('el atrasado dice que te deben', () {
      final a = deDeudas([
        deuda(
          direction: DebtDirection.owed,
          name: 'Carlos',
          plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-06-15'),
        ),
      ], cobro: true).single;
      expect(a.titulo, 'Carlos te debe un pago');
    });
  });

  group('los ids', () {
    test('son estables: reprogramar reemplaza, no duplica', () {
      final d = deuda(
        plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-09-15'),
      );
      final a = deDeudas([d]).map((x) => x.id).toList();
      final b = deDeudas([d]).map((x) => x.id).toList();
      expect(a, b);
    });

    test('los dos avisos de la misma deuda no se pisan', () {
      final avisos = deDeudas([
        deuda(
          plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-09-15'),
        ),
      ]);
      expect(avisos[0].id, isNot(avisos[1].id));
    });

    test('dos deudas distintas tampoco', () {
      final avisos = deDeudas([
        deuda(id: 1, plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-09-15')),
        deuda(id: 2, plan: const PaymentPlan(every: DueEvery.monthly, amount: 500, from: '2026-09-15')),
      ]);
      expect(avisos.map((a) => a.id).toSet().length, avisos.length);
    });

    test('caben en un int de 32 bits, que es lo que usa Android', () {
      final avisos = deDeudas([
        deuda(id: 99999, plan: const PaymentPlan(every: DueEvery.monthly, amount: 5, from: '2026-09-15')),
      ]);
      for (final a in avisos) {
        expect(a.id, lessThan(2147483647));
        expect(a.id, greaterThan(0));
      }
    });
  });

  group('el vehículo', () {
    Vehicle moto({int? km}) => Vehicle(
          id: 1,
          name: 'Mi moto',
          kind: VehicleKind.moto,
          active: true,
          odometer: km,
          services: 1,
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

    Service servicio(String dia, {int? km, List<int> tareas = const [10]}) => Service(
          id: 100,
          vehicleId: 1,
          kind: ServiceKind.service,
          taskIds: tareas,
          day: dia,
          odometer: km,
          title: 'Mantenimiento',
          currency: 'NIO',
          hasReceipt: false,
        );

    VehicleData datos({
      required List<VehicleTask> tareas,
      List<Service> servicios = const [],
      int? km,
    }) =>
        VehicleData(
          today: hoy,
          vehicles: [moto(km: km)],
          tasks: tareas,
          services: servicios,
        );

    test('lo que ya se pasó por fecha se recuerda hoy', () {
      final avisos = avisosDeVehiculos(
        data: datos(
          tareas: [tarea(cadaMeses: 6)],
          servicios: [servicio('2025-06-03')],
        ),
        hoy: hoy,
      );
      expect(avisos.single.dia, hoy);
      expect(avisos.single.titulo, contains('Mi moto'));
      expect(avisos.single.cuerpo, contains('atraso'));
    });

    test('lo que viene se avisa una semana antes', () {
      // 2026-06-03 + 6 meses = 2026-12-03; una semana antes es el 2026-11-26.
      final avisos = avisosDeVehiculos(
        data: datos(
          tareas: [tarea(cadaMeses: 6)],
          servicios: [servicio('2026-06-03')],
        ),
        hoy: hoy,
      );
      expect(avisos.single.dia, '2026-11-26');
    });

    test('lo que toca SOLO por kilómetros no se programa', () {
      // No tiene fecha: depende de cuánto se ande, así que ponerle una sería
      // adivinar. Eso se ve al abrir la app.
      final avisos = avisosDeVehiculos(
        data: datos(
          tareas: [tarea(cadaKm: 3000)],
          servicios: [servicio('2026-08-01', km: 10000)],
          km: 13500,
        ),
        hoy: hoy,
      );
      expect(avisos, isEmpty);
    });

    test('una tarea que nunca se ha hecho no genera aviso con fecha', () {
      // "Nunca" no tiene día al que programar; se ve al abrir la app.
      final avisos = avisosDeVehiculos(
        data: datos(tareas: [tarea(cadaMeses: 6)]),
        hoy: hoy,
      );
      expect(avisos, isEmpty);
    });

    test('un vehículo archivado no avisa', () {
      final data = VehicleData(
        today: hoy,
        vehicles: [
          Vehicle(
            id: 1,
            name: 'La vieja',
            kind: VehicleKind.moto,
            active: false,
            services: 1,
            spent: const {},
          ),
        ],
        tasks: [tarea(cadaMeses: 6)],
        services: [servicio('2025-01-01')],
      );
      expect(avisosDeVehiculos(data: data, hoy: hoy), isEmpty);
    });
  });
}
