// Command: el estado de un botón que llama a la red.
//
// La prueba que importa es la última: un ViewModel que NO reenvía los avisos de
// su comando deja la pantalla sin repintar, y entonces un error no se ve nunca.
// Eso pasó de verdad — un login con la contraseña mala no decía nada — y esto
// es lo que lo habría cazado.

import 'dart:async';

import 'package:deudas_app/utils/command.dart';
import 'package:deudas_app/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Command0', () {
    test('mientras corre lo dice, y al acabar deja de decirlo', () async {
      final espera = Completer<void>();
      final c = Command0<int>(() async {
        await espera.future;
        return const Ok(1);
      });

      expect(c.running, isFalse);
      final futuro = c.run();
      expect(c.running, isTrue);
      espera.complete();
      await futuro;
      expect(c.running, isFalse);
    });

    test('guarda el error para poder mostrarlo', () async {
      final c = Command0<int>(() async => const Err('No se pudo.'));
      await c.run();
      expect(c.errorMessage, 'No se pudo.');
      expect(c.error?.sessionExpired, isFalse);
    });

    test('el doble toque no dispara dos veces', () async {
      var veces = 0;
      final espera = Completer<void>();
      final c = Command0<int>(() async {
        veces++;
        await espera.future;
        return const Ok(1);
      });

      final a = c.run();
      final b = c.run(); // el segundo toque, mientras el primero corre
      espera.complete();
      await Future.wait([a, b]);
      expect(veces, 1);
    });

    test('un intento nuevo limpia el error del anterior', () async {
      var falla = true;
      final c = Command0<int>(() async => falla ? const Err('mal') : const Ok(1));
      await c.run();
      expect(c.errorMessage, 'mal');
      falla = false;
      await c.run();
      expect(c.errorMessage, isNull);
    });

    test('clearError borra el mensaje cuando ya se corrigió lo que estaba mal', () async {
      final c = Command0<int>(() async => const Err('mal'));
      await c.run();
      c.clearError();
      expect(c.errorMessage, isNull);
    });

    test('avisa al empezar y al acabar', () async {
      final c = Command0<int>(() async => const Ok(1));
      var avisos = 0;
      c.addListener(() => avisos++);
      await c.run();
      // Dos: "empecé" (para pintar la ruedita) y "acabé".
      expect(avisos, 2);
    });
  });

  group('Command1', () {
    test('pasa el argumento y guarda el error', () async {
      String? visto;
      final c = Command1<int, String>((arg) async {
        visto = arg;
        return const Err('nope');
      });
      await c.run('hola');
      expect(visto, 'hola');
      expect(c.errorMessage, 'nope');
    });

    test('la sesión vencida se distingue de un error cualquiera', () async {
      final c = Command1<int, String>(
        (_) async => const Err('Sesión vencida.', sessionExpired: true),
      );
      await c.run('x');
      expect(c.error?.sessionExpired, isTrue);
    });
  });

  group('reenviar los avisos al ViewModel', () {
    test('sin reenviarlos, el ViewModel no se entera de que el comando falló', () async {
      final vm = _FalsoVmSinReenviar();
      var repintados = 0;
      vm.addListener(() => repintados++);

      await vm.guardar.run();

      expect(vm.guardar.errorMessage, 'mal');
      // Este es el bug: el comando sabe que falló, pero nadie repinta, así que
      // el error no llega nunca a la pantalla.
      expect(repintados, 0);
    });

    test('reenviándolos, sí', () async {
      final vm = _FalsoVm();
      var repintados = 0;
      vm.addListener(() => repintados++);

      await vm.guardar.run();

      expect(vm.guardar.errorMessage, 'mal');
      expect(repintados, greaterThan(0));
    });
  });
}

/// Como estaban todos los ViewModel antes: el comando avisa a sus oyentes y el
/// ViewModel no reenvía nada.
class _FalsoVmSinReenviar extends ChangeNotifier {
  final guardar = Command0<void>(() async => const Err<void>('mal'));
}

/// Como quedaron: el `..addListener(notifyListeners)` es la línea que arregla el
/// login que no decía nada.
class _FalsoVm extends ChangeNotifier {
  _FalsoVm() {
    guardar = Command0<void>(() async => const Err<void>('mal'))
      ..addListener(notifyListeners);
  }

  late final Command0<void> guardar;
}
