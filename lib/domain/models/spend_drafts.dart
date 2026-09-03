// =============================================================================
//  Lo que se está escribiendo en los formularios de gastos: un gasto, una
//  categoría, un ingreso.
//
//  Las reglas viven aquí y no en las pantallas por lo de siempre: la API las
//  comprueba igual, pero decirlo en el teléfono ahorra un viaje y da el mensaje
//  al instante. Y con los MISMOS mensajes que responde el servidor.
// =============================================================================

import '../dia.dart';
import 'spend.dart';

/// Un monto positivo escrito a mano ("3,500.50"), o null si no sirve.
double? montoDe(String texto) {
  final n = double.tryParse(texto.replaceAll(',', '').trim());
  if (n == null || !n.isFinite || n <= 0 || n > 1e9) return null;
  return (n * 100).round() / 100;
}

/// El cambio de la captura de un gasto: igual, quitada o nueva. Es el mismo
/// problema de tres estados que el comprobante de un movimiento.
sealed class CambioCaptura {
  const CambioCaptura();
}

class CapturaIgual extends CambioCaptura {
  const CapturaIgual();
}

class CapturaQuitada extends CambioCaptura {
  const CapturaQuitada();
}

class CapturaNueva extends CambioCaptura {
  const CapturaNueva(this.dataUri);
  final String dataUri;
}

/* ================================================================= gasto == */

class ExpenseDraft {
  const ExpenseDraft({
    required this.day,
    this.categoryId,
    this.amount = '',
    this.currency = 'NIO',
    this.reason = '',
    this.note = '',
    this.receipt = const CapturaIgual(),
  });

  final String day;

  /// null = sin categoría. Se permite: anotar el gasto importa más que
  /// clasificarlo, y siempre se puede arreglar después.
  final int? categoryId;

  final String amount;
  final String currency;
  final String reason;
  final String note;
  final CambioCaptura receipt;

  ExpenseDraft copyWith({
    String? day,
    int? categoryId,
    bool sinCategoria = false,
    String? amount,
    String? currency,
    String? reason,
    String? note,
    CambioCaptura? receipt,
  }) =>
      ExpenseDraft(
        day: day ?? this.day,
        categoryId: sinCategoria ? null : (categoryId ?? this.categoryId),
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        reason: reason ?? this.reason,
        note: note ?? this.note,
        receipt: receipt ?? this.receipt,
      );

  double? get monto => montoDe(amount);

  String? problema({required String hoy}) {
    if (monto == null) return 'El monto debe ser mayor que cero.';
    if (!diaValido(day)) return 'La fecha no es válida.';
    if (day.compareTo(masDias(hoy, 1)) > 0) return 'Esa fecha todavía no llega.';
    if (reason.trim().length > 120) return 'El motivo es muy largo.';
    if (note.trim().length > 500) return 'La nota es muy larga.';
    return null;
  }

  bool esValido({required String hoy}) => problema(hoy: hoy) == null;

  Map<String, Object?> aJson({required bool nuevo}) => {
        'day': day,
        'amount': monto,
        'currency': currency,
        // `categoryId` en vacío es "sin categoría" para la API; en un gasto
        // nuevo se manda igual, para poder dejarlo sin clasificar.
        'categoryId': categoryId ?? '',
        if (nuevo && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (nuevo && note.trim().isNotEmpty) 'note': note.trim(),
        // Al editar van SIEMPRE, incluso vacíos: es la forma de borrarlos.
        if (!nuevo) 'reason': reason.trim(),
        if (!nuevo) 'note': note.trim(),
        ...switch (receipt) {
          CapturaIgual() => const <String, Object?>{},
          CapturaQuitada() => const {'receipt': null},
          CapturaNueva(:final dataUri) => {'receipt': dataUri},
        },
      };

  factory ExpenseDraft.de(Expense e) => ExpenseDraft(
        day: e.day,
        categoryId: e.categoryId,
        amount: e.amount == e.amount.roundToDouble()
            ? e.amount.toStringAsFixed(0)
            : e.amount.toStringAsFixed(2),
        currency: e.currency,
        reason: e.reason ?? '',
        note: e.note ?? '',
      );
}

/* ============================================================= categoría == */

class CategoryDraft {
  const CategoryDraft({
    this.name = '',
    this.budget = '',
    this.currency = 'NIO',
    this.active = true,
  });

  final String name;

  /// El tope mensual. Vacío = sin tope, que es válido: una categoría sirve para
  /// clasificar aunque uno no se proponga un límite.
  final String budget;

  final String currency;
  final bool active;

  CategoryDraft copyWith({String? name, String? budget, String? currency, bool? active}) =>
      CategoryDraft(
        name: name ?? this.name,
        budget: budget ?? this.budget,
        currency: currency ?? this.currency,
        active: active ?? this.active,
      );

  /// El tope en número; `double.nan` si lo escrito no sirve, para distinguir
  /// "vacío" de "mal escrito".
  double? get tope {
    final s = budget.trim();
    if (s.isEmpty) return null;
    return montoDe(s) ?? double.nan;
  }

  String? get problema {
    if (name.trim().isEmpty) return 'Ponle un nombre a la categoría.';
    if (name.trim().length > 40) return 'El nombre es muy largo.';
    final b = tope;
    if (b != null && b.isNaN) return 'El presupuesto debe ser mayor que cero.';
    return null;
  }

  bool get esValido => problema == null;

  Map<String, Object?> aJson({required bool nueva}) => {
        'name': name.trim(),
        'budget': budget.trim(),
        'currency': currency,
        if (!nueva) 'active': active,
      };

  factory CategoryDraft.de(ExpenseCategory c) => CategoryDraft(
        name: c.name,
        budget: c.budget == null
            ? ''
            : (c.budget! == c.budget!.roundToDouble()
                ? c.budget!.toStringAsFixed(0)
                : c.budget!.toString()),
        currency: c.currency,
        active: c.active,
      );
}

/* =============================================================== ingreso == */

class IncomeDraft {
  const IncomeDraft({
    this.kind = IncomeKind.monthly,
    this.amount = '',
    this.currency = 'NIO',
    required this.day,
    this.source = '',
    this.note = '',
  });

  final IncomeKind kind;
  final String amount;
  final String currency;

  /// En un sueldo, DESDE cuándo rige. En uno de una sola vez, el día que entró.
  final String day;

  final String source;
  final String note;

  IncomeDraft copyWith({
    IncomeKind? kind,
    String? amount,
    String? currency,
    String? day,
    String? source,
    String? note,
  }) =>
      IncomeDraft(
        kind: kind ?? this.kind,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        day: day ?? this.day,
        source: source ?? this.source,
        note: note ?? this.note,
      );

  double? get monto => montoDe(amount);

  bool get esSueldo => kind == IncomeKind.monthly;

  String? problema({required String hoy}) {
    if (monto == null) return 'El monto debe ser mayor que cero.';
    if (!diaValido(day)) {
      return esSueldo ? 'Indica desde cuándo ganas eso.' : 'La fecha no es válida.';
    }
    // Un sueldo puede empezar a regir el mes que viene (un aumento ya
    // acordado); un ingreso de una sola vez, no: eso todavía no entró.
    if (!esSueldo && day.compareTo(masDias(hoy, 1)) > 0) {
      return 'Esa fecha todavía no llega.';
    }
    if (source.trim().length > 80) return 'Ese nombre es muy largo.';
    if (note.trim().length > 300) return 'La nota es muy larga.';
    return null;
  }

  bool esValido({required String hoy}) => problema(hoy: hoy) == null;

  Map<String, Object?> aJson() => {
        'kind': kind.wire,
        'amount': monto,
        'currency': currency,
        'day': day,
        'source': source.trim(),
        'note': note.trim(),
      };

  factory IncomeDraft.de(Income i) => IncomeDraft(
        kind: i.kind,
        amount: i.amount == i.amount.roundToDouble()
            ? i.amount.toStringAsFixed(0)
            : i.amount.toStringAsFixed(2),
        currency: i.currency,
        day: i.day,
        source: i.source ?? '',
        note: i.note ?? '',
      );
}
