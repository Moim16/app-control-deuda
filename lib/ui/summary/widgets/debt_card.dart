// La tarjeta de una deuda en el resumen.

import 'package:flutter/material.dart';

import '../../../domain/models/debt.dart';
import '../../../domain/models/me.dart';
import '../../core/formato.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vocabulario.dart';
import '../../core/widgets/comunes.dart';

class DebtCard extends StatelessWidget {
  const DebtCard({
    super.key,
    required this.debt,
    required this.me,
    required this.currency,
    required this.onTap,
  });

  final Debt debt;
  final Me me;

  /// La moneda que se está mirando en el resumen. Si la deuda no tiene nada en
  /// ella, se muestra la que sí tenga.
  final String currency;

  final VoidCallback onTap;

  static IconData iconoDe(DebtKind k) => switch (k) {
        DebtKind.person => Icons.person_outline,
        DebtKind.card => Icons.credit_card,
        DebtKind.other => Icons.account_balance_wallet_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lado = ladoDe(debt, me);
    final cur = debt.currencyToShow(currency);
    final tot = debt.totals[cur]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.soft,
                        border: Border.all(color: t.line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconoDe(debt.kind), size: 18, color: t.muted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                          Text(
                            _subtitulo(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: t.faint),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Una deuda puede estar en dos monedas: se muestran las
                        // dos, una debajo de la otra. Nunca sumadas.
                        for (final c in debt.currencies)
                          Text(
                            plata(debt.pendingIn(c), c),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: t.ink,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        Text(
                          debt.settled ? 'saldada' : lado.chip,
                          style: TextStyle(fontSize: 11.5, color: t.faint),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Barra(parte: tot.paid, total: tot.loaned),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${lado.prestado} ${plata(tot.loaned, cur)}',
                        style: TextStyle(fontSize: 12, color: t.muted),
                      ),
                    ),
                    Text(
                      '${lado.abonado} ${plata(tot.paid, cur)} · ${porcentaje(tot.paid, tot.loaned)}%',
                      style: TextStyle(fontSize: 12, color: t.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitulo() {
    final quien = debt.counterpart?.trim().isNotEmpty == true
        ? debt.counterpart!
        : debt.kind.label;
    final cuando = debt.lastDay == null
        ? 'sin movimientos'
        : 'último mov. ${fecha(debt.lastDay)}';
    return '$quien · $cuando';
  }
}
