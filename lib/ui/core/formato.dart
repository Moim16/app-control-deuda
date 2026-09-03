// =============================================================================
//  Montos y fechas, como se escriben en Nicaragua.
//
//  Todo el formato vive aqui: si un dia hay que cambiar como se ve un monto, se
//  cambia en un solo sitio y no en catorce pantallas.
// =============================================================================

import 'package:intl/intl.dart';

/// Las dos monedas de la app. No hay conversion entre ellas a proposito: no
/// hay tipo de cambio, asi que los saldos van por separado y nunca se suman.
class Moneda {
  const Moneda(this.symbol, this.name);
  final String symbol;
  final String name;

  static const nio = Moneda('C\$', 'córdobas');
  static const usd = Moneda('US\$', 'dólares');

  static const todas = {'NIO': nio, 'USD': usd};

  static Moneda de(String code) => todas[code] ?? nio;
}

// El separador de miles es la COMA y el decimal el PUNTO, como se escribe en
// Nicaragua y como ya lo muestra la version web ("C$3,500.50"). Se pide con el
// locale 'en_US' a proposito: los datos de `es_NI` que trae `intl` usan el
// punto para los miles, y las dos apps tienen que decir lo mismo.
final _nf = NumberFormat('#,##0.##', 'en_US');
final _nf2 = NumberFormat('#,##0.00', 'en_US');

/// "C$3,500" — el simbolo siempre pegado al monto que le corresponde, para que
/// no quede duda de en que moneda esta.
String plata(num? monto, String moneda) {
  final v = (monto ?? 0).toDouble();
  final abs = v.abs() < 0.005 ? 0 : v.abs();
  return '${v < 0 ? '-' : ''}${Moneda.de(moneda).symbol}${_nf.format(abs)}';
}

/// Con los dos decimales siempre, para las columnas de un detalle.
String plata2(num? monto, String moneda) =>
    '${Moneda.de(moneda).symbol}${_nf2.format(monto ?? 0)}';

/// Solo el numero, para el monto grande que ya lleva su simbolo aparte.
String soloNumero(num? v) => _nf.format((v ?? 0).abs());

/// "12.5k", "1.2M" — para los ejes de un grafico, donde no cabe el monto entero.
String compacto(num? v) {
  final n = (v ?? 0).toDouble();
  final a = n.abs();
  if (a >= 1e6) return '${(n / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1).replaceAll('.0', '')}M';
  if (a >= 1e3) return '${(n / 1e3).toStringAsFixed(a >= 1e4 ? 0 : 1).replaceAll('.0', '')}k';
  return _nf.format(n);
}

/// El porcentaje que se muestra al lado de una barra.
int porcentaje(num parte, num total) =>
    total <= 0 ? 0 : (parte / total * 100).clamp(0, 100).round();

/* ================================================================ fechas == */

final _dia = DateFormat('d MMM', 'es');
final _diaAno = DateFormat('d MMM yyyy', 'es');
final _diaLargo = DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'es');
final _mesAno = DateFormat('MMMM yyyy', 'es');
final _fechaHora = DateFormat('d MMM, h:mm a', 'es');

/// "12 may" o "12 may 2026". Sin el punto que mete `intl` en la abreviatura.
String fecha(String? day, {bool conAno = false}) {
  if (day == null || day.isEmpty) return '—';
  final d = DateTime.tryParse(day);
  if (d == null) return '—';
  return (conAno ? _diaAno : _dia).format(d).replaceAll('.', '');
}

/// "martes, 12 de mayo de 2026".
String fechaLarga(String day) {
  final d = DateTime.tryParse(day);
  return d == null ? '—' : _diaLargo.format(d);
}

/// "mayo 2026", para la cabecera de un mes.
String mesLargo(String yyyymm) {
  final d = DateTime.tryParse('$yyyymm-01');
  return d == null ? '—' : _mesAno.format(d);
}

/// Cuando se escribio algo: "12 may, 3:40 p. m.".
String cuando(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '—' : _fechaHora.format(d.toLocal()).replaceAll('.', '');
}

/// Hoy en YYYY-MM-DD segun el telefono. Solo para poner por defecto la fecha de
/// un formulario: la fecha que MANDA es la que dice el servidor.
String hoyLocal() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// "3 días" / "1 día": el plural bien hecho, que aparece por todas partes.
String plural(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

/// "sept 26", para el eje de un gráfico donde no cabe el mes entero.
String mesCorto(String? day) {
  final d = DateTime.tryParse(day ?? '');
  if (d == null) return '—';
  return DateFormat('MMM yy', 'es').format(d).replaceAll('.', '');
}
