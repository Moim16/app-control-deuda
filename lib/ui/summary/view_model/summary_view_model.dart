// =============================================================================
//  El estado del Resumen: qué lado se mira, en qué moneda, y los totales.
//
//  Aquí no se calcula ningún saldo: los totales por deuda llegan hechos de la
//  API. Lo único que hace este ViewModel es SUMAR los de la moneda que se está
//  mirando, y nunca entre monedas distintas.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/summary.dart';
import '../../../domain/pago_esperado.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class SummaryViewModel extends ChangeNotifier {
  SummaryViewModel({required DebtRepository debts}) : _debts = debts {
    load = Command0<AccountSummary>(_load);
    refresh = Command0<AccountSummary>(() => _load(force: true));
    _debts.addListener(notifyListeners);
  }

  final DebtRepository _debts;

  late final Command0<AccountSummary> load;
  late final Command0<AccountSummary> refresh;

  AccountSummary? get summary => _debts.summary;

  /// El lado que se mira: la DIRECCIÓN del dato, no cómo se llama para quien
  /// mira (de eso se encarga `ladoDe`).
  DebtDirection _side = DebtDirection.owe;
  DebtDirection get side => _side;

  String? _currency;
  String? get currency => _currency;

  Future<Result<AccountSummary>> _load({bool force = false}) async {
    final r = await _debts.loadSummary(force: force);
    if (r case Ok<AccountSummary>()) _acomodar();
    return r;
  }

  /// Deja el lado y la moneda en algo que exista: si no debo nada pero me
  /// deben, abre en "Me deben"; y la moneda, la que tenga más deudas.
  void _acomodar() {
    final s = summary;
    if (s == null) return;

    if (s.openOn(_side).isEmpty && s.openOn(_side.flipped).isNotEmpty) {
      _side = _side.flipped;
      _currency = null;
    }

    final cuenta = <String, int>{};
    for (final d in s.openOn(_side)) {
      for (final c in d.currencies) {
        cuenta[c] = (cuenta[c] ?? 0) + 1;
      }
    }
    if (cuenta.isEmpty) {
      _currency = 'NIO';
      return;
    }
    if (_currency == null || !cuenta.containsKey(_currency)) {
      final orden = cuenta.keys.toList()
        ..sort((a, b) {
          final porCuenta = cuenta[b]!.compareTo(cuenta[a]!);
          return porCuenta != 0 ? porCuenta : (a == 'NIO' ? -1 : 1);
        });
      _currency = orden.first;
    }
  }

  void showSide(DebtDirection d) {
    if (_side == d) return;
    _side = d;
    _currency = null;
    _acomodar();
    notifyListeners();
  }

  void showCurrency(String c) {
    if (_currency == c) return;
    _currency = c;
    notifyListeners();
  }

  /* -------------------------------------------------------------- lo visto -- */

  /// Las monedas que aparecen de este lado, córdobas primero.
  List<String> get currencies {
    final s = summary;
    if (s == null) return const ['NIO'];
    final set = <String>{};
    for (final d in s.openOn(_side)) {
      set.addAll(d.currencies);
    }
    if (set.isEmpty) return const ['NIO'];
    return set.toList()..sort((a, b) => a == 'NIO' ? -1 : 1);
  }

  /// Las deudas del lado que tienen algo en la moneda que se mira. Una deuda
  /// puede estar en las dos a la vez.
  List<Debt> get debts {
    final s = summary;
    if (s == null) return const [];
    return s.openOn(_side).where((d) => d.totals.containsKey(_currency)).toList();
  }

  List<Debt> get closed => summary?.closedOn(_side) ?? const [];

  /// El total de la moneda que se mira. Se suma solo dentro de una moneda.
  Totals get total {
    var loaned = 0.0, paid = 0.0, balance = 0.0;
    for (final d in debts) {
      final t = d.totals[_currency]!;
      loaned += t.loaned;
      paid += t.paid;
      balance += t.balance;
    }
    return Totals(loaned: loaned, paid: paid, balance: balance);
  }

  /// Lo que vence en los próximos 7 días o ya está atrasado, lo más urgente
  /// primero. Es lo único de la pantalla sobre lo que hay que hacer algo.
  List<(Debt, PagoEsperado)> get pendientes {
    final s = summary;
    if (s == null) return const [];
    final out = <(Debt, PagoEsperado)>[];
    for (final d in s.openOn(_side)) {
      final p = proximoPago(d, s.today);
      if (p != null && p.daysLeft <= 7) out.add((d, p));
    }
    out.sort((a, b) => a.$2.daysLeft.compareTo(b.$2.daysLeft));
    return out;
  }

  @override
  void dispose() {
    _debts.removeListener(notifyListeners);
    load.dispose();
    refresh.dispose();
    super.dispose();
  }
}
