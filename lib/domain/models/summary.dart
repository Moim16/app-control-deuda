// Todo lo que necesita el Resumen, tal como lo manda la API en una sola
// llamada: las deudas con sus totales ya calculados, los movimientos en crudo
// (para los graficos) y los ultimos comentarios.

import 'comment.dart';
import 'debt.dart';
import 'entry.dart';

class AccountSummary {
  const AccountSummary({
    required this.today,
    required this.debts,
    required this.entries,
    required this.comments,
  });

  /// Hoy segun el SERVIDOR (hora de Nicaragua). Se usa esta y no la del
  /// telefono: un equipo con la zona mal configurada diria otro dia.
  final String today;

  final List<Debt> debts;
  final List<Entry> entries;
  final List<Comment> comments;

  /// Las deudas abiertas de un lado.
  List<Debt> openOn(DebtDirection direction) =>
      debts.where((d) => d.direction == direction && d.active).toList();

  List<Debt> closedOn(DebtDirection direction) =>
      debts.where((d) => d.direction == direction && !d.active).toList();

  Debt? byId(int id) {
    for (final d in debts) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Los movimientos de una deuda que ya vinieron en el resumen. Sirven para
  /// pintar el grafico sin pedir la lista completa.
  List<Entry> entriesOf(int debtId) => entries.where((e) => e.debtId == debtId).toList();

  factory AccountSummary.fromJson(Map<String, dynamic> j) => AccountSummary(
        today: j['today'] as String,
        debts: (j['debts'] as List).map((d) => Debt.fromJson(d as Map<String, dynamic>)).toList(),
        entries:
            (j['entries'] as List).map((e) => Entry.fromJson(e as Map<String, dynamic>)).toList(),
        comments:
            (j['comments'] as List).map((c) => Comment.fromJson(c as Map<String, dynamic>)).toList(),
      );
}
