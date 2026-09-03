// El estado de la ficha de una deuda: sus movimientos, su moneda y su hilo de
// comentarios.

import 'package:flutter/foundation.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../domain/models/comment.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/entry.dart';
import '../../../domain/pago_esperado.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

/// Qué se está viendo de la deuda.
enum DebtTab { movimientos, comentarios }

/// El filtro de la lista de movimientos.
enum EntryFilter { todos, prestamos, abonos }

class DebtViewModel extends ChangeNotifier {
  DebtViewModel({required DebtRepository debts, required this.debtId}) : _debts = debts {
    load = Command0<List<Entry>>(_load);
    reload = Command0<List<Entry>>(() => _load(force: true));
    comment = Command1<Comment, String>(_comment);
    _debts.addListener(notifyListeners);
  }

  final DebtRepository _debts;
  final int debtId;

  late final Command0<List<Entry>> load;
  late final Command0<List<Entry>> reload;
  late final Command1<Comment, String> comment;

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

  Future<Result<Comment>> _comment(String texto) async {
    final r = await _debts.addComment(debtId, texto);
    if (r case Ok<Comment>(:final value)) {
      _comments = [..._comments, value];
      notifyListeners();
    }
    return r;
  }

  Future<void> deleteComment(int id) async {
    final r = await _debts.deleteComment(id, debtId: debtId);
    if (r.isOk) {
      _comments = _comments.where((c) => c.id != id).toList();
      notifyListeners();
    }
  }

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

  @override
  void dispose() {
    _debts.removeListener(notifyListeners);
    load.dispose();
    reload.dispose();
    comment.dispose();
    super.dispose();
  }
}
