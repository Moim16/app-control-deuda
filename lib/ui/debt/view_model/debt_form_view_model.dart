// El estado del formulario de una deuda: crearla, editarla, cerrarla o
// borrarla.

import 'package:flutter/foundation.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/debt_draft.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class DebtFormViewModel extends ChangeNotifier {
  DebtFormViewModel({
    required DebtRepository debts,
    required DebtDraft inicial,
    this.debt,
  })  : _debts = debts,
        _draft = inicial {
    guardar = Command0<Debt?>(_guardar)..addListener(notifyListeners);
    borrar = Command0<void>(_borrar)..addListener(notifyListeners);
  }

  final DebtRepository _debts;

  /// La deuda que se edita, o null si es nueva.
  final Debt? debt;

  /// Devuelve la deuda cuando es nueva, para poder abrirla enseguida.
  late final Command0<Debt?> guardar;
  late final Command0<void> borrar;

  DebtDraft _draft;
  DebtDraft get draft => _draft;

  /// La deuda recien creada. `Command` solo guarda el error, no el valor, y
  /// quien abrio el formulario necesita la deuda para abrirla enseguida.
  Debt? _creada;
  Debt? get debtCreada => _creada;

  bool get esNueva => debt == null;

  /// Cuántos movimientos se perderían al borrar. Se dice en el aviso: no es lo
  /// mismo borrar una deuda vacía que una con cuarenta préstamos.
  int get movimientos => debt?.entryCount ?? 0;

  String? get problema => _draft.problema;
  bool get puedeGuardar => _draft.esValido;

  void cambiarDireccion(DebtDirection d) => _set(_draft.copyWith(direction: d));
  void cambiarNombre(String v) => _set(_draft.copyWith(name: v));
  void cambiarTipo(DebtKind k) => _set(_draft.copyWith(kind: k));
  void cambiarMoneda(String c) => _set(_draft.copyWith(currency: c));
  void cambiarContraparte(String v) => _set(_draft.copyWith(counterpart: v));
  void cambiarNota(String v) => _set(_draft.copyWith(note: v));
  void cambiarInteres(String v) => _set(_draft.copyWith(interestRate: v));
  void cambiarCuota(String v) => _set(_draft.copyWith(dueAmount: v));
  void cambiarDesde(String d) => _set(_draft.copyWith(dueFrom: d));
  void cambiarAbierta(bool v) => _set(_draft.copyWith(active: v));

  /// null quita el acuerdo de pago.
  void cambiarFrecuencia(DueEvery? e) => _set(
        e == null ? _draft.copyWith(borrarAcuerdo: true) : _draft.copyWith(dueEvery: e),
      );

  void _set(DebtDraft d) {
    _draft = d;
    guardar.clearError();
    notifyListeners();
  }

  Future<Result<Debt?>> _guardar() async {
    final mal = problema;
    if (mal != null) return Err<Debt?>(mal);
    if (esNueva) {
      final r = await _debts.createDebt(_draft);
      if (r case Ok<Debt>(:final value)) _creada = value;
      return switch (r) {
        Ok<Debt>(:final value) => Ok<Debt?>(value),
        Err<Debt>(:final message, :final sessionExpired) =>
          Err<Debt?>(message, sessionExpired: sessionExpired),
      };
    }
    final r = await _debts.updateDebt(debt!.id, _draft);
    return switch (r) {
      Ok<void>() => const Ok<Debt?>(null),
      Err<void>(:final message, :final sessionExpired) =>
        Err<Debt?>(message, sessionExpired: sessionExpired),
    };
  }

  Future<Result<void>> _borrar() =>
      esNueva ? Future.value(const Ok<void>(null)) : _debts.deleteDebt(debt!.id);

  @override
  void dispose() {
    guardar.dispose();
    borrar.dispose();
    super.dispose();
  }
}
