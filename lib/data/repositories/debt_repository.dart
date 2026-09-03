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
import '../../domain/models/entry.dart';
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
        _summary = AccountSummary.fromJson(await _api.get('/api/summary'));
        notifyListeners();
        return _summary!;
      },
      alMensaje: _mensaje,
      esSesionVencida: _vencida,
    );
  }

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

  Future<Result<void>> addEntry({
    required int debtId,
    required EntryKind kind,
    required String day,
    required num amount,
    required String currency,
    String? reason,
    String? note,
    String? receipt,
  }) =>
      Result.guard<void>(
        () async {
          await _api.post('/api/entries', {
            'debtId': debtId,
            'kind': kind.wire,
            'day': day,
            'amount': amount,
            'currency': currency,
            if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            if (receipt != null) 'receipt': receipt,
          });
          // El saldo cambio: lo que hay en memoria ya no vale.
          _invalidate(debtId);
          await loadSummary(force: true);
        },
        alMensaje: _mensaje,
        esSesionVencida: _vencida,
      );

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
