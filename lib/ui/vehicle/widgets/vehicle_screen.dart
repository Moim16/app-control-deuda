// =============================================================================
//  El vehículo: qué le toca, qué se le ha hecho y qué se le ha puesto.
//
//  El mantenimiento va en UN registro con UN monto que puede cubrir varias
//  tareas a la vez, porque así es como se hace: uno lleva la moto a la casa
//  comercial, le hacen aceite, filtro y cadena, y paga un solo monto. Los
//  accesorios (antivuelco, pescantes, llantas) van aparte: no son algo que
//  haya que repetir, y de ellos lo que interesa es cuánto lleva invertido.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/mantenimiento.dart';
import '../../../domain/models/vehicle.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/comunes.dart';
import '../view_model/vehicle_view_model.dart';
import 'service_form_sheet.dart';
import 'tasks_screen.dart';
import 'vehicle_form_sheet.dart';

class VehicleScreen extends StatelessWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VehicleViewModel(vehiculos: context.read<VehicleRepository>())..load.run(),
      child: const _VehicleBody(),
    );
  }
}

class _VehicleBody extends StatelessWidget {
  const _VehicleBody();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final vm = context.watch<VehicleViewModel>();
    final v = vm.vehiculo;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VEHÍCULO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: t.faint,
              ),
            ),
            Text(
              v?.name ?? 'Mantenimiento',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
          ],
        ),
        actions: [
          if (v != null) ...[
            IconButton(
              icon: const Icon(Icons.checklist_outlined, size: 21),
              tooltip: 'Tareas',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TasksScreen(vehiculo: v)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 21),
              tooltip: 'Editar el vehículo',
              onPressed: () => _editarVehiculo(context, v),
            ),
          ],
        ],
      ),
      floatingActionButton: v == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _nuevoServicio(context, vm, v),
              icon: const Icon(Icons.add),
              label: const Text('Registro'),
            ),
      body: switch (vm.load) {
        _ when vm.load.errorMessage != null && vm.data == null => ErrorConReintento(
            mensaje: vm.load.errorMessage!,
            onReintentar: vm.load.run,
          ),
        _ when vm.data == null => const Center(child: CircularProgressIndicator()),
        _ => RefreshIndicator(
            onRefresh: vm.refresh.run,
            child: v == null ? const _Arranque() : _Contenido(vm: vm, v: v),
          ),
      },
    );
  }
}

Future<void> _editarVehiculo(BuildContext context, Vehicle? v) async {
  final guardado = await VehicleFormSheet.abrir(context, vehiculo: v);
  if (guardado && context.mounted) aviso(context, 'Guardado');
}

Future<void> _nuevoServicio(
  BuildContext context,
  VehicleViewModel vm,
  Vehicle v, {
  Service? servicio,
}) async {
  final guardado = await ServiceFormSheet.abrir(
    context,
    vehiculo: v,
    hoy: vm.hoy,
    tareas: vm.data?.tareasDe(v.id) ?? const [],
    servicio: servicio,
  );
  if (guardado && context.mounted) {
    aviso(context, servicio == null ? 'Registrado' : 'Guardado');
  }
}

class _Arranque extends StatelessWidget {
  const _Arranque();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              Vacio(
                'Registra tu moto o tu carro y la app te dice cuándo le toca '
                'cada cosa.\nCon el vehículo se crean las tareas típicas: '
                'aceite, llantas, seguro…',
                icono: Icons.two_wheeler_outlined,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => _editarVehiculo(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Registrar un vehículo'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.vm, required this.v});

  final VehicleViewModel vm;
  final Vehicle v;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final pendientes = vm.pendientes;
    final monedas = vm.monedasGastadas;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        if (vm.vehiculos.length > 1)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in vm.vehiculos)
                ChoiceChip(
                  label: Text(x.active ? x.name : '${x.name} (archivado)'),
                  selected: x.id == v.id,
                  onSelected: (_) => vm.mostrar(x.id),
                ),
            ],
          ),

        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Etiqueta(v.kind.label),
            if (v.plate?.trim().isNotEmpty ?? false) Etiqueta(v.plate!.trim()),
            if (v.year != null) Etiqueta('${v.year}'),
            if (!v.active) const Etiqueta('archivado', tono: Tono.malo),
          ],
        ),

        const SizedBox(height: 14),
        MontoGrande(
          titulo: 'Kilometraje',
          monto: v.odometer,
          // El kilometraje no es plata: sin simbolo de moneda y con su unidad.
          unidad: 'km',
          detalle: v.odometer == null
              ? 'Anótalo en el próximo registro y la app puede decirte cuándo toca cada cosa.'
              : 'El más alto anotado · ${plural(v.services, 'registro', 'registros')}'
                  '${v.lastDay != null ? ' · último ${fecha(v.lastDay)}' : ''}',
        ),

        if (monedas.isNotEmpty) ...[
          const SizedBox(height: 10),
          Casillas(items: [
            for (final c in monedas) ('Gastado (${Moneda.de(c).name})', plata(v.spent[c], c), null),
            if (vm.gastadoEnAccesorios.isNotEmpty)
              (
                'En accesorios',
                vm.gastadoEnAccesorios.entries
                    .map((e) => plata(e.value, e.key))
                    .join(' + '),
                null,
              ),
          ]),
        ],

        if (pendientes.isNotEmpty) ...[
          Seccion('Le toca ya', color: t.bad),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, st) in pendientes.indexed) ...[
                  if (i > 0) Divider(height: 1, color: t.line),
                  _FilaTarea(st: st, urgente: true),
                ],
              ],
            ),
          ),
        ],

        _Tareas(vm: vm),
        _Historial(vm: vm, v: v),
        _Accesorios(vm: vm, v: v),
      ],
    );
  }
}

class _Tareas extends StatelessWidget {
  const _Tareas({required this.vm});

  final VehicleViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final alDia = vm.tareas.where((x) => !x.toca).toList();
    if (alDia.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Seccion('Al día'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, st) in alDia.indexed) ...[
                if (i > 0) Divider(height: 1, color: t.line),
                _FilaTarea(st: st, urgente: false),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaTarea extends StatelessWidget {
  const _FilaTarea({required this.st, required this.urgente});

  final EstadoTarea st;
  final bool urgente;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // El color por urgencia: rojo lo pasado, ámbar lo que está por caer.
    final color = st.nunca
        ? t.muted
        : urgente
            ? t.bad
            : st.urgencia < 0.25
                ? t.half
                : t.ok;

    return ListTile(
      leading: Icon(
        st.nunca
            ? Icons.help_outline
            : urgente
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
        size: 20,
        color: color,
      ),
      title: Text(
        st.tarea.name,
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
      ),
      subtitle: Text(
        textoDeTarea(st, numero: (n) => soloNumero(n), plural: plural),
        style: TextStyle(fontSize: 12.5, color: urgente ? t.bad : t.muted),
      ),
      trailing: st.ultimo == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fecha(st.ultimo!.day), style: TextStyle(fontSize: 12, color: t.faint)),
                if (st.ultimo!.odometer != null)
                  Text(
                    '${soloNumero(st.ultimo!.odometer)} km',
                    style: TextStyle(fontSize: 11.5, color: t.faint),
                  ),
              ],
            ),
    );
  }
}

class _Historial extends StatelessWidget {
  const _Historial({required this.vm, required this.v});

  final VehicleViewModel vm;
  final Vehicle v;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lista = vm.mantenimientos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Seccion('Lo que se le ha hecho'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: lista.isEmpty
              ? Vacio(
                  'Todavía no hay nada anotado.',
                  icono: Icons.build_outlined,
                  accion: FilledButton.icon(
                    onPressed: () => _nuevoServicio(context, vm, v),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Anotar un mantenimiento'),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, s) in lista.indexed) ...[
                      if (i > 0) Divider(height: 1, color: t.line),
                      _FilaServicio(
                        s: s,
                        tareas: vm.data,
                        onTap: () => _nuevoServicio(context, vm, v, servicio: s),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Accesorios extends StatelessWidget {
  const _Accesorios({required this.vm, required this.v});

  final VehicleViewModel vm;
  final Vehicle v;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lista = vm.accesorios;
    if (lista.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Seccion('Lo que se le ha puesto'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, s) in lista.indexed) ...[
                if (i > 0) Divider(height: 1, color: t.line),
                _FilaServicio(
                  s: s,
                  tareas: vm.data,
                  onTap: () => _nuevoServicio(context, vm, v, servicio: s),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaServicio extends StatelessWidget {
  const _FilaServicio({required this.s, required this.tareas, required this.onTap});

  final Service s;
  final VehicleData? tareas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // Las tareas que cubrió: es lo que explica que un solo monto haya tapado
    // tres cosas.
    final cubre = s.taskIds
        .map((id) => tareas?.tarea(id)?.name)
        .whereType<String>()
        .toList();

    return ListTile(
      title: Text(
        s.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
      ),
      subtitle: Text(
        [
          fecha(s.day, conAno: true),
          if (s.odometer != null) '${soloNumero(s.odometer)} km',
          if (s.place?.trim().isNotEmpty ?? false) s.place!.trim(),
          if (cubre.isNotEmpty) cubre.join(', '),
        ].join(' · '),
        maxLines: 2,
        style: TextStyle(fontSize: 12.5, color: t.muted, height: 1.35),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.expenseId != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.shopping_cart_outlined, size: 14, color: t.faint),
            ),
          if (s.hasReceipt)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.image_outlined, size: 15, color: t.faint),
            ),
          Text(
            // Sin costo: fue en garantía, y decirlo es mejor que un "C$0".
            s.cost == null ? 'garantía' : plata(s.cost, s.currency),
            style: TextStyle(
              fontSize: 14,
              fontWeight: s.cost == null ? FontWeight.w400 : FontWeight.w600,
              color: s.cost == null ? t.faint : t.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
