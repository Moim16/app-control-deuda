// El Resumen: lo que debo y lo que me deben.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/me.dart';
import '../../../domain/pago_esperado.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/cerrar_sesion.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/graficos.dart';
import '../../debt/widgets/debt_form_sheet.dart';
import '../../settings/widgets/settings_screen.dart';
import '../../debt/widgets/debt_screen.dart';
import '../view_model/summary_view_model.dart';
import 'debt_card.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  @override
  void initState() {
    super.initState();
    // El primer `load` va aquí y no en el constructor del ViewModel: pintar y
    // pedir datos son dos cosas, y la pantalla es la que sabe cuándo aparece.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SummaryViewModel>().load.run();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = context.watch<SummaryViewModel>();
    final me = context.watch<AuthRepository>().me;
    if (me == null) return const SizedBox.shrink();

    final lado = ladoDeVista(vm.side, me);
    final resumen = vm.summary;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RESUMEN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: t.faint,
              ),
            ),
            Text(
              me.accountName ?? 'Deudas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _BotonCuenta(me: me),
          ),
        ],
      ),
      // Crear una deuda es del dueño, y es lo primero que hay que poder hacer
      // en una cuenta vacia.
      floatingActionButton: (me.isOwner && vm.summary != null)
          ? FloatingActionButton.extended(
              heroTag: 'fab-deudas',
              onPressed: () => nuevaDeuda(context, vm, lado),
              icon: const Icon(Icons.add),
              label: Text(lado.nuevo),
            )
          : null,
      body: switch (vm.load) {
        _ when vm.load.errorMessage != null && resumen == null => ErrorConReintento(
          mensaje: vm.load.errorMessage!,
          onReintentar: vm.load.run,
        ),
        _ when resumen == null => const Center(child: CircularProgressIndicator()),
        _ => RefreshIndicator(
          onRefresh: vm.refresh.run,
          child: _Contenido(vm: vm, me: me, lado: lado),
        ),
      },
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.vm, required this.me, required this.lado});

  final SummaryViewModel vm;
  final Me me;
  final Lado lado;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final cur = vm.currency ?? 'NIO';
    final total = vm.total;
    final deudas = vm.debts;

    if (deudas.isEmpty && vm.pendientes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me.isOwner) _Pestanas(vm: vm, me: me),
          Card(
            child: Vacio(
              me.isOwner
                  ? lado.vacio
                  : 'Todavía no te compartieron ninguna ${lado.cosa}.\nCuando lo hagan, aparecerá aquí.',
              icono: me.isOwner ? Icons.account_balance_wallet_outlined : Icons.visibility_outlined,
              accion: me.isOwner
                  ? FilledButton.icon(
                      onPressed: () => nuevaDeuda(context, vm, lado),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(lado.nuevo),
                    )
                  : null,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // Las pestañas Debo / Me deben son solo del dueño: a quien entra de
        // solo lectura se le comparte su deuda y nada más.
        if (me.isOwner) _Pestanas(vm: vm, me: me),

        if (vm.currencies.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(
              spacing: 6,
              children: [
                for (final c in vm.currencies)
                  ChoiceChip(
                    label: Text('${Moneda.de(c).symbol} ${Moneda.de(c).name}'),
                    selected: c == cur,
                    onSelected: (_) => vm.showCurrency(c),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 14),
        MontoGrande(
          titulo: vm.currencies.length > 1
              ? '${lado.totalTitulo} (${Moneda.de(cur).name})'
              : lado.totalTitulo,
          monto: total.balance > 0 ? total.balance : 0,
          moneda: cur,
          detalle:
              '${plural(deudas.length, lado.cosa, lado.cosas)} en ${Moneda.de(cur).name}'
              ' · ${porcentaje(total.paid, total.loaned)}% ${lado.pagadoAdverbio}'
              ' de lo ${lado.loPrestado}',
        ),

        const SizedBox(height: 8),
        Casillas(
          items: [
            (lado.prestado, plata(total.loaned, cur), null),
            (lado.abonado, plata(total.paid, cur), t.ok),
            (lado.pendiente, plata(total.balance > 0 ? total.balance : 0, cur), t.bad),
          ],
        ),

        if (vm.hayMovimientos) ...[
          const Seccion('Cómo ha ido'),
          _Curva(vm: vm, lado: lado, cur: cur),
        ],

        if (vm.pendientes.isNotEmpty) ...[
          Seccion(lado.tocaTitulo, color: t.bad),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, (deuda, pago)) in vm.pendientes.indexed) ...[
                  if (i > 0) Divider(height: 1, color: t.line),
                  _FilaPendiente(debt: deuda, pago: pago),
                ],
              ],
            ),
          ),
        ],

        Seccion(lado.lista),
        for (final d in deudas)
          DebtCard(
            debt: d,
            me: me,
            currency: cur,
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => DebtScreen(debtId: d.id))),
          ),

        // Las cerradas no se esconden: una deuda saldada es justo lo que uno
        // quiere poder mirar despues, y desde ahi se reabre si hizo falta.
        if (vm.closed.isNotEmpty) ...[
          Seccion('${lado.cosas.substring(0, 1).toUpperCase()}${lado.cosas.substring(1)} cerradas'),
          for (final d in vm.closed)
            DebtCard(
              debt: d,
              me: me,
              currency: d.currencyToShow(cur),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => DebtScreen(debtId: d.id))),
            ),
        ],

        if (vm.summary!.comments.isNotEmpty) ...[
          const Seccion('Últimos comentarios'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, c) in vm.summary!.comments.indexed) ...[
                  if (i > 0) Divider(height: 1, color: t.line),
                  ListTile(
                    leading: Icon(Icons.chat_bubble_outline, size: 18, color: t.muted),
                    title: Text(
                      '${c.userName} en ${c.debtName ?? ''} · ${cuando(c.createdAt)}',
                      style: TextStyle(fontSize: 12.5, color: t.muted),
                    ),
                    subtitle: Text(
                      c.text,
                      style: TextStyle(fontSize: 14.5, color: t.ink, height: 1.35),
                    ),
                    onTap: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => DebtScreen(debtId: c.debtId))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Abre el formulario de una deuda nueva y, si se creo, entra en ella: lo
/// unico que tiene sentido hacer despues es registrar el primer prestamo.
Future<void> nuevaDeuda(BuildContext context, SummaryViewModel vm, Lado lado) async {
  final hoy = vm.summary?.today;
  if (hoy == null) return;

  final r = await DebtFormSheet.abrir(context, hoy: hoy, direccion: vm.side);
  if (!context.mounted) return;

  if (r case DeudaCreada(:final debt)) {
    // El lado se mueve al de la deuda creada: si se creo un cobro estando en
    // "Debo", dejarla fuera de la vista seria raro.
    vm.showSide(debt.direction);
    aviso(context, '${lado.nuevo} creado. Ahora registra el primer préstamo.');
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DebtScreen(debtId: debt.id)));
  }
}

/// La curva del saldo total: doce meses, al cierre de cada uno.
class _Curva extends StatelessWidget {
  const _Curva({required this.vm, required this.lado, required this.cur});

  final SummaryViewModel vm;
  final Lado lado;
  final String cur;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final datos = vm.curva;
    if (datos.meses.isEmpty) return const SizedBox.shrink();

    final etiquetas = [for (final m in datos.meses) mesCorto('$m-01')];
    final series = [Serie(nombre: lado.saldoTitulo, color: t.serie[0], valores: datos.saldo)];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cómo ha ido el saldo',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
            const SizedBox(height: 2),
            Text(
              'Últimos 12 meses, al cierre de cada mes · ${Moneda.de(cur).name}',
              style: TextStyle(fontSize: 12.5, color: t.faint),
            ),
            const SizedBox(height: 14),
            Grafico(series: series, etiquetas: etiquetas, moneda: cur),
            TablaGrafico(etiquetas: etiquetas, series: series, moneda: cur),
          ],
        ),
      ),
    );
  }
}

class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.vm, required this.me});

  final SummaryViewModel vm;
  final Me me;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final s = vm.summary;
    return Row(
      children: [
        for (final dir in DebtDirection.values)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: () => vm.showSide(dir),
              style: TextButton.styleFrom(
                foregroundColor: dir == vm.side ? t.ink : t.muted,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Row(
                children: [
                  Text(
                    ladoDeVista(dir, me).tab,
                    style: TextStyle(
                      fontWeight: dir == vm.side ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14.5,
                    ),
                  ),
                  if (s != null && s.openOn(dir).isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Etiqueta('${s.openOn(dir).length}'),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FilaPendiente extends StatelessWidget {
  const _FilaPendiente({required this.debt, required this.pago});

  final Debt debt;
  final PagoEsperado pago;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ListTile(
      leading: Icon(Icons.event_outlined, size: 20, color: pago.overdue ? t.bad : t.half),
      title: Text(
        debt.name,
        style: TextStyle(fontWeight: FontWeight.w600, color: t.ink),
      ),
      subtitle: Text(
        '${_texto(pago)} · ${fecha(pago.day, conAno: true)}',
        style: TextStyle(color: t.muted, fontSize: 13),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            plata(pago.amount, pago.currency),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: t.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (pago.overdue) ...[
            const SizedBox(height: 2),
            const Etiqueta('atrasado', tono: Tono.malo),
          ],
        ],
      ),
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => DebtScreen(debtId: debt.id))),
    );
  }

  static String _texto(PagoEsperado p) {
    if (p.overdue) return 'Atrasado ${plural(p.daysLate, 'día', 'días')}';
    if (p.daysLeft == 0) return 'Toca hoy';
    if (p.daysLeft == 1) return 'Toca mañana';
    return 'Toca en ${plural(p.daysLeft, 'día', 'días')}';
  }
}

/// El circulito con las iniciales: abre la hoja de la cuenta.
class _BotonCuenta extends StatelessWidget {
  const _BotonCuenta({required this.me});

  final Me me;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _abrir(context),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: t.line2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          me.initials,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: t.ink),
        ),
      ),
    );
  }

  void _abrir(BuildContext context) {
    final t = context.tk;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  me.initials,
                  style: TextStyle(color: t.onInk, fontWeight: FontWeight.w700),
                ),
              ),
              title: Row(
                children: [
                  Text(me.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Etiqueta(me.isOwner ? 'dueño' : 'solo lectura', fuerte: me.isOwner),
                ],
              ),
              subtitle: Text(me.fullName ?? me.accountName ?? ''),
            ),
            Divider(height: 1, color: t.line),
            // Quien entra de solo lectura no tiene barra de abajo: este es su
            // unico camino a los ajustes.
            ListTile(
              leading: Icon(Icons.settings_outlined, color: t.muted),
              title: const Text('Ajustes'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            Divider(height: 1, color: t.line),
            ListTile(
              leading: Icon(Icons.logout, color: t.bad),
              title: Text('Cerrar sesión', style: TextStyle(color: t.bad)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                cerrarSesion(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
