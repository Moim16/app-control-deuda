// =============================================================================
//  Las piezas que se repiten en varias pantallas.
//
//  Están aquí y no copiadas en cada `widgets/` de feature porque son de la app,
//  no de una pantalla: si el aviso de error cambia, cambia en todas.
// =============================================================================

import 'package:flutter/material.dart';

import '../formato.dart';
import '../theme/app_theme.dart';

enum Tono { normal, bueno, aviso, malo }

/// La banda de color con un mensaje. El equivalente del `.msg` de la web.
class Aviso extends StatelessWidget {
  const Aviso(this.texto, {super.key, this.tono = Tono.normal, this.icono, this.negrita});

  final String texto;
  final Tono tono;
  final IconData? icono;

  /// La primera parte, en negrita ("Atrasado 50 días · C$1,000 cada mes").
  final String? negrita;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final (fondo, color) = switch (tono) {
      Tono.bueno => (t.okBg, t.ok),
      Tono.aviso => (t.halfBg, t.half),
      Tono.malo => (t.badBg, t.bad),
      Tono.normal => (t.soft, t.muted),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icono != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icono, size: 17, color: color),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (negrita != null)
                    TextSpan(
                      text: negrita,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (negrita != null) const TextSpan(text: ' · '),
                  TextSpan(text: texto),
                ],
              ),
              style: TextStyle(color: color, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// El estado vacío con su icono: nunca un texto suelto en medio de la nada.
class Vacio extends StatelessWidget {
  const Vacio(this.texto, {super.key, this.icono = Icons.inbox_outlined, this.accion});

  final String texto;
  final IconData icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      child: Column(
        children: [
          Icon(icono, size: 26, color: t.faint),
          const SizedBox(height: 10),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.faint, fontSize: 13.5, height: 1.6),
          ),
          if (accion != null) ...[const SizedBox(height: 16), accion!],
        ],
      ),
    );
  }
}

/// La etiqueta chiquita en pastilla ("ya toca", "solo lectura").
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.tono = Tono.normal, this.fuerte = false});

  final String texto;
  final Tono tono;

  /// Fondo tinta, letra clara: para la que tiene que resaltar de verdad.
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final (fondo, borde, color) = switch (tono) {
      Tono.bueno => (t.okBg, t.ok.withValues(alpha: 0.4), t.ok),
      Tono.aviso => (t.halfBg, t.half.withValues(alpha: 0.4), t.half),
      Tono.malo => (t.badBg, t.bad.withValues(alpha: 0.4), t.bad),
      Tono.normal => fuerte ? (t.ink, t.ink, t.onInk) : (t.soft, t.line, t.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: fondo,
        border: Border.all(color: borde),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

/// El monto grande de una pantalla: el número que uno vino a ver.
///
/// Cifras proporcionales a propósito: `tabular-nums` a este tamaño deja los
/// números flojos, y aquí no hay ninguna columna que alinear.
class MontoGrande extends StatelessWidget {
  const MontoGrande({
    super.key,
    required this.titulo,
    required this.monto,
    required this.moneda,
    this.detalle,
    this.abajo,
  });

  final String titulo;
  final double monto;
  final String moneda;
  final String? detalle;
  final Widget? abajo;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: t.muted,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Moneda.de(moneda).symbol,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: t.muted),
                ),
                const SizedBox(width: 4),
                Text(
                  soloNumero(monto),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.2,
                    height: 1.1,
                    color: t.ink,
                  ),
                ),
              ],
            ),
            if (detalle != null) ...[
              const SizedBox(height: 2),
              Text(detalle!, style: TextStyle(fontSize: 13, color: t.muted, height: 1.4)),
            ],
            if (abajo != null) ...[const SizedBox(height: 12), abajo!],
          ],
        ),
      ),
    );
  }
}

/// Las tres casillas de totales: prestado, abonado, lo que falta.
class Casillas extends StatelessWidget {
  const Casillas({super.key, required this.items});

  /// Título, valor y de qué color va el valor.
  final List<(String, String, Color?)> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$1.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                      color: t.faint,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: item.$3 ?? t.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// La barra de progreso fina: cuánto se ha pagado de lo prestado.
class Barra extends StatelessWidget {
  const Barra({super.key, required this.parte, required this.total, this.color, this.alto = 6});

  final num parte;
  final num total;
  final Color? color;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto / 2),
      child: Container(
        height: alto,
        decoration: BoxDecoration(
          color: t.soft,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(alto / 2),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (porcentaje(parte, total) / 100).clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color ?? t.serie[2],
              borderRadius: BorderRadius.circular(alto / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// El encabezado de sección: un título chiquito en mayúsculas, con algo
/// opcional a la derecha.
class Seccion extends StatelessWidget {
  const Seccion(this.titulo, {super.key, this.derecha, this.color});

  final String titulo;
  final Widget? derecha;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: color ?? t.faint,
              ),
            ),
          ),
          if (derecha != null) derecha!,
        ],
      ),
    );
  }
}

/// La pantalla de "algo salió mal", con su botón de reintentar. Un error sin
/// forma de reintentar deja a la persona atrapada.
class ErrorConReintento extends StatelessWidget {
  const ErrorConReintento({super.key, required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Aviso(mensaje, tono: Tono.malo, icono: Icons.error_outline),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// El aviso breve de abajo, que no interrumpe. Reemplaza al `toast()` de la web.
void aviso(BuildContext context, String texto, {bool malo = false}) {
  final t = context.tk;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(malo ? Icons.error_outline : Icons.check, size: 18, color: malo ? Colors.white : t.onInk),
            const SizedBox(width: 8),
            Expanded(child: Text(texto)),
          ],
        ),
        backgroundColor: malo ? t.bad : t.ink,
        duration: Duration(seconds: malo ? 4 : 2),
      ),
    );
}
