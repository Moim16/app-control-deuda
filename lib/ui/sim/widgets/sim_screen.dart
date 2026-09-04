// =============================================================================
//  El simulador: "¿y si abono C$500 cada mes?".
//
//  Es la pantalla que contesta la pregunta que uno se hace de verdad — cuándo
//  se acaba esto — y por eso lo primero que se ve es la fecha, no la tabla.
//
//  Sirve igual para lo que uno paga y para lo que espera cobrar: cambian las
//  palabras, no los números.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/spend_repository.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/simulacion.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/graficos.dart';
import '../view_model/sim_view_model.dart';

class SimScreen extends StatelessWidget {
  const SimScreen({super.key, this.debtId});

  /// La deuda desde la que se abrió, para dejarla elegida.
  final int? debtId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SimViewModel(
        debts: context.read<DebtRepository>(),
        gastos: context.read<SpendRepository>(),
        debtId: debtId,
      ),
      child: const _SimBody(),
    );
  }
}

class _SimBody extends StatelessWidget {
  const _SimBody();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = context.watch<SimViewModel>();
    final me = context.watch<AuthRepository>().me;
    final o = vm.elegida;

    return Scaffold(
      appBar: AppBar(
        bottom: const BarraCargando(),
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIMULADOR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: t.faint,
              ),
            ),
            Text(
              'Cuándo se acaba',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
          ],
        ),
      ),
      body: (o == null || me == null)
          ? Center(
              child: Vacio(
                'No hay nada con saldo para simular.',
                icono: Icons.calculate_outlined,
              ),
            )
          : _Contenido(vm: vm, o: o, lado: ladoDe(o.debt, me)),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.vm, required this.o, required this.lado});

  final SimViewModel vm;
  final Simulable o;
  final Lado lado;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final cur = o.currency;
    final cobro = lado == Lado.meDeben;
    final resultados = vm.resultados;
    final opciones = vm.opciones;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Una por deuda Y moneda: cada parte se paga por su lado.
        if (opciones.length > 1)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in opciones)
                ChoiceChip(
                  label: Text('${x.debt.name} · ${plata(x.balance, x.currency)}'),
                  selected: x.key == o.key,
                  onSelected: (_) => vm.elegir(x.key),
                ),
            ],
          ),

        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Saldo a simular: ${plata(o.balance, cur)}',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
                ),
                const SizedBox(height: 14),
                Segmentado<DueEvery>(
                  opciones: [
                    (DueEvery.weekly, 'Semanal', Icons.calendar_view_week_outlined, null),
                    (DueEvery.biweekly, 'Quincenal', Icons.calendar_view_month_outlined, null),
                    (DueEvery.monthly, 'Mensual', Icons.calendar_month_outlined, null),
                  ],
                  elegida: vm.cada,
                  onElegir: vm.cambiarCada,
                ),
                const SizedBox(height: 14),
                CampoFecha(
                  etiqueta: cobro ? 'Primer pago que reciba' : 'Primer pago',
                  dia: vm.desde,
                  hoy: vm.hoy,
                  // Se puede planear a futuro: es un plan, no un registro.
                  hastaDias: 366,
                  onCambiar: vm.cambiarDesde,
                  ayuda: 'Fecha del primer pago',
                ),
                const SizedBox(height: 14),
                _CampoInteres(vm: vm, debt: o.debt),
                if (vm.capacidad case final cap? when cap.libre > 0) ...[
                  const SizedBox(height: 14),
                  Aviso(
                    'Según tus ingresos y lo que gastas, te sobran '
                    '${plata(cap.libre, cur)} al mes.',
                    tono: Tono.bueno,
                    icono: Icons.savings_outlined,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  cobro ? 'Cuánto me abona cada vez' : 'Cuánto abono cada vez',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hasta ${SimViewModel.maxEscenarios} montos para comparar.',
                  style: TextStyle(fontSize: 12, color: t.faint),
                ),
                const SizedBox(height: 10),
                for (final (i, m) in vm.montos.indexed)
                  _CampoMonto(vm: vm, indice: i, valor: m, moneda: cur),
                if (vm.montos.length < SimViewModel.maxEscenarios)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: vm.agregarEscenario,
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('Comparar otro monto'),
                    ),
                  ),
              ],
            ),
          ),
        ),

        for (final (i, (monto, r)) in resultados.indexed)
          if (r != null)
            _Escenario(
              monto: monto,
              r: r,
              moneda: cur,
              cada: vm.cada,
              cobro: cobro,
              color: t.serie[i % t.serie.length],
              numero: resultados.length > 1 ? i + 1 : null,
              conInteres: vm.interes > 0,
            ),

        if (resultados.any((x) => x.$2 != null && !x.$2!.nunca)) ...[
          const SizedBox(height: 12),
          _Curva(vm: vm, o: o, resultados: resultados),
          const SizedBox(height: 12),
          _Calendario(
            r: resultados.firstWhere((x) => x.$2 != null && !x.$2!.nunca).$2!,
            moneda: cur,
            conInteres: vm.interes > 0,
            varios: resultados.where((x) => x.$2 != null).length > 1,
          ),
        ],
      ],
    );
  }
}

class _CampoInteres extends StatefulWidget {
  const _CampoInteres({required this.vm, required this.debt});

  final SimViewModel vm;
  final Debt debt;

  @override
  State<_CampoInteres> createState() => _CampoInteresState();
}

class _CampoInteresState extends State<_CampoInteres> {
  late final TextEditingController _c = TextEditingController(text: widget.vm.rate);
  String _ultimo = '';

  @override
  void initState() {
    super.initState();
    _ultimo = widget.vm.rate;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // Al cambiar de deuda el interés lo pone el ViewModel, y la caja de texto
    // tiene que seguirlo; lo que escribe la persona no se toca.
    if (widget.vm.rate != _ultimo) {
      _ultimo = widget.vm.rate;
      _c.text = _ultimo;
    }
    final registrado = widget.debt.interestRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: const InputDecoration(labelText: 'Interés anual (%)'),
          onChanged: (v) {
            _ultimo = v;
            widget.vm.cambiarInteres(v);
          },
        ),
        const SizedBox(height: 4),
        Text(
          registrado != null && registrado > 0
              ? 'La deuda tiene $registrado% registrado.'
              : 'Déjalo en 0 si no cobra interés (lo normal entre familia).',
          style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
        ),
      ],
    );
  }
}

class _CampoMonto extends StatefulWidget {
  const _CampoMonto({
    required this.vm,
    required this.indice,
    required this.valor,
    required this.moneda,
  });

  final SimViewModel vm;
  final int indice;
  final String valor;
  final String moneda;

  @override
  State<_CampoMonto> createState() => _CampoMontoState();
}

class _CampoMontoState extends State<_CampoMonto> {
  late final TextEditingController _c = TextEditingController(text: widget.valor);
  String _ultimo = '';

  @override
  void initState() {
    super.initState();
    _ultimo = widget.valor;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (widget.valor != _ultimo) {
      _ultimo = widget.valor;
      _c.text = _ultimo;
    }
    final color = t.serie[widget.indice % t.serie.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // El cuadrito del color de la serie: así se sabe qué línea del
          // gráfico es este monto sin tener que adivinarlo.
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: TextField(
              controller: _c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                prefixText: '${Moneda.de(widget.moneda).symbol} ',
                isDense: true,
              ),
              onChanged: (v) {
                _ultimo = v;
                widget.vm.cambiarMonto(widget.indice, v);
              },
            ),
          ),
          if (widget.vm.montos.length > 1)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: t.faint),
              tooltip: 'Quitar',
              onPressed: () => widget.vm.quitarEscenario(widget.indice),
            ),
        ],
      ),
    );
  }
}

/// El resultado de un monto: cuándo termina y cuánto cuesta.
class _Escenario extends StatelessWidget {
  const _Escenario({
    required this.monto,
    required this.r,
    required this.moneda,
    required this.cada,
    required this.cobro,
    required this.color,
    required this.numero,
    required this.conInteres,
  });

  final double monto;
  final Simulacion r;
  final String moneda;
  final DueEvery cada;
  final bool cobro;
  final Color color;
  final int? numero;
  final bool conInteres;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Container(
        // La línea de color a la izquierda ata la tarjeta con su línea del
        // gráfico.
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${cobro ? 'Recibiendo' : 'Abonando'} ${plata(monto, moneda)} '
                    '${cada.label.toLowerCase()}',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: t.ink),
                  ),
                ),
                if (numero != null) Etiqueta('escenario $numero'),
              ],
            ),
            const SizedBox(height: 12),
            if (r.nunca)
              Aviso(
                'Con ese monto la deuda no baja: el abono no cubre ni el interés '
                'del período. Sube el monto.',
                tono: Tono.aviso,
                icono: Icons.trending_flat,
              )
            else ...[
              Casillas(items: [
                ('Termina', fecha(r.hasta, conAno: true), null),
                ('Pagos', '${r.pagos}', null),
                ('Tiempo', tiempoHumano(r.desde, r.hasta), null),
              ]),
              const SizedBox(height: 8),
              Casillas(items: [
                (cobro ? 'Total a recibir' : 'Total pagado', plata(r.pagado, moneda), null),
                ('Intereses', plata(r.interes, moneda), conInteres ? t.bad : null),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cómo bajaría el saldo, escenario por escenario.
class _Curva extends StatelessWidget {
  const _Curva({required this.vm, required this.o, required this.resultados});

  final SimViewModel vm;
  final Simulable o;
  final List<(double, Simulacion?)> resultados;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    // El eje X lo manda la simulación más larga, y se muestrea: dibujar
    // trescientos puntos en un teléfono no dice más que dibujar cuarenta.
    var maxN = 0;
    for (final (_, r) in resultados) {
      if (r == null) continue;
      final n = r.nunca ? (r.pagos < 60 ? r.pagos : 60) : r.pagos;
      if (n > maxN) maxN = n;
    }
    if (maxN == 0) return const SizedBox.shrink();

    final paso = (maxN / 40).ceil().clamp(1, maxN);
    final idx = <int>[];
    for (var i = 0; i <= maxN; i += paso) {
      idx.add(i);
    }
    if (idx.last != maxN) idx.add(maxN);

    final series = <Serie>[];
    for (final (k, (monto, r)) in resultados.indexed) {
      if (r == null) continue;
      series.add(Serie(
        nombre: '${plata(monto, o.currency)} ${vm.cada.label.toLowerCase()}',
        color: t.serie[k % t.serie.length],
        valores: [
          for (final i in idx)
            // El punto 0 es el saldo de hoy; de ahí en adelante, el saldo
            // después de cada pago. Pasado el final, la deuda ya está en cero.
            if (i == 0)
              o.balance
            else if (i <= r.pagos)
              r.cuotas[i - 1].balance
            else if (!r.nunca)
              0
            else
              null,
        ],
      ));
    }
    if (series.isEmpty) return const SizedBox.shrink();

    final etiquetas = [
      for (final i in idx) i == 0 ? 'hoy' : _mesDe(vm, i),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cómo bajaría el saldo',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
            const SizedBox(height: 2),
            Text(
              'Saldo después de cada pago · ${Moneda.de(o.currency).name}',
              style: TextStyle(fontSize: 12.5, color: t.faint),
            ),
            const SizedBox(height: 14),
            Grafico(series: series, etiquetas: etiquetas, moneda: o.currency),
            TablaGrafico(etiquetas: etiquetas, series: series, moneda: o.currency),
          ],
        ),
      ),
    );
  }

  /// El mes del pago número `i`, para el eje.
  String _mesDe(SimViewModel vm, int i) {
    final primera = vm.resultados.firstWhere((x) => x.$2 != null).$2!;
    final n = i - 1;
    final dia = n < primera.cuotas.length ? primera.cuotas[n].day : primera.hasta;
    return mesCorto(dia);
  }
}

/// El calendario de pagos, plegado: es el detalle que se consulta, no lo que
/// uno viene a ver.
class _Calendario extends StatelessWidget {
  const _Calendario({
    required this.r,
    required this.moneda,
    required this.conInteres,
    required this.varios,
  });

  final Simulacion r;
  final String moneda;
  final bool conInteres;
  final bool varios;

  /// Con más pagos que esto, la tabla deja de ser útil y se dice cuántos hay.
  static const _tope = 200;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final filas = r.cuotas.take(_tope).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            varios ? 'Calendario de pagos (escenario 1)' : 'Calendario de pagos',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink),
          ),
          children: [
            for (final c in filas)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text('${c.n}', style: TextStyle(fontSize: 12, color: t.faint)),
                    ),
                    Expanded(
                      child: Text(
                        fecha(c.day, conAno: true),
                        style: TextStyle(fontSize: 13, color: t.muted),
                      ),
                    ),
                    if (conInteres)
                      SizedBox(
                        width: 74,
                        child: Text(
                          plata2(c.interest, moneda),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: t.bad,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 82,
                      child: Text(
                        plata(c.balance, moneda),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (r.pagos > _tope)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Text(
                  'Se muestran los primeros $_tope pagos de ${r.pagos}.',
                  style: TextStyle(fontSize: 12.5, color: t.faint),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
