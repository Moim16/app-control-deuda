// =============================================================================
//  Mantiene los recordatorios al día sin que nadie tenga que acordarse.
//
//  Va envolviendo la app: escucha los repositorios y, cuando cambian las deudas
//  o el vehículo, reprograma. Es lo que evita el fallo clásico de esto — anotar
//  un abono y que el teléfono siga avisando del pago viejo.
//
//  No pinta nada: solo mira y reprograma.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/avisos_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../formato.dart';

class SincronizaAvisos extends StatefulWidget {
  const SincronizaAvisos({super.key, required this.child});

  final Widget child;

  @override
  State<SincronizaAvisos> createState() => _SincronizaAvisosState();
}

class _SincronizaAvisosState extends State<SincronizaAvisos> {
  /// La huella de lo último que se programó. Sin esto, cada `notifyListeners`
  /// de cualquier repositorio volvería a reprogramar una docena de avisos.
  String _ultima = '';

  @override
  Widget build(BuildContext context) {
    final avisos = context.watch<AvisosRepository>();
    final deudas = context.watch<DebtRepository>();
    final vehiculos = context.watch<VehicleRepository>();
    final me = context.watch<AuthRepository>().me;

    final resumen = deudas.summary;
    if (avisos.activo && me != null && resumen != null) {
      final huella = [
        avisos.hora,
        resumen.today,
        // Lo que mueve una fecha de aviso: el acuerdo, el último pago y el
        // saldo de cada deuda.
        for (final d in resumen.debts)
          '${d.id}:${d.active}:${d.plan?.every.wire}:${d.plan?.amount}:'
              '${d.plan?.from}:${d.lastPaymentDay}:${d.currencies.map(d.pendingIn).join(',')}',
        vehiculos.data?.services.length,
        vehiculos.data?.tasks.length,
      ].join('|');

      if (huella != _ultima) {
        _ultima = huella;
        // Fuera del build: reprogramar toca el sistema y no puede pasar
        // mientras se está pintando.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          avisos.sincronizar(
            deudas: resumen.debts,
            vehiculos: vehiculos.data,
            hoy: resumen.today,
            // Para quien mira de solo lectura, su deuda es un cobro: el aviso
            // tiene que decirle "te deben", no "debes".
            esCobro: (d) => me.isOwner ? d.isReceivable : !d.isReceivable,
            plata: plata,
            fecha: (d) => fecha(d, conAno: true),
          );
        });
      }
    }

    return widget.child;
  }
}
