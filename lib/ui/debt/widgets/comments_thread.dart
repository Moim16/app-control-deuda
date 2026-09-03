// El hilo de comentarios de la deuda EN GENERAL.
//
// Los de un movimiento en particular viven en su detalle. Los dos usan la
// misma pieza (`HiloComentarios`): lo único que cambia es de dónde sale la
// lista.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../view_model/debt_view_model.dart';
import 'hilo_comentarios.dart';

class CommentsThread extends StatelessWidget {
  const CommentsThread({super.key, required this.vm, required this.soloLectura});

  final DebtViewModel vm;

  /// Cambia solo el texto de ayuda: quien es dueño escribe notas, quien mira
  /// pregunta. La cajita la ve todo el mundo.
  final bool soloLectura;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          soloLectura
              ? 'Puedes dejar comentarios sobre la deuda en general, o abrir un '
                  'movimiento para comentar ese en particular.'
              : 'Aquí quedan las notas sobre la deuda en general. Para comentar '
                  'un movimiento, ábrelo.',
          style: TextStyle(fontSize: 13, color: t.muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        HiloComentarios(
          comentarios: vm.comments,
          onEnviar: vm.comentar,
          onBorrar: vm.borrarComentario,
        ),
      ],
    );
  }
}
