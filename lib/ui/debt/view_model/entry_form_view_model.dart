// =============================================================================
//  El estado del formulario de un movimiento: registrar uno nuevo o corregir
//  uno que ya está.
//
//  El borrador vive aquí y no en el `State` del widget porque hay que decidir
//  cosas con él (si se puede guardar, qué está mal, si el comprobante se toca)
//  y eso no es trabajo de la pantalla. Lo que sí se queda en el widget son los
//  `TextEditingController`, que son de la caja de texto y de nadie más.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../data/services/comprobante.dart';
import '../../../domain/models/entry.dart';
import '../../../domain/models/entry_draft.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class EntryFormViewModel extends ChangeNotifier {
  EntryFormViewModel({
    required DebtRepository debts,
    required ComprobanteService comprobantes,
    required this.debtId,
    required this.hoy,
    required EntryDraft inicial,
    this.entry,
  })  : _debts = debts,
        _comprobantes = comprobantes,
        _draft = inicial,
        _teniaComprobante = entry?.hasReceipt ?? false {
    guardar = Command0<void>(_guardar);
  }

  final DebtRepository _debts;
  final ComprobanteService _comprobantes;
  final int debtId;

  /// Hoy según el servidor: es el tope de la fecha y el valor por defecto.
  final String hoy;

  /// El movimiento que se está corrigiendo, o null si es nuevo.
  final Entry? entry;

  final bool _teniaComprobante;

  late final Command0<void> guardar;

  EntryDraft _draft;
  EntryDraft get draft => _draft;

  bool get esNuevo => entry == null;

  /// La imagen elegida en esta sesión del formulario, para la miniatura.
  String? _elegida;

  /// El comprobante que el movimiento ya tenía, para no editar a ciegas.
  String? _actual;

  /// Lo que hay que pintar: lo nuevo si se eligió algo, si no lo que ya había.
  String? get comprobante => _elegida ?? (tendraComprobante ? _actual : null);

  bool _buscandoImagen = false;
  bool get buscandoImagen => _buscandoImagen;

  /// El error de elegir la imagen, que no es el de guardar.
  String? _errorImagen;
  String? get errorImagen => _errorImagen;

  /// Si al guardar habrá un comprobante. Sirve para el texto del botón: no es
  /// lo mismo "agregar" que "reemplazar".
  bool get tendraComprobante => switch (_draft.receipt) {
        ComprobanteNuevo() => true,
        ComprobanteQuitado() => false,
        ComprobanteIgual() => _teniaComprobante,
      };

  /// Si ya se puede tocar el botón de guardar.
  bool get puedeGuardar => _draft.esValido(hoy: hoy);

  /// Qué está mal, para mostrarlo cuando se intenta guardar de todos modos.
  String? get problema => _draft.problema(hoy: hoy);

  /// Trae el comprobante que ya estaba guardado. Se pide aparte porque son
  /// cientos de KB y no vienen en la lista de movimientos.
  Future<void> cargarComprobanteActual() async {
    if (!_teniaComprobante) return;
    final r = await _debts.receipt(entry!.id);
    if (r case Ok<String>(:final value)) {
      _actual = value;
      notifyListeners();
    }
  }

  /* --------------------------------------------------------------- cambios -- */

  void cambiarKind(EntryKind k) => _set(_draft.copyWith(kind: k));
  void cambiarDia(String d) => _set(_draft.copyWith(day: d));
  void cambiarMoneda(String c) => _set(_draft.copyWith(currency: c));
  void cambiarMonto(String v) => _set(_draft.copyWith(amount: v));
  void cambiarMotivo(String v) => _set(_draft.copyWith(reason: v));
  void cambiarNota(String v) => _set(_draft.copyWith(note: v));

  /// Abre la cámara o la galería y deja la imagen lista para subir.
  Future<void> elegirComprobante(Origen origen) async {
    if (_buscandoImagen) return;
    _buscandoImagen = true;
    _errorImagen = null;
    notifyListeners();
    try {
      final uri = await _comprobantes.elegir(origen);
      // null = se canceló: no es un error y no se toca lo que ya había.
      if (uri != null) {
        _elegida = uri;
        _draft = _draft.copyWith(receipt: ComprobanteNuevo(uri));
      }
    } on ComprobanteError catch (e) {
      _errorImagen = e.message;
    } catch (_) {
      _errorImagen = 'No se pudo preparar la imagen.';
    }
    _buscandoImagen = false;
    notifyListeners();
  }

  void quitarComprobante() {
    _elegida = null;
    _set(_draft.copyWith(receipt: const ComprobanteQuitado()));
  }

  void _set(EntryDraft d) {
    _draft = d;
    // Un error de la vez anterior no puede quedarse en pantalla mientras la
    // persona corrige justo eso.
    guardar.clearError();
    notifyListeners();
  }

  /* -------------------------------------------------------------- guardar -- */

  Future<Result<void>> _guardar() async {
    final mal = problema;
    if (mal != null) return Err<void>(mal);
    return esNuevo
        ? _debts.addEntry(debtId, _draft)
        : _debts.updateEntry(entry!.id, debtId: debtId, d: _draft);
  }

  @override
  void dispose() {
    guardar.dispose();
    super.dispose();
  }
}
