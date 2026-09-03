// =============================================================================
//  El detalle de una categoría en un mes: cuánto se gastó, contra su tope, y
//  cómo viene de los últimos seis meses.
//
//  Los seis meses son el punto: un mes suelto no dice si algo se disparó. Ver
//  la barra de este mes al lado de las cinco anteriores sí.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/spend_repository.dart';
import '../../../domain/dia.dart';
import '../../../domain/models/spend.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/graficos.dart';
import 'expense_form_sheet.dart';

class CategoryDetailSheet extends StatelessWidget {
  const CategoryDetailSheet({
    super.key,
    required this.categoria,
    required this.mes,
    required this.moneda,
    required this.hoy,
  });

  /// null = "Sin categoría".
  final ExpenseCategory? categoria;
  final String mes;
  final String moneda;
  final String hoy;

  static Future<void> abrir(
    BuildContext context, {
    required ExpenseCategory? categoria,
    required String mes,
    required String moneda,
    required String hoy,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        builder: (_) => CategoryDetailSheet(
          categoria: categoria,
          mes: mes,
          moneda: moneda,
          hoy: hoy,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final repo = context.watch<SpendRepository>();
    final data = repo.data;
    if (data == null) return const SizedBox.shrink();

    final catId = categoria?.id;
    bool esSuyo(Expense e) => e.categoryId == catId && e.currency == moneda;

    final delMes = data.expenses.where((e) => esSuyo(e) && mesDe(e.day) == mes).toList();
    final total = delMes.fold<double>(0, (a, e) => a + e.amount);
    final tope = (categoria?.budget != null && categoria!.currency == moneda)
        ? categoria!.budget
        : null;
    final pasado = tope != null && total > tope;

    // Los últimos seis: los suficientes para ver una tendencia sin apretar las
    // barras en un teléfono.
    final meses = ultimosMeses(6, hoy: hoy);
    final etiquetas = [for (final m in meses) mesCorto('$m-01')];
    final series = [
      Serie(
        nombre: categoria?.name ?? 'Sin categoría',
        color: t.serie[0],
        valores: [
          for (final m in meses)
            data.expenses
                .where((e) => esSuyo(e) && mesDe(e.day) == m)
                .fold<double>(0, (a, e) => a + e.amount),
        ],
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              categoria?.name ?? 'Sin categoría',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${mesLargo(mes)} · ${plural(delMes.length, 'gasto', 'gastos')}',
              style: TextStyle(fontSize: 13, color: t.muted),
            ),
            const SizedBox(height: 16),

            Casillas(items: [
              ('Gastado', plata(total, moneda), pasado ? t.bad : null),
              (
                'Presupuesto',
                tope == null ? '—' : plata(tope, moneda),
                null,
              ),
            ]),

            if (tope != null) ...[
              const SizedBox(height: 10),
              Barra(parte: total, total: tope, color: pasado ? t.bad : null),
              const SizedBox(height: 6),
              Text(
                pasado
                    ? 'Pasado por ${plata(total - tope, moneda)}'
                    : 'Queda ${plata(tope - total, moneda)} del tope',
                style: TextStyle(fontSize: 12.5, color: pasado ? t.bad : t.muted),
              ),
            ],

            const Seccion('Últimos 6 meses'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Grafico(
                      series: series,
                      etiquetas: etiquetas,
                      moneda: moneda,
                      forma: FormaGrafico.barras,
                      alto: 160,
                    ),
                    TablaGrafico(etiquetas: etiquetas, series: series, moneda: moneda),
                  ],
                ),
              ),
            ),

            const Seccion('Los gastos del mes'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: delMes.isEmpty
                  ? Vacio('Sin gastos este mes.', icono: Icons.shopping_cart_outlined)
                  : Column(
                      children: [
                        for (final (i, e) in delMes.indexed) ...[
                          if (i > 0) Divider(height: 1, color: t.line),
                          ListTile(
                            title: Text(
                              (e.reason?.trim().isNotEmpty ?? false)
                                  ? e.reason!.trim()
                                  : 'Gasto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.5, color: t.ink),
                            ),
                            subtitle: Text(
                              fecha(e.day),
                              style: TextStyle(fontSize: 12.5, color: t.muted),
                            ),
                            trailing: Text(
                              plata(e.amount, e.currency),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            onTap: () async {
                              final guardado = await ExpenseFormSheet.abrir(
                                context,
                                hoy: hoy,
                                categorias: data.activas,
                                monedaPorDefecto: moneda,
                                gasto: e,
                              );
                              if (guardado && context.mounted) aviso(context, 'Guardado');
                            },
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
