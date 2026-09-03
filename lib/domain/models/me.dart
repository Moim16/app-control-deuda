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
