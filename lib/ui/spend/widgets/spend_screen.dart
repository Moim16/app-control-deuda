// =============================================================================
//  Gastos del hogar.
//
//  El mes manda: se elige un mes arriba y todo lo de abajo habla de ese mes.
//  Al abrir esto uno viene a saber UNA cosa — "¿cuánto llevo y me estoy
//  pasando?" — así que eso va primero y grande, y el detalle debajo.
//
//  El presupuesto es un tope que uno se propone, no una regla: pasarse no
//  bloquea nada, solo se pinta en rojo.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/spend_repository.dart';
import '../../../domain/gastos.dart';
import '../../../domain/models/spend.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/graficos.dart';
import '../view_model/spend_view_model.dart';
import 'categories_screen.dart';
import 'category_detail_sheet.dart';
import 'expense_form_sheet.dart';
import 'incomes_screen.dart';

class SpendScreen extends StatelessWidget {
  const SpendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SpendViewModel(
        gastos: context.read<SpendRepository>(),
        deudas: context.read<DebtRepository>(),
      )..load.run(),
      child: const _SpendBody(),
    );
  }
}

class _SpendBody extends StatelessWidget {
  const _SpendBody();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = context.watch<SpendViewModel>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GASTOS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: t.faint,
              ),
            ),
            Text(
              'Del hogar',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_outlined, size: 21),
            tooltip: 'Ingresos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IncomesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.label_outline, size: 21),
            tooltip: 'Categorías',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: vm.data == null || vm.vacia
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _nuevoGasto(context, vm),
              icon: const Icon(Icons.add),
              label: const Text('Gasto'),
            ),
      body: switch (vm.load) {
        _ when vm.load.errorMessage != null && vm.data == null => ErrorConReintento(
            mensaje: vm.load.errorMessage!,
            onReintentar: vm.load.run,
          ),
        _ when vm.data == null => const Center(child: CircularProgressIndicator()),
        _ => RefreshIndicator(
            onRefresh: vm.refresh.run,
            child: vm.vacia ? _Arranque(vm: vm) : _Contenido(vm: vm),
          ),
      },
    );
  }
}

Future<void> _nuevoGasto(BuildContext context, SpendViewModel vm, {Expense? gasto}) async {
  final guardado = await ExpenseFormSheet.abrir(
    context,
    hoy: vm.hoy,
    categorias: vm.data?.activas ?? const [],
    monedaPorDefecto: vm.moneda,
    gasto: gasto,
  );
  if (!guardado || !context.mounted) return;
  aviso(context, gasto == null ? 'Gasto registrado' : 'Guardado');
}

/// Sin categorías no hay nada que hacer aquí: se ofrece crearlas de una vez.
class _Arranque extends StatelessWidget {
  const _Arranque({required this.vm});

  final SpendViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              Vacio(
                'Para llevar el gasto del hogar hacen falta categorías:\n'
                'Comida, Casa, Transporte…',
                icono: Icons.shopping_cart_outlined,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _sembrar(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Crear las categorías típicas'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                      ),
                      child: const Text('Crear la mía'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sembrar(BuildContext context) async {
    final r = await context.read<SpendRepository>().seedCategories();
    if (!context.mounted) return;
    aviso(
      context,
      r.isOk ? 'Categorías creadas' : (r as dynamic).message as String,
      malo: !r.isOk,
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.vm});

  final SpendViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final cur = vm.moneda;
    final ing = vm.ingreso;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        _BarraMes(vm: vm),

        if (vm.monedas.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final c in vm.monedas)
                ChoiceChip(
                  label: Text('${Moneda.de(c).symbol} ${Moneda.de(c).name}'),
                  selected: c == cur,
                  onSelected: (_) => vm.showMoneda(c),
                ),
            ],
          ),
        ],

        const SizedBox(height: 14),
        MontoGrande(
          titulo: 'Gastado en ${mesLargo(vm.mes).split(' ').first}',
          monto: vm.gastado,
          moneda: cur,
          detalle: vm.tope > 0
              ? 'de ${plata(vm.tope, cur)} que te propusiste · ${vm.porcentajeGastado}%'
                  '${vm.esMesActual ? ' (va el ${vm.porcentajeMes}% del mes)' : ''}'
              : 'Sin presupuesto puesto todavía',
          abajo: vm.tope > 0
              ? Barra(
                  parte: vm.gastado,
                  total: vm.tope,
                  color: switch (vm.estado) {
                    EstadoDelMes.pasado => t.bad,
                    EstadoDelMes.apretado => t.half,
                    _ => t.ok,
                  },
                )
              : null,
        ),

        if (vm.tope > 0 && vm.cuantasSinTope > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${plural(vm.cuantasSinTope, 'categoría', 'categorías')} sin tope en '
            '${Moneda.de(cur).name}: no suman al presupuesto.',
            style: TextStyle(fontSize: 12, color: t.faint, height: 1.4),
          ),
        ],

        const SizedBox(height: 10),
        Casillas(items: [
          ('Entró', plata(ing.total + vm.flujo.recibido, cur), null),
          ('Gastado', plata(vm.gastado, cur), null),
          ('Queda', plata(vm.disponible, cur), vm.disponible < 0 ? t.bad : t.ok),
        ]),

        if (!ing.hay) ...[
          const SizedBox(height: 12),
          Aviso(
            'Anota tu ingreso y la app puede decirte cuánto te queda de verdad '
            'y cuánto puedes abonar.',
            tono: Tono.normal,
            icono: Icons.payments_outlined,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IncomesScreen()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Anotar mi ingreso'),
          ),
        ],

        if (vm.capacidad case final cap?) ...[
          const SizedBox(height: 12),
          Aviso(
            'Ganas ${plata(cap.ingreso, cur)} y gastas ${plata(cap.gasto, cur)} '
            'al mes (promedio de ${plural(cap.meses, 'mes', 'meses')} cerrados).',
            negrita: 'Te sobran ${plata(cap.libre, cur)}',
            tono: cap.libre > 0 ? Tono.bueno : Tono.malo,
            icono: Icons.savings_outlined,
          ),
        ],

        _PorCategoria(vm: vm),
        _Grafico(vm: vm),
        _Lista(vm: vm),
      ],
    );
  }
}

/// El selector de mes: flechas y el nombre del mes en el medio.
class _BarraMes extends StatelessWidget {
  const _BarraMes({required this.vm});

  final SpendViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mes anterior',
            onPressed: vm.mesAnterior,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  mesLargo(vm.mes),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
                ),
                Text(
                  '${plural(vm.gastosDelMes.length, 'gasto', 'gastos')}'
                  '${vm.esMesActual ? ' · día ${vm.diaHoy} de ${vm.diasMes}' : ''}',
                  style: TextStyle(fontSize: 12, color: t.faint),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Mes siguiente',
            // No se pasa del mes en curso: no hay gastos del futuro.
            onPressed: vm.esMesActual ? null : vm.mesSiguiente,
          ),
        ],
      ),
    );
  }
}

/// En qué se fue la plata, de mayor a menor.
class _PorCategoria extends StatelessWidget {
  const _PorCategoria({required this.vm});

  final SpendViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lista = vm.categorias;
    if (lista.isEmpty) return const SizedBox.shrink();

    final maximo = lista.fold<double>(1, (a, x) => x.total > a ? x.total : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Seccion('En qué se fue'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, x) in lista.indexed) ...[
                if (i > 0) Divider(height: 1, color: t.line),
                InkWell(
                  onTap: () => CategoryDetailSheet.abrir(
                    context,
                    categoria: x.categoria,
                    mes: vm.mes,
                    moneda: vm.moneda,
                    hoy: vm.hoy,
                  ),
                  child: _FilaCategoria(x: x, maximo: maximo, moneda: vm.moneda),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaCategoria extends StatelessWidget {
  const _FilaCategoria({required this.x, required this.maximo, required this.moneda});

  final GastoDeCategoria x;
  final double maximo;
  final String moneda;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tope = x.topeEn(moneda);
    final pasado = tope != null && x.total > tope;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  x.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
                ),
              ),
              Text(
                plata(x.total, moneda),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: pasado ? t.bad : t.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // La barra se mide contra el tope si lo hay, y si no contra la
          // categoría más gastada: así se compara con algo.
          Barra(
            parte: x.total,
            total: tope ?? maximo,
            color: pasado ? t.bad : null,
            alto: 5,
          ),
          const SizedBox(height: 4),
          Text(
            [
              plural(x.cuantos, 'gasto', 'gastos'),
              if (tope != null) 'tope ${plata(tope, moneda)}',
              if (pasado) '¡pasado por ${plata(x.total - tope, moneda)}!',
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: pasado ? t.bad : t.faint),
          ),
        ],
      ),
    );
  }
}

class _Grafico extends StatelessWidget {
  const _Grafico({required this.vm});

  final SpendViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final datos = vm.porMes;
    if (datos.gastado.every((v) => v == 0)) return const SizedBox.shrink();

    final etiquetas = [for (final m in datos.meses) mesCorto('$m-01')];
    final series = [
      Serie(nombre: 'Gastado', color: t.serie[0], valores: datos.gastado),
      // El tope en la misma escala: es la referencia contra la que se mira.
      if (vm.tope > 0)
        Serie(
          nombre: 'Presupuesto',
          color: t.serie[3],
          valores: [for (final _ in datos.meses) vm.tope],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Seccion('Cómo va el gasto'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Gasto por mes',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Últimos 12 meses · ${Moneda.de(vm.moneda).name}',
                  style: TextStyle(fontSize: 12.5, color: t.faint),
                ),
                const SizedBox(height: 14),
                Grafico(
                  series: series,
                  etiquetas: etiquetas,
                  moneda: vm.moneda,
                  forma: FormaGrafico.barras,
                ),
                TablaGrafico(etiquetas: etiquetas, series: series, moneda: vm.moneda),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Los gastos del mes, uno por uno.
class _Lista extends StatelessWidget {
  const _Lista({required this.vm});

  final SpendViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lista = vm.gastosEnMoneda;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Seccion(plural(lista.length, 'gasto', 'gastos')),
        Card(
          clipBehavior: Clip.antiAlias,
          child: lista.isEmpty
              ? Vacio(
                  'Nada anotado en ${mesLargo(vm.mes)}.',
                  icono: Icons.receipt_long_outlined,
                  accion: FilledButton.icon(
                    onPressed: () => _nuevoGasto(context, vm),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Anotar un gasto'),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, e) in lista.indexed) ...[
                      if (i > 0) Divider(height: 1, color: t.line),
                      ListTile(
                        title: Text(
                          (e.reason?.trim().isNotEmpty ?? false)
                              ? e.reason!.trim()
                              : (vm.data?.categoria(e.categoryId)?.name ?? 'Gasto'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.5, color: t.ink),
                        ),
                        subtitle: Text(
                          [
                            fecha(e.day),
                            vm.data?.categoria(e.categoryId)?.name ?? 'Sin categoría',
                          ].join(' · '),
                          style: TextStyle(fontSize: 12.5, color: t.muted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (e.hasReceipt)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(Icons.image_outlined, size: 15, color: t.faint),
                              ),
                            Text(
                              plata(e.amount, e.currency),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _nuevoGasto(context, vm, gasto: e),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
