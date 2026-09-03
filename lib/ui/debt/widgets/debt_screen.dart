// La ficha de una deuda (o de un cobro): saldo, movimientos y comentarios.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../domain/models/debt.dart';
import '../../../domain/models/entry.dart';
import '../../../utils/result.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';
import '../view_model/debt_view_model.dart';
import 'comments_thread.dart';
import 'entry_detail_sheet.dart';
import 'entry_form_sheet.dart';
import 'entry_tile.dart';

class DebtScreen extends StatelessWidget {
  const DebtScreen({super.key, required this.debtId});

  final int debtId;

  @override
  Widget build(BuildContext context) {
    // El ViewModel se crea aquí: vive lo que vive la pantalla, y se destruye
    // con ella.
    return ChangeNotifierProvider(
      create: (_) => DebtViewModel(
        debts: context.read<DebtRepository>(),
        debtId: debtId,
      )..load.run(),
      child: const _DebtBody(),
    );
  }
}

class _DebtBody extends StatelessWidget {
  const _DebtBody();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = context.watch<DebtViewModel>();
    final me = context.watch<AuthRepository>().me;
    final debt = vm.debt;

    if (me == null || debt == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lado = ladoDe(debt, me);
    final cur = vm.currency;
    final tot = debt.totals[cur]!;
    final varias = debt.currencies.length > 1;
    final pago = vm.pago;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              debt.isReceivable == (lado == Lado.meDeben) && lado == Lado.meDeben ? 'COBRO' : 'DEUDA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: t.faint,
              ),
            ),
            Text(
              debt.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: vm.reload.run,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            // Las etiquetas de qué es esto.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (me.isOwner)
                  Etiqueta(
                    debt.isReceivable ? 'me deben' : 'yo debo',
                    tono: debt.isReceivable ? Tono.bueno : Tono.normal,
                  ),
                Etiqueta(debt.kind.label),
                if (!varias) Etiqueta(Moneda.de(cur).name),
                if (!debt.active) const Etiqueta('cerrada', tono: Tono.malo),
              ],
            ),
            if (debt.counterpart?.trim().isNotEmpty == true || debt.note?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  [debt.counterpart, debt.note].where((x) => x?.trim().isNotEmpty == true).join(' · '),
                  style: TextStyle(fontSize: 13, color: t.muted),
                ),
              ),

            // Una deuda puede tener una parte en córdobas y otra en dólares.
            if (varias)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final c in debt.currencies)
                      ChoiceChip(
                        label: Text(
                          '${Moneda.de(c).symbol} ${Moneda.de(c).name} · ${plata(debt.pendingIn(c), c)}',
                        ),
                        selected: c == cur,
                        onSelected: (_) => vm.showCurrency(c),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            MontoGrande(
              titulo: tot.balance <= 0 && tot.loaned > 0
                  ? 'Parte saldada'
                  : (varias ? '${lado.saldoTitulo} en ${Moneda.de(cur).name}' : lado.saldoTitulo),
              monto: tot.balance > 0 ? tot.balance : 0,
              moneda: cur,
              detalle: _detalle(debt, lado, cur, varias),
              abajo: Barra(parte: tot.paid, total: tot.loaned),
            ),

            const SizedBox(height: 8),
            Casillas(items: [
              (lado.prestado, plata(tot.loaned, cur), null),
              (lado.abonado, plata(tot.paid, cur), t.ok),
              ('Movimientos', '${vm.allEntries.length}', null),
            ]),

            // Solo el dueño registra. No se esconde el boton "por si acaso":
            // la API tambien lo rechaza, esto es para no ofrecer lo imposible.
            if (me.isOwner && vm.hoy != null) ...[
              const SizedBox(height: 14),
              _BotonesRegistrar(vm: vm, lado: lado, hoy: vm.hoy!),
            ],

            if (pago != null) ...[
              const SizedBox(height: 12),
              Aviso(
                '${plata(pago.amount, pago.currency)} ${debt.plan!.every.label.toLowerCase()}'
                ' · ${fecha(pago.day, conAno: true)}',
                negrita: pago.overdue
                    ? 'Atrasado ${plural(pago.daysLate, 'día', 'días')}'
                    : pago.daysLeft == 0
                        ? 'Toca hoy'
                        : 'Toca en ${plural(pago.daysLeft, 'día', 'días')}',
                tono: pago.overdue ? Tono.malo : (pago.soon ? Tono.aviso : Tono.bueno),
                icono: Icons.event_outlined,
              ),
            ],

            const SizedBox(height: 18),
            _Pestanas(vm: vm, lado: lado),
            const SizedBox(height: 12),

            if (vm.tab == DebtTab.movimientos)
              _Movimientos(vm: vm, lado: lado, puedeEscribir: me.isOwner)
            else
              CommentsThread(vm: vm, soloLectura: !me.isOwner),
          ],
        ),
      ),
    );
  }

  static String _detalle(Debt debt, Lado lado, String cur, bool varias) {
    final tot = debt.totals[cur]!;
    final base = tot.balance < 0
        ? '${lado.abonado} de más: ${plata(-tot.balance, cur)} a favor'
        : '${porcentaje(tot.paid, tot.loaned)}% ${lado.pagadoAdverbio} de ${plata(tot.loaned, cur)}';
    if (!varias) return base;
    final otras = debt.currencies
        .where((c) => c != cur)
        .map((c) => plata(debt.pendingIn(c), c))
        .join(' y ');
    return '$base · también ${lado.chip} $otras';
  }
}

/// Abre el formulario y, si se guardo, refresca la ficha y avisa.
///
/// Esta suelta y no dentro de un widget porque la llaman tres sitios: los dos
/// botones de arriba, el vacio de la lista y el detalle de un movimiento.
Future<void> _registrar(
  BuildContext context,
  DebtViewModel vm,
  Lado lado,
  EntryKind kind, {
  Entry? entry,
}) async {
  final hoy = vm.hoy;
  final debt = vm.debt;
  if (hoy == null || debt == null) return;

  final guardado = await EntryFormSheet.abrir(
    context,
    debtId: vm.debtId,
    lado: lado,
    hoy: hoy,
    kind: kind,
    // La moneda que se propone: la que se esta mirando, que para una deuda de
    // una sola moneda es justo la suya.
    currency: entry?.currency ?? vm.currency,
    entry: entry,
  );
  if (!guardado || !context.mounted) return;

  await vm.refrescar();
  if (!context.mounted) return;
  aviso(
    context,
    entry != null
        ? 'Movimiento corregido'
        : '${kind == EntryKind.loan ? lado.prestamo : lado.abono} registrado',
  );
}

/// Los dos botones de registrar. Son dos y no un menu porque son las dos cosas
/// que se hacen todo el tiempo, y asi el tipo queda decidido antes de abrir.
class _BotonesRegistrar extends StatelessWidget {
  const _BotonesRegistrar({required this.vm, required this.lado, required this.hoy});

  final DebtViewModel vm;
  final Lado lado;
  final String hoy;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _registrar(context, vm, lado, EntryKind.loan),
            style: OutlinedButton.styleFrom(foregroundColor: t.bad),
            icon: const Icon(Icons.arrow_upward, size: 17),
            label: Text(lado.prestamo, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _registrar(context, vm, lado, EntryKind.payment),
            icon: const Icon(Icons.arrow_downward, size: 17),
            label: Text(lado.abono, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.vm, required this.lado});

  final DebtViewModel vm;
  final Lado lado;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final comentarios = vm.allEntries.fold<int>(0, (a, e) => a + e.commentCount) +
        vm.comments.length;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
      child: Row(
        children: [
          for (final tab in DebtTab.values)
            _Pestana(
              texto: tab == DebtTab.movimientos ? 'Movimientos' : 'Comentarios',
              cuenta: tab == DebtTab.movimientos ? vm.allEntries.length : comentarios,
              activa: vm.tab == tab,
              onTap: () => vm.showTab(tab),
            ),
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.cuenta,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final int cuenta;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: activa ? t.ink : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                color: activa ? t.ink : t.muted,
              ),
            ),
            if (cuenta > 0) ...[
              const SizedBox(width: 6),
              Etiqueta('$cuenta'),
            ],
          ],
        ),
      ),
    );
  }
}

class _Movimientos extends StatelessWidget {
  const _Movimientos({required this.vm, required this.lado, required this.puedeEscribir});

  final DebtViewModel vm;
  final Lado lado;

  /// El de solo lectura ve la lista igual, pero no la toca.
  final bool puedeEscribir;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lista = vm.entries;
    final saldos = vm.runningBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final f in EntryFilter.values)
              ChoiceChip(
                label: Text(switch (f) {
                  EntryFilter.todos => 'Todos',
                  EntryFilter.prestamos => lado.prestamos,
                  EntryFilter.abonos => lado.abonos,
                }),
                selected: vm.filter == f,
                onSelected: (_) => vm.showFilter(f),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: lista.isEmpty
              ? Vacio(
                  vm.allEntries.isEmpty ? lado.sinMovimientos : 'Nada con ese filtro.',
                  icono: Icons.receipt_long_outlined,
                  // Un vacio sin salida deja a la persona mirando el texto:
                  // aqui mismo esta el boton de cargar el primero.
                  accion: (vm.allEntries.isEmpty && puedeEscribir && vm.hoy != null)
                      ? FilledButton.icon(
                          onPressed: () => _registrar(context, vm, lado, EntryKind.loan),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(lado.primerMovimiento),
                        )
                      : null,
                )
              : Column(
                  children: [
                    for (final (i, e) in lista.indexed) ...[
                      if (i > 0) Divider(height: 1, color: t.line),
                      EntryTile(
                        entry: e,
                        lado: lado,
                        saldo: saldos[e.id],
                        onTap: () => _abrirDetalle(context, e),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context, Entry e) async {
    final accion = await showModalBottomSheet<AccionMovimiento>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      builder: (_) => EntryDetailSheet(
        entry: e,
        lado: lado,
        cargarComprobante: vm.receipt,
        puedeEditar: puedeEscribir,
      ),
    );
    if (!context.mounted) return;

    // La hoja no hace el trabajo: dice lo que se pidio y se cierra. Asi el
    // formulario y el borrado no se abren encima de un modal que se esta yendo.
    switch (accion) {
      case AccionMovimiento.corregir:
        await _registrar(context, vm, lado, e.kind, entry: e);
      case AccionMovimiento.borrar:
        await _borrar(context, e);
      case null:
        break;
    }
  }

  Future<void> _borrar(BuildContext context, Entry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar este ${(e.isLoan ? lado.prestamo : lado.abono).toLowerCase()}?'),
        content: Text(
          'Se borra ${plata(e.amount, e.currency)} del ${fecha(e.day, conAno: true)}, '
          'su comprobante y sus comentarios. El saldo se recalcula.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.tk.bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final r = await vm.borrarMovimiento(e.id);
    if (!context.mounted) return;
    switch (r) {
      case Ok<void>():
        aviso(context, 'Movimiento borrado');
      case Err<void>(:final message):
        aviso(context, message, malo: true);
    }
  }
}
