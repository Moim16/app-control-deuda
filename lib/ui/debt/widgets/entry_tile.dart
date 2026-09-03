// La fila de un movimiento en la lista.

import 'package:flutter/material.dart';

import '../../../domain/models/entry.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.lado,
    required this.saldo,
    required this.onTap,
  });

  final Entry entry;
  final Lado lado;

  /// El saldo justo después de este movimiento, en su moneda.
  final double? saldo;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // El color con significado: rojo lo que sube la deuda, verde lo que la baja.
    final color = entry.isLoan ? t.bad : t.ok;
    final fondo = entry.isLoan ? t.badBg : t.okBg;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: fondo,
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          entry.isLoan ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: color,
        ),
      ),
      title: Text(
        entry.reason?.trim().isNotEmpty == true
            ? entry.reason!
            : (entry.isLoan ? lado.prestamo : lado.abono),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.ink),
      ),
      subtitle: Row(
        children: [
          Text(
            fecha(entry.day, conAno: true),
            style: TextStyle(fontSize: 12.5, color: t.faint),
          ),
          if (entry.hasReceipt) ...[
            const SizedBox(width: 8),
            Icon(Icons.image_outlined, size: 13, color: t.faint),
          ],
          if (entry.commentCount > 0) ...[
            const SizedBox(width: 8),
            Icon(Icons.chat_bubble_outline, size: 13, color: t.faint),
            const SizedBox(width: 3),
            Text('${entry.commentCount}', style: TextStyle(fontSize: 12, color: t.faint)),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${entry.isLoan ? '+' : '−'}${plata(entry.amount, entry.currency)}',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (saldo != null)
            Text(
              'saldo ${plata(saldo, entry.currency)}',
              style: TextStyle(fontSize: 11.5, color: t.faint),
            ),
        ],
      ),
    );
  }
}
