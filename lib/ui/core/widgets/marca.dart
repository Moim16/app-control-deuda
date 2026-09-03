// =============================================================================
//  La marca de la app: la misma cartera del icono del lanzador.
//
//  Se dibuja con un CustomPainter en vez de cargar un PNG por dos razones: se
//  ve nitida a cualquier tamaño, y toma los colores de los tokens del tema, asi
//  que no hay dos verdades sobre cual es el negro de la app.
//
//  La geometria es LA MISMA de `tool/make_icons.mjs` (lienzo de 512), para que
//  el icono del telefono y lo que se ve dentro de la app sean el mismo dibujo.
// =============================================================================

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class Marca extends StatelessWidget {
  const Marca({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarcaPainter(fondo: t.ink, cartera: t.onInk),
      ),
    );
  }
}

/// Solo la cartera, sin el cuadrado de fondo: para una barra o un boton, donde
/// el fondo ya lo pone otra cosa.
class MarcaSuelta extends StatelessWidget {
  const MarcaSuelta({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarcaPainter(cartera: color ?? context.tk.ink, soloCartera: true),
      ),
    );
  }
}

class _MarcaPainter extends CustomPainter {
  const _MarcaPainter({
    this.fondo,
    required this.cartera,
    this.soloCartera = false,
  });

  final Color? fondo;
  final Color cartera;
  final bool soloCartera;

  @override
  void paint(Canvas canvas, Size size) {
    // Todo esta pensado en un lienzo de 512: se escala y se olvida.
    final k = size.width / 512;
    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(x * k, y * k, w * k, h * k);
    Radius rad(double v) => Radius.circular(v * k);

    if (!soloCartera && fondo != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r(0, 0, 512, 512), rad(96)),
        Paint()..color = fondo!,
      );
    }

    // El cuerpo, y el bolsillo recortado de el: con `difference` el bolsillo es
    // un hueco de verdad, asi que se ve el fondo a traves y no un parche del
    // color del fondo (que en la version suelta seria un rectangulo pegado).
    final cuerpo = Path()
      ..addRRect(RRect.fromRectAndRadius(r(84, 156, 344, 216), rad(44)));
    final bolsillo = Path()
      ..addRRect(RRect.fromRectAndRadius(r(300, 222, 148, 84), rad(30)));
    final broche = Path()
      ..addOval(Rect.fromCircle(center: Offset(368 * k, 264 * k), radius: 17 * k));

    final conHueco = Path.combine(PathOperation.difference, cuerpo, bolsillo);
    canvas.drawPath(conHueco, Paint()..color = cartera);
    canvas.drawPath(broche, Paint()..color = cartera);
  }

  @override
  bool shouldRepaint(_MarcaPainter old) =>
      old.fondo != fondo || old.cartera != cartera || old.soloCartera != soloCartera;
}
