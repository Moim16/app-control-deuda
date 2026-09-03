// Quien entro: su nombre, su rol y de que cuenta.

class Me {
  const Me({
    required this.id,
    required this.name,
    this.fullName,
    required this.role,
    this.accountName,
  });

  final int id;
  final String name;
  final String? fullName;

  /// `admin` es el dueño de la cuenta; `viewer` solo mira lo que le
  /// compartieron y comenta.
  final String role;
  final String? accountName;

  bool get isOwner => role == 'admin';

  /// Las iniciales para el circulito de la cabecera ("Luis Pérez" -> "LP").
  String get initials {
    final base = (fullName?.trim().isNotEmpty ?? false) ? fullName!.trim() : name;
    final partes = base.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    return partes.map((p) => p[0].toUpperCase()).join();
  }

  factory Me.fromJson(Map<String, dynamic> j, {Map<String, dynamic>? account}) => Me(
        id: j['id'] as int,
        name: j['name'] as String,
        fullName: j['fullName'] as String?,
        role: j['role'] as String,
        accountName: account?['name'] as String?,
      );
}

/// Un usuario de la cuenta, como lo ve el dueño en la pantalla de accesos.
class Usuario {
  const Usuario({
    required this.id,
    required this.name,
    this.fullName,
    required this.role,
    required this.active,
    required this.debtIds,
  });

  final int id;
  final String name;
  final String? fullName;
  final String role;
  final bool active;

  /// Las deudas que tiene asignadas. Un `viewer` sin ninguna no ve NADA: no es
  /// un error, es lo que significa no haberle compartido todavía.
  final List<int> debtIds;

  bool get isOwner => role == 'admin';

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: j['id'] as int,
        name: j['name'] as String,
        fullName: j['fullName'] as String?,
        role: (j['role'] as String?) ?? 'viewer',
        active: (j['active'] as int? ?? 1) == 1,
        debtIds: ((j['debtIds'] as List?) ?? const []).map((x) => x as int).toList(),
      );
}

/// El código de recuperación: si hay uno y de cuándo es. El código en sí solo
/// se ve UNA vez, al generarlo.
class Recuperacion {
  const Recuperacion({required this.tiene, this.desde});

  final bool tiene;
  final String? desde;

  factory Recuperacion.fromJson(Map<String, dynamic>? j) => Recuperacion(
        tiene: (j?['has'] as bool?) ?? false,
        desde: j?['at'] as String?,
      );
}
