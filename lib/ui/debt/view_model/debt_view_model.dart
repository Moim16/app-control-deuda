// El estado de la ficha de una deuda: sus movimientos, su moneda y su hilo de
// comentarios.

import 'package:flutter/foundation.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../domain/dia.dart';
import '../../../domain/models/comment.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/entry.dart';
import '../../../domain/pago_esperado.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

/// Qué se está viendo de la deuda.
enum DebtTab { movimientos, graficos, comentarios }

/// El filtro de la lista de movimientos.
enum EntryFilter { todos, prestamos, abonos }

class DebtViewModel extends ChangeNotifier {
  DebtViewModel({required DebtRepository debts, required this.debtId}) : _debts = debts {
    load = Command0<List<Entry>>(_load)..addListener(notifyListeners);
    reload = Command0<List<Entry>>(() => _load(force: true))..addListener(notifyListeners);
    _debts.addListener(notifyListeners);
  }

  final DebtRepository _debts;
  final int debtId;

  late final Command0<List<Entry>> load;
  late final Command0<List<Entry>> reload;

  List<Entry> _entries = const [];
  List<Entry> get allEntries => _entries;

  List<Comment> _comments = const [];
  List<Comment> get comments => _comments;

  DebtTab _tab = DebtTab.movimientos;
  DebtTab get tab => _tab;

  EntryFilter _filter = EntryFilter.todos;
  EntryFilter get filter => _filter;

  String? _currency;

  /// La deuda tal como la trajo el resumen. Si aún no está cargado, null.
  Debt? get debt => _debts.summary?.byId(debtId);

  /// La moneda que se está mirando (una deuda puede estar en dos).
  String get currency => debt?.currencyToShow(_currency) ?? 'NIO';

  /// Hoy segun el servidor. Es el tope y el valor por defecto de la fecha de un
  /// movimiento, asi que no puede salir del reloj del telefono.
  String? get hoy => _debts.summary?.today;

  PagoEsperado? get pago {
    final d = debt;
    final hoy = _debts.summary?.today;
    return (d == null || hoy == null) ? null : proximoPago(d, hoy);
  }

  Future<Result<List<Entry>>> _load({bool force = false}) async {
    final r = await _debts.entries(debtId, force: force);
    if (r case Ok<List<Entry>>(:final value)) _entries = value;
    // Los comentarios generales se piden con los movimientos: son parte de la
    // misma ficha y así la pestaña no tarda al abrirse.
    final c = await _debts.comments(debtId);
    if (c case Ok<List<Comment>>(:final value)) _comments = value;
    notifyListeners();
    return r;
  }

  /* -------------------------------- el hilo de UN movimiento -------------- */

  /// Los comentarios de un movimiento. Se piden al abrir su detalle y no con la
  /// lista: son de ese movimiento y casi nunca se miran todos.
  Future<Result<List<Comment>>> commentsOf(int entryId) =>
      _debts.comments(debtId, entryId: entryId);

  /// Escribe en el hilo de un movimiento. Al volver se recarga todo: el
  /// contador que se ve en la fila del movimiento tiene que subir.
  Future<Result<Comment>> commentOn(int entryId, String texto) async {
    final r = await _debts.addComment(debtId, texto, entryId: entryId);
    if (r.isOk) await _load(force: true);
    return r;
  }

  /// Escribe en el hilo de la deuda en general.
  Future<Result<Comment>> comentar(String texto) async {
    final r = await _debts.addComment(debtId, texto);
    if (r case Ok<Comment>(:final value)) {
      _comments = [..._comments, value];
      notifyListeners();
    }
    return r;
  }

  /// Borra un comentario, sea de la deuda o de un movimiento. Se recarga en vez
  /// de quitarlo de la lista a mano: si era de un movimiento, tambien cambia su
  /// contador.
  Future<Result<void>> borrarComentario(int id) async {
    final r = await _debts.deleteComment(id, debtId: debtId);
    if (r.isOk) await _load(force: true);
    return r;
  }

  /// Borra un movimiento. El saldo lo recalcula el servidor; aqui solo se tira
  /// lo que habia en memoria.
  Future<Result<void>> borrarMovimiento(int entryId) async {
    final r = await _debts.deleteEntry(entryId, debtId: debtId);
    if (r.isOk) await _load(force: true);
    return r;
  }

  /// Se llama despues de registrar o corregir: el repositorio ya invalido su
  /// cache, pero esta pantalla necesita la lista nueva.
  Future<void> refrescar() => _load(force: true);

  void showTab(DebtTab t) {
    if (_tab == t) return;
    _tab = t;
    notifyListeners();
  }

  void showFilter(EntryFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  void showCurrency(String c) {
    if (_currency == c) return;
    _currency = c;
    notifyListeners();
  }

  /// Los movimientos que se ven con el filtro puesto, del más nuevo al más
  /// viejo (como los manda la API).
  List<Entry> get entries => switch (_filter) {
        EntryFilter.todos => _entries,
        EntryFilter.prestamos => _entries.where((e) => e.isLoan).toList(),
        EntryFilter.abonos => _entries.where((e) => !e.isLoan).toList(),
      };

  /// El saldo justo después de cada movimiento, llevado POR MONEDA: así la
  /// lista cuenta la historia sin que nadie tenga que sumar de cabeza.
  Map<int, double> get runningBalance {
    final ordenados = [..._entries]..sort((a, b) {
        final porDia = a.day.compareTo(b.day);
        return porDia != 0 ? porDia : a.id.compareTo(b.id);
      });
    final saldo = <String, double>{};
    final out = <int, double>{};
    for (final e in ordenados) {
      saldo[e.currency] = (saldo[e.currency] ?? 0) + e.signed;
      out[e.id] = (saldo[e.currency]! * 100).round() / 100;
    }
    return out;
  }

  Future<Result<String>> receipt(int entryId) => _debts.receipt(entryId);

  /* -------------------------------------------------------------- graficos -- */

  /// Los meses del grafico: los ultimos doce, acabando en el de hoy.
  List<String> get meses => ultimosMeses(12, hoy: hoy ?? '');

  /// Los movimientos de la moneda que se esta mirando. No se mezclan monedas
  /// en un grafico: dos monedas son dos graficos.
  List<Entry> get deLaMoneda => _entries.where((e) => e.currency == currency).toList();

  @override
  void dispose() {
    _debts.removeListener(notifyListeners);
    load.dispose();
    reload.dispose();
    super.dispose();
  }
}
