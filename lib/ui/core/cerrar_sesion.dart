// =============================================================================
//  Cerrar sesión, en un solo sitio.
//
//  Importa que sea uno solo: al salir hay que vaciar TODOS los repositorios, y
//  si cada pantalla lo hace por su cuenta, el día que se añada uno nuevo se va
//  a olvidar en alguna — y el siguiente que entre vería datos que no son suyos.
//
//  Y se hace AQUÍ y no mientras se pinta: `clear()` avisa a quien escucha, y
//  avisar en medio de un build es justo lo que Flutter no permite.
// =============================================================================

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/avisos_repository.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/spend_repository.dart';
import '../../data/repositories/vehicle_repository.dart';

Future<void> cerrarSesion(BuildContext context) async {
  context.read<DebtRepository>().clear();
  context.read<SpendRepository>().clear();
  context.read<VehicleRepository>().clear();
  // Los recordatorios programados son de esta cuenta: dejarlos puestos avisaría
  // de pagos que el siguiente que entre no tiene por qué ver.
  await context.read<AvisosRepository>().desactivar();

  if (context.mounted) await context.read<AuthRepository>().signOut();
}
