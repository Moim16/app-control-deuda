// =============================================================================
//  El estado de la pantalla de gastos.
//
//  El MES manda: se elige un mes y todo lo de abajo habla de ese mes. Lo que
//  uno quiere saber al abrir esto es una sola cosa — "¿cuánto llevo y me estoy
//  pasando?" — así que eso es lo que se calcula primero.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/spend_repository.dart';
import '../../../domain/dia.dart';
import '../../../domain/gastos.dart';
import '../../../domain/models/spend.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class SpendViewModel extends ChangeNotifier {
  SpendViewModel({required SpendRepository gastos, required DebtRepository deudas})
      : _gastos = gastos,
        _deudas = deudas {
    load = Command0<SpendData>(_load)..addListener(notifyListeners);
    refresh = Command0<SpendData>(() => _load(force: true))..addListener(notifyListeners);
    _gastos.addListener(notifyListeners);
  }

  final SpendRepository _gastos;

  /// Los movimientos de deudas hacen falta para decir qué queda de verdad este
  /// mes: lo que se abonó también salió del bolsillo.
  final DebtRepository _deudas;

  late final Command0<SpendData> load;
  late final Command0<SpendData> refresh;

  SpendData? get data => _gastos.data;

  String? _mes;
  String? _moneda;

  String get hoy => data?.today ?? diaDe(DateTime.now());
  String get mes => _mes ?? mesDe(hoy);
  bool get esMesActual => mes == mesDe(hoy);

  /// Las monedas que aparecen: las de los gastos del mes y las de los
  /// presupuestos. Córdobas siempre, aunque no haya nada.
  List<String> get monedas {
    final set = <String>{'NIO'};
    for (final e in gastosDelMes) {
      set.add(e.currency);
    }
    for (final c in data?.activas ?? const <ExpenseCategory>[]) {
      if (c.budget != null) set.add(c.currency);
    }
    return set.toList()..sort((a, b) => a == 'NIO' ? -1 : 1);
  }

  String get moneda => (_moneda != null && monedas.contains(_moneda)) ? _moneda! : monedas.first;

  /* ------------------------------------------------------------- lo del mes -- */

  List<Expense> get gastosDelMes =>
      (data?.expenses ?? const <Expense>[]).where((e) => mesDe(e.day) == mes).toList();

  List<Expense> get gastosEnMoneda =>
      gastosDelMes.where((e) => e.currency == moneda).toList();

  double get gastado => gastosEnMoneda.fold<double>(0, (a, e) => a + e.amount);

  /// El presupuesto del mes: la suma de los topes de las categorías EN ESTA
  /// MONEDA. Las que no tienen tope no suman nada, y la pantalla lo avisa.
  double get tope => (data?.activas ?? const <ExpenseCategory>[])
      .where((c) => c.budget != null && c.currency == moneda)
      .fold<double>(0, (a, c) => a + c.budget!);

  int get cuantasSinTope => (data?.activas ?? const <ExpenseCategory>[])
      .where((c) => c.budget == null || c.currency != moneda)
      .length;

  int get porcentajeGastado => tope <= 0 ? 0 : ((gastado / tope) * 100).round();
  int get porcentajeMes => porcentajeDelMes(mes, hoy);
  int get diasMes => diasDelMes(mes);
  int get diaHoy => esMesActual ? (int.tryParse(hoy.substring(8, 10)) ?? diasMes) : diasMes;

  /// Cómo va el mes contra el tope: verde, ámbar o rojo.
  ///
  /// No se compara solo contra el 100%: gastar el 60% cuando va el 20% del mes
  /// ya es ir mal, y esperar al 101% para avisar sería avisar tarde.
  EstadoDelMes get estado {
    if (tope <= 0) return EstadoDelMes.sinTope;
    if (porcentajeGastado > 100) return EstadoDelMes.pasado;
    if (porcentajeGastado > porcentajeMes + 10) return EstadoDelMes.apretado;
    return EstadoDelMes.bien;
  }

  IngresoDelMes get ingreso => ingresoDe(data?.incomes ?? const [], mes, moneda);

  ({double pagado, double recibido}) get flujo => flujoDeudas(
        movimientos: _deudas.summary?.entries ?? const [],
        deudas: _deudas.summary?.debts ?? const [],
        mes: mes,
        moneda: moneda,
      );

  /// Lo que queda de verdad este mes: lo que entró menos lo gastado y menos lo
  /// que ya se abonó a deudas. Lo que me pagaron de un cobro también entró.
  double get disponible {
    final f = flujo;
    return ingreso.total + f.recibido - gastado - f.pagado;
  }

  Capacidad? get capacidad => capacidadDe(
        ingresos: data?.incomes ?? const [],
        gastos: data?.expenses ?? const [],
        moneda: moneda,
        hoy: hoy,
      );

  List<GastoDeCategoria> get categorias => porCategoria(
        categorias: data?.categories ?? const [],
        gastosDelMes: gastosDelMes,
        moneda: moneda,
      );

  /// El gasto de los últimos doce meses, para el gráfico.
  ({List<String> meses, List<double> gastado}) get porMes {
    final ms = ultimosMeses(12, hoy: hoy);
    return (
      meses: ms,
      gastado: [
        for (final m in ms)
          (data?.expenses ?? const <Expense>[])
              .where((e) => e.currency == moneda && mesDe(e.day) == m)
              .fold<double>(0, (a, e) => a + e.amount),
      ],
    );
  }

  /// Si la cuenta está recién empezada: no hay categorías ni ingresos.
  bool get vacia =>
      (data?.categories.isEmpty ?? true) && (data?.incomes.isEmpty ?? true);

  /* -------------------------------------------------------------- cambios -- */

  void mesAnterior() {
    _mes = mesDe(masMeses('$mes-01', -1));
    notifyListeners();
  }

  void mesSiguiente() {
    // No se pasa del mes en curso: no hay gastos del futuro.
    if (esMesActual) return;
    _mes = mesDe(masMeses('$mes-01', 1));
    notifyListeners();
  }

  void showMoneda(String c) {
    if (_moneda == c) return;
    _moneda = c;
    notifyListeners();
  }

  Future<Result<SpendData>> _load({bool force = false}) => _gastos.load(force: force);

  @override
  void dispose() {
    _gastos.removeListener(notifyListeners);
    load.dispose();
    refresh.dispose();
    super.dispose();
  }
}

enum EstadoDelMes { sinTope, bien, apretado, pasado }
