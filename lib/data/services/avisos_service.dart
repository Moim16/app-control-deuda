// =============================================================================
//  Lo único que sabe del sistema de notificaciones.
//
//  Son notificaciones LOCALES programadas: la app le dice a Android "muestra
//  esto el 15 a las 8", y Android lo hace aunque la app esté cerrada, sin
//  internet y sin gastar batería esperando.
//
//  Se REPROGRAMA todo de una vez, no se van tocando una por una: cambiar un
//  acuerdo de pago mueve varias fechas a la vez, y calcular el diferencial
//  sería trabajo para equivocarse. Cancelar todo y volver a poner lo que toca
//  es lo mismo y no se descuadra nunca.
//
//  Al reprogramar, los ids son ESTABLES (los pone `domain/avisos.dart`), así
//  que un aviso que sigue siendo el mismo se reemplaza en vez de duplicarse.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/avisos.dart';

class AvisosService {
  AvisosService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// La zona en la que se programan: la de Nicaragua, la misma con la que el
  /// servidor decide qué día es hoy. Con la del teléfono, alguien de viaje
  /// recibiría el aviso del pago un día antes o después.
  static const _zona = 'America/Managua';

  /// Un solo canal: son todos la misma clase de aviso, y Android deja que la
  /// persona lo silencie desde los ajustes del sistema si le estorba.
  static const _canal = AndroidNotificationChannel(
    'recordatorios',
    'Recordatorios',
    description: 'Cuándo toca un pago o un mantenimiento.',
    importance: Importance.defaultImportance,
  );

  bool _listo = false;
  late tz.Location _location;

  Future<void> init() async {
    if (_listo) return;
    tzdata.initializeTimeZones();
    _location = tz.getLocation(_zona);

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);
    _listo = true;
  }

  /// Pide el permiso de notificaciones (Android 13+ lo exige) y dice si quedó
  /// concedido. En versiones anteriores no hay nada que pedir.
  Future<bool> pedirPermiso() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  Future<bool> tienePermiso() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  /// Borra lo programado y pone estos avisos. `hora` es la hora del día a la
  /// que se muestran (8 = ocho de la mañana).
  ///
  /// Devuelve cuántos quedaron puestos.
  Future<int> reprogramar(List<Aviso> avisos, {required int hora}) async {
    await init();
    await _plugin.cancelAll();

    final ahora = tz.TZDateTime.now(_location);
    var puestos = 0;

    for (final a in avisos) {
      final dia = DateTime.tryParse(a.dia);
      if (dia == null) continue;

      var cuando = tz.TZDateTime(_location, dia.year, dia.month, dia.day, hora);
      // Un aviso de hoy cuya hora ya pasó no se puede programar para atrás. Se
      // manda en un minuto: es lo que uno espera al activarlos y ver que ya hay
      // algo atrasado.
      if (!cuando.isAfter(ahora)) {
        if (a.dia != _hoyEnZona(ahora)) continue;
        cuando = ahora.add(const Duration(minutes: 1));
      }

      try {
        await _plugin.zonedSchedule(
          a.id,
          a.titulo,
          a.cuerpo,
          cuando,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _canal.id,
              _canal.name,
              channelDescription: _canal.description,
              // El cuerpo puede pasar de una línea; así se ve entero al
              // desplegar la notificación.
              styleInformation: BigTextStyleInformation(a.cuerpo),
            ),
          ),
          // Inexacto a propósito: una alarma exacta pide un permiso especial en
          // Android 12+, y para "avisar por la mañana" da igual que llegue a
          // las 8:00 o a las 8:20. `allowWhileIdle` es lo que hace que llegue
          // aunque el teléfono esté en reposo.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Solo aplica en iOS, pero el paquete lo exige igual. Se interpreta
          // como hora del calendario, que es lo que ya se calculo arriba.
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        puestos++;
      } catch (e) {
        // Un aviso que el sistema rechaza no puede tumbar los demás.
        debugPrint('No se pudo programar el aviso ${a.id}: $e');
      }
    }
    return puestos;
  }

  Future<void> cancelarTodo() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Los que están puestos ahora mismo. Sirve para poder decirlo en Ajustes en
  /// vez de prometer avisos y que la persona no sepa si funcionan.
  Future<int> cuantosPuestos() async {
    await init();
    final pendientes = await _plugin.pendingNotificationRequests();
    return pendientes.length;
  }

  static String _hoyEnZona(tz.TZDateTime ahora) =>
      '${ahora.year.toString().padLeft(4, '0')}-'
      '${ahora.month.toString().padLeft(2, '0')}-'
      '${ahora.day.toString().padLeft(2, '0')}';
}
