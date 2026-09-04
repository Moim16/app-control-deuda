// =============================================================================
//  Los recordatorios: si están activados, a qué hora, y mantenerlos al día.
//
//  La preferencia se guarda en el TELÉFONO: son notificaciones de este aparato.
//
//  Se reprograma todo cada vez que cambian los datos (`sincronizar`), porque un
//  abono registrado puede mover la fecha del próximo pago y un mantenimiento
//  anotado pone al día tres tareas de un golpe. Es barato: cancelar y volver a
//  poner una docena de avisos no cuesta nada, y no se descuadra nunca.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/avisos.dart';
import '../../domain/models/debt.dart';
import '../services/avisos_service.dart';

class AvisosRepository extends ChangeNotifier {
  AvisosRepository({required AvisosService service}) : _service = service;

  final AvisosService _service;

  static const _kActivo = 'dd_avisos';
  static const _kHora = 'dd_avisos_hora';

  bool _activo = false;
  bool get activo => _activo;

  /// La hora del día a la que llegan. Ocho de la mañana: temprano para poder
  /// hacer algo ese día, y no de madrugada.
  int _hora = 8;
  int get hora => _hora;

  int _puestos = 0;

  /// Cuántos avisos quedaron programados. Se dice en Ajustes: prometer
  /// recordatorios sin que la persona sepa si funcionan no sirve.
  int get puestos => _puestos;

  bool _permiso = false;

  /// Si Android los tiene permitidos. Se puede haber quitado desde los ajustes
  /// del sistema, y entonces hay que decirlo.
  bool get permiso => _permiso;

  Future<void> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      _activo = p.getBool(_kActivo) ?? false;
      _hora = p.getInt(_kHora) ?? 8;
    } catch (_) {
      // Sin preferencias guardadas se queda apagado, que es lo prudente.
    }
    if (_activo) {
      _permiso = await _service.tienePermiso();
      _puestos = await _service.cuantosPuestos();
    }
    notifyListeners();
  }

  /// Activa los avisos. Pide el permiso si hace falta y devuelve si quedó.
  Future<bool> activar() async {
    _permiso = await _service.tienePermiso();
    if (!_permiso) _permiso = await _service.pedirPermiso();
    if (!_permiso) {
      notifyListeners();
      return false;
    }
    _activo = true;
    await _guardar();
    notifyListeners();
    return true;
  }

  Future<void> desactivar() async {
    _activo = false;
    _puestos = 0;
    await _guardar();
    await _service.cancelarTodo();
    notifyListeners();
  }

  Future<void> cambiarHora(int h) async {
    if (_hora == h) return;
    _hora = h;
    await _guardar();
    notifyListeners();
  }

  /// Vuelve a poner todos los avisos con los datos de ahora. Se llama cada vez
  /// que cambian las deudas.
  ///
  /// Con los avisos apagados no hace nada: ni siquiera calcula.
  Future<void> sincronizar({
    required List<Debt> deudas,
    required String hoy,
    required bool Function(Debt) esCobro,
    required String Function(num monto, String moneda) plata,
    required String Function(String dia) fecha,
  }) async {
    if (!_activo) return;

    _permiso = await _service.tienePermiso();
    if (!_permiso) {
      // Se lo quitaron desde el sistema: no se insiste, se refleja y ya.
      _puestos = 0;
      notifyListeners();
      return;
    }

    final avisos = avisosDeDeudas(
      deudas: deudas,
      hoy: hoy,
      esCobro: esCobro,
      plata: plata,
      fecha: fecha,
    );

    _puestos = await _service.reprogramar(avisos, hora: _hora);
    notifyListeners();
  }

  Future<void> _guardar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kActivo, _activo);
      await p.setInt(_kHora, _hora);
    } catch (_) {
      // Se queda puesto en esta sesión aunque no se haya podido guardar.
    }
  }
}
