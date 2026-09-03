// =============================================================================
//  Las deudas: a esto le pregunta la UI.
//
//  Guarda en memoria lo ultimo que trajo, asi que abrir una deuda y volver al
//  resumen no vuelve a pedir todo. Cuando algo cambia (se registra un abono, se
//  escribe un comentario) invalida lo que ya no vale.
//
//  Aqui NO se calculan saldos: llegan hechos de la API. Si la app los volviera
//  a calcular por su cuenta, un dia diria algo distinto a la web y habria que
//  averiguar cual de las dos miente.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../domain/models/comment.dart';
import '../../domain/models/debt.dart';
import '../../domain/models/debt_draft.dart';
import '../../domain/models/entry.dart';
import '../../domain/models/entry_draft.dart';
import '../../domain/models/summary.dart';
import '../../utils/result.dart';
import '../services/api_client.dart';

class DebtRepository extends ChangeNotifier {
  DebtRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  AccountSummary? _summary;
  AccountSummary? get summary => _summary;

  /// Los movimientos ya pedidos, por deuda.
  final Map<int, List<Entry>> _entries = {};

  /* -------------------------------------------------------------- resumen -- */

  Future<Result<AccountSummary>> loadSummary({bool force = false}) async {
    if (_summary != null && !force) return Ok(_summary!);
    return Result.guard<AccountSummary>(
      () async {
        // `all=1` trae tambien las cerradas: la app tiene que poder verlas y
        // reabrirlas, no solo las abiertas. Son pocas y vienen en la misma
        // llamada, asi que no cuesta nada.
        _summary = AccountSummary.fromJson(await _api.get('/api/summary?all=1'));
        notifyListeners();
        return _summary!;
      },
      alMensaje: _mensaje,
      esSesionVencida: _vencida,
    );
  }

  /* ---------------------------------------------------------------- deudas -- */

  /// Crea la deuda y devuelve la nueva, para poder abrirla enseguida.
  ///
  /// Aqui NO se pide monto: una deuda nace con un nombre y se va llenando de
  /// prestamos. El saldo lo calcula el servidor a partir de ellos.
  Future<Result<Debt>> createDebt(DebtDraft d) => Result.guard<Debt>(
        () async {
          final j = await _api.post('/api/debts', d.aJson(nueva: true));
          final debt = Debt.fromJson(j['debt'] as Map<String, dynamic>);
          await loadSummary(force: true);
          return debt;
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  Future<Result<void>> updateDebt(int debtId, DebtDraft d) => Result.guard<void>(
        () async {
          await _api.put('/api/debts?id=$debtId', d.aJson(nueva: false));
          _invalidate(debtId);
          await loadSummary(force: true);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Cierra o reabre la deuda. Cerrar no borra nada: la saca de la lista de
  /// abiertas y ahi queda su historial.
  Future<Result<void>> setDebtActive(int debtId, {required bool active}) =>
      Result.guard<void>(
        () async {
          await _api.put('/api/debts?id=$debtId', {'active': active});
          await loadSummary(force: true);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Borra la deuda con todo su historial. Sin vuelta atras: quien solo quiere
  /// dejar de verla, la cierra.
  Future<Result<void>> deleteDebt(int debtId) => Result.guard<void>(
        () async {
          await _api.delete('/api/debts?id=$debtId&hard=1');
          _entries.remove(debtId);
          await loadSummary(force: true);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /* ---------------------------------------------------------- movimientos -- */

  Future<Result<List<Entry>>> entries(int debtId, {bool force = false}) async {
    final cache = _entries[debtId];
    if (cache != null && !force) return Ok(cache);
    return Result.guard<List<Entry>>(
      () async {
        final j = await _api.get('/api/entries?debtId=$debtId');
        final list =
            (j['entries'] as List).map((e) => Entry.fromJson(e as Map<String, dynamic>)).toList();
        _entries[debtId] = list;
        notifyListeners();
        return list;
      },
      alMensaje: _mensaje,
      esSesionVencida: _vencida,
    );
  }

  /// El comprobante de un movimiento (data URI JPEG). No se guarda en memoria:
  /// son cientos de KB y se ven una vez.
  Future<Result<String>> receipt(int entryId) => Result.guard<String>(
        () async => (await _api.get('/api/entries?id=$entryId&receipt=1'))['image'] as String,
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Registra un movimiento. El cuerpo se arma desde el borrador para que la
  /// pantalla no tenga que saber como se llaman los campos en la API.
  Future<Result<void>> addEntry(int debtId, EntryDraft d) => Result.guard<void>(
        () async {
          await _api.post('/api/entries', {
            'debtId': debtId,
            'kind': d.kind.wire,
            'day': d.day,
            'amount': d.monto,
            'currency': d.currency,
            ..._opcionales(d),
          });
          // El saldo cambio: lo que hay en memoria ya no vale.
          _invalidate(debtId);
          await loadSummary(force: true);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Corrige un movimiento ya registrado.
  Future<Result<void>> updateEntry(int entryId, {required int debtId, required EntryDraft d}) =>
      Result.guard<void>(
        () async {
          await _api.put('/api/entries?id=$entryId', {
            'kind': d.kind.wire,
            'day': d.day,
            'amount': d.monto,
            'currency': d.currency,
            // Al editar, el motivo y la nota van SIEMPRE, incluso vacios: es la
            // forma de borrar lo que decia antes.
            'reason': d.reason.trim(),
            'note': d.note.trim(),
            ..._comprobante(d),
          });
          _invalidate(debtId);
          await loadSummary(force: true);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Borra el movimiento, su comprobante y sus comentarios.
  Future<Result<void>> deleteEntry(int entryId, {required int debtId}) => Result.guard<void>(
        () async {
          await _api.delete('/api/entries?id=$entryId');
          _invalidate(debtId);
          await loadSummary(force: true);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /// Al registrar, un campo vacio se deja fuera: la API ya guarda null.
  static Map<String, Object?> _opcionales(EntryDraft d) => {
        if (d.reason.trim().isNotEmpty) 'reason': d.reason.trim(),
        if (d.note.trim().isNotEmpty) 'note': d.note.trim(),
        ..._comprobante(d),
      };

  /// La API distingue tres cosas: la clave ausente no toca el comprobante, en
  /// null lo borra, y con un data URI lo reemplaza.
  static Map<String, Object?> _comprobante(EntryDraft d) => switch (d.receipt) {
        ComprobanteIgual() => const {},
        ComprobanteQuitado() => const {'receipt': null},
        ComprobanteNuevo(:final dataUri) => {'receipt': dataUri},
      };

  /* --------------------------------------------------------- comentarios -- */

  Future<Result<List<Comment>>> comments(int debtId, {int? entryId, bool all = false}) =>
      Result.guard<List<Comment>>(
        () async {
          final q = all ? '&entryId=0' : (entryId == null ? '' : '&entryId=$entryId');
          final j = await _api.get('/api/comments?debtId=$debtId$q');
          return (j['comments'] as List)
              .map((c) => Comment.fromJson(c as Map<String, dynamic>))
              .toList();
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  Future<Result<Comment>> addComment(int debtId, String text, {int? entryId}) =>
      Result.guard<Comment>(
        () async {
          final j = await _api.post('/api/comments', {
            'debtId': debtId,
            'text': text.trim(),
            if (entryId != null) 'entryId': entryId,
          });
          // El contador de comentarios del movimiento cambio.
          _invalidate(debtId);
          return Comment.fromJson(j['comment'] as Map<String, dynamic>);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  Future<Result<void>> deleteComment(int id, {required int debtId}) => Result.guard<void>(
        () async {
          await _api.delete('/api/comments?id=$id');
          _invalidate(debtId);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

  /* ------------------------------------------------------------------------ */

  void _invalidate(int debtId) {
    _entries.remove(debtId);
    notifyListeners();
  }

  /// Al salir de la sesion no puede quedar nada de la cuenta anterior en
  /// memoria: el siguiente que entre veria datos que no son suyos.
  void clear() {
    _summary = null;
    _entries.clear();
    notifyListeners();
  }

  static String _mensaje(Object e) =>
      e is ApiException ? e.message : 'Algo salió mal. Intenta de nuevo.';

  static bool _vencida(Object e) => e is ApiException && e.sessionExpired;
}
