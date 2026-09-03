// Los gastos del hogar: sus categorías, los gastos y los ingresos.
//
// Todo esto es del DUEÑO. Un usuario de solo lectura entra a ver la deuda que
// le compartieron, no en qué se gasta uno la plata: la API le responde 404 a
// todo esto, incluida la lectura.

/// Una categoría del gasto (Comida, Casa, Transporte…) con su presupuesto
/// mensual opcional.
///
/// Se llama `ExpenseCategory` y no `Category` porque ese nombre ya lo usa
/// `flutter/foundation`, y el choque obliga a esconder uno de los dos en cada
/// archivo que importe ambos. Es el mismo motivo por el que `AccountSummary` no
/// se llama `Summary`.
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    this.budget,
    required this.currency,
    required this.active,
    required this.expenses,
  });

  final int id;
  final String name;

  /// El tope que uno se propone al mes. Es un tope propuesto, no una regla:
  /// pasarse no bloquea nada, solo se pinta en rojo.
  final double? budget;

  /// La moneda del presupuesto. Un tope en córdobas no limita un gasto en
  /// dólares: son dos cuentas.
  final String currency;

  final bool active;

  /// Cuántos gastos tiene. Sirve para avisar antes de archivarla.
  final int expenses;

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
        id: j['id'] as int,
        name: j['name'] as String,
        budget: (j['budget'] as num?)?.toDouble(),
        currency: (j['currency'] as String?) ?? 'NIO',
        active: (j['active'] as int? ?? 1) == 1,
        expenses: (j['expenses'] as int?) ?? 0,
      );
}

class Expense {
  const Expense({
    required this.id,
    this.categoryId,
    required this.day,
    required this.amount,
    required this.currency,
    this.reason,
    this.note,
    required this.hasReceipt,
    this.createdBy,
    this.createdAt,
  });

  final int id;

  /// null = sin categoría. Pasa cuando se borra una categoría: sus gastos NO
  /// se borran, porque la plata se gastó igual.
  final int? categoryId;

  final String day;
  final double amount;
  final String currency;
  final String? reason;
  final String? note;
  final bool hasReceipt;
  final String? createdBy;
  final String? createdAt;

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as int,
        categoryId: j['categoryId'] as int?,
        day: j['day'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'NIO',
        reason: j['reason'] as String?,
        note: j['note'] as String?,
        hasReceipt: (j['hasReceipt'] as bool?) ?? false,
        createdBy: j['createdBy'] as String?,
        createdAt: j['createdAt'] as String?,
      );
}

/// De qué tipo es un ingreso.
enum IncomeKind {
  /// El sueldo: se repite cada mes y rige DESDE su fecha.
  monthly,

  /// Lo que entró una sola vez ese día: aguinaldo, un trabajito.
  once;

  static IncomeKind parse(String? v) => v == 'once' ? IncomeKind.once : IncomeKind.monthly;

  String get wire => this == IncomeKind.once ? 'once' : 'monthly';

  String get label => this == IncomeKind.once ? 'Una sola vez' : 'Cada mes';
}

class Income {
  const Income({
    required this.id,
    required this.kind,
    required this.amount,
    required this.currency,
    required this.day,
    this.source,
    this.note,
  });

  final int id;
  final IncomeKind kind;
  final double amount;
  final String currency;

  /// En un sueldo, DESDE cuándo se gana eso. Así un aumento se registra con su
  /// fecha y los meses viejos siguen contando lo que se ganaba entonces.
  final String day;

  final String? source;
  final String? note;

  bool get esSueldo => kind == IncomeKind.monthly;

  factory Income.fromJson(Map<String, dynamic> j) => Income(
        id: j['id'] as int,
        kind: IncomeKind.parse(j['kind'] as String?),
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'NIO',
        day: j['day'] as String,
        source: j['source'] as String?,
        note: j['note'] as String?,
      );
}

/// Todo lo que devuelve `/api/expenses` en una sola llamada: es lo que necesita
/// la pantalla para pintarse entera.
class SpendData {
  const SpendData({
    required this.today,
    required this.from,
    required this.categories,
    required this.expenses,
    required this.incomes,
  });

  final String today;

  /// El primer día del rango que trajo la API.
  final String from;

  final List<ExpenseCategory> categories;
  final List<Expense> expenses;

  /// Los ingresos vienen COMPLETOS, no solo los del rango: el sueldo de hace
  /// dos años sigue haciendo falta para saber qué se ganaba entonces.
  final List<Income> incomes;

  List<ExpenseCategory> get activas => categories.where((c) => c.active).toList();

  ExpenseCategory? categoria(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  factory SpendData.fromJson(Map<String, dynamic> j) => SpendData(
        today: j['today'] as String,
        from: (j['from'] as String?) ?? '',
        categories: (j['categories'] as List)
            .map((c) => ExpenseCategory.fromJson(c as Map<String, dynamic>))
            .toList(),
        expenses: (j['expenses'] as List)
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList(),
        incomes: (j['incomes'] as List)
            .map((i) => Income.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}
