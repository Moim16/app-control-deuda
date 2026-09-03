// =============================================================================
//  El estado del simulador: qué saldo se está simulando y con qué montos.
//
//  Se simula una deuda EN UNA MONEDA. Una deuda con parte en córdobas y parte
//  en dólares son dos planes distintos: no hay tipo de cambio en esta app, así
//  que juntarlas sería inventarse uno.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/spend_repository.dart';
import '../../../domain/dia.dart';
import '../../../domain/gastos.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/simulacion.dart';

/// Una cosa simulable: la parte de una deuda en una moneda.
class Simulable {
  const Simulable({required this.debt, required this.currency, required this.balance});

  final Debt debt;
  final String currency;
  final double balance;

  String get key => '${debt.id}-$currency';
}

class SimViewModel extends ChangeNotifier {
  SimViewModel({
    required DebtRepository debts,
    required SpendRepository gastos,
    int? debtId,
  })  : _debts = debts,
        _gastos = gastos,
        _debtIdInicial = debtId {
    _debts.addListener(_alCambiar);
    _acomodar();
  }

  final DebtRepository _debts;

  /// Los gastos y los ingresos, para poder decir cuanto sobra de verdad al mes.
  /// Es lo que separa el simulador de un juego de numeros.
  final SpendRepository _gastos;

  final int? _debtIdInicial;

  /// Hasta tres montos a la vez: comparar dos planes es el 90% del uso, y con
  /// más de tres el gráfico deja de leerse.
  static const maxEscenarios = 3;

  String? _key;
  DueEvery _cada = DueEvery.monthly;
  String? _desde;
  String _rate = '0';
  List<String> _montos = const [];

  DueEvery get cada => _cada;
  String get desde => _desde ?? hoy;
  String get rate => _rate;
  List<String> get montos => _montos;

  String get hoy => _debts.summary?.today ?? diaDe(DateTime.now());

  /// Todo lo que tiene saldo para simular, de las deudas abiertas.
  List<Simulable> get opciones {
    final s = _debts.summary;
    if (s == null) return const [];
    final out = <Simulable>[];
    for (final d in s.debts.where((d) => d.active)) {
      for (final c in d.currencies) {
        final b = d.totals[c]?.balance ?? 0;
        if (b > 0) out.add(Simulable(debt: d, currency: c, balance: b));
      }
    }
    return out;
  }

  Simulable? get elegida {
    final ops = opciones;
    if (ops.isEmpty) return null;
    for (final o in ops) {
      if (o.key == _key) return o;
    }
    return ops.first;
  }

  /// Lo que de verdad sobra al mes, si la app lo sabe. Solo tiene sentido en
  /// una deuda propia: en un cobro, quien tiene que poder pagar es el otro.
  Capacidad? get capacidad {
    final o = elegida;
    if (o == null || o.debt.isReceivable) return null;
    final d = _gastos.data;
    if (d == null) return null;
    return capacidadDe(
      ingresos: d.incomes,
      gastos: d.expenses,
      moneda: o.currency,
      hoy: d.today,
    );
  }

  double get interes {
    final n = double.tryParse(_rate.replaceAll(',', '').trim()) ?? 0;
    return (n.isFinite && n > 0) ? n : 0;
  }

  /// Un resultado por monto escrito. Los montos vacíos o en cero no simulan
  /// nada: no se inventa un plan que nadie pidió.
  List<(double, Simulacion?)> get resultados {
    final o = elegida;
    if (o == null) return const [];
    return [
      for (final m in _montos)
        (
          double.tryParse(m.replaceAll(',', '').trim()) ?? 0,
          _simular(o, double.tryParse(m.replaceAll(',', '').trim()) ?? 0),
        ),
    ];
  }

  Simulacion? _simular(Simulable o, double monto) => monto <= 0
      ? null
      : simular(
          saldo: o.balance,
          cuota: monto,
          cada: _cada,
          desde: desde,
          rate: interes,
        );

  /* -------------------------------------------------------------- cambios -- */

  void elegir(String key) {
    if (_key == key) return;
    _key = key;
    // Al cambiar de deuda, el interés y el monto propuesto son los de ESA
    // deuda: arrastrar los de la anterior daría un plan que no es de nadie.
    final o = elegida;
    if (o != null) {
      _rate = _interesDe(o);
      _montos = [_sugerir(o)];
    }
    notifyListeners();
  }

  void cambiarCada(DueEvery e) {
    if (_cada == e) return;
    _cada = e;
    notifyListeners();
  }

  void cambiarDesde(String d) {
    if (_desde == d) return;
    _desde = d;
    notifyListeners();
  }

  void cambiarInteres(String v) {
    _rate = v;
    notifyListeners();
  }

  void cambiarMonto(int i, String v) {
    if (i < 0 || i >= _montos.length) return;
    _montos = [..._montos]..[i] = v;
    notifyListeners();
  }

  void agregarEscenario() {
    if (_montos.length >= maxEscenarios) return;
    final ultimo = double.tryParse(_montos.last.replaceAll(',', '')) ?? 100;
    _montos = [..._montos, (ultimo * 1.5).round().toString()];
    notifyListeners();
  }

  void quitarEscenario(int i) {
    if (_montos.length <= 1 || i < 0 || i >= _montos.length) return;
    _montos = [..._montos]..removeAt(i);
    notifyListeners();
  }

  /* ------------------------------------------------------------------------ */

  void _alCambiar() {
    _acomodar();
    notifyListeners();
  }

  /// Deja elegida una opción que exista y propone un monto de arranque.
  void _acomodar() {
    final ops = opciones;
    if (ops.isEmpty) return;
    if (_key != null && ops.any((o) => o.key == _key)) {
      if (_montos.isEmpty) _montos = [_sugerir(elegida!)];
      return;
    }
    // La deuda desde la que se abrió el simulador, si trajo saldo.
    final inicial = _debtIdInicial == null
        ? null
        : ops.where((o) => o.debt.id == _debtIdInicial).firstOrNull;
    final o = inicial ?? ops.first;
    _key = o.key;
    _rate = _interesDe(o);
    _montos = [_sugerir(o)];
  }

  /// El monto de arranque: lo que de verdad sobra al mes si la app lo sabe, y
  /// si no, pagarlo en un año. Lo primero es un numero real; lo segundo, un
  /// deseo — pero es mejor que empezar en blanco.
  String _sugerir(Simulable o) {
    final cap = capacidad;
    if (cap != null && cap.libre > 0) {
      final v = cap.libre < o.balance ? cap.libre : o.balance;
      return v.round().toString();
    }
    return _sugerido(o);
  }

  static String _interesDe(Simulable o) {
    final r = o.debt.interestRate;
    if (r == null || r <= 0) return '0';
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
  }

  /// Pagarlo en un año, redondeado a algo que uno diría en voz alta (decenas
  /// en córdobas, unidades en dólares).
  static String _sugerido(Simulable o) {
    final paso = o.currency == 'USD' ? 1 : 10;
    final v = (o.balance / 12 / paso).round() * paso;
    return (v < 1 ? 1 : v).toString();
  }

  @override
  void dispose() {
    _debts.removeListener(_alCambiar);
    super.dispose();
  }
}
