// =============================================================================
//  El tema: los mismos tokens de color de la PWA, en Flutter.
//
//  Reglas heredadas del proyecto web, porque no valen menos aqui:
//
//    - Todo el color sale de tokens; ninguna pantalla escribe un color literal.
//    - El color CON SIGNIFICADO se reserva para dos cosas: el sentido del
//      movimiento (rojo el prestamo, verde el abono) y las series de los
//      graficos. Lo demas es blanco, negro y grises.
//    - Sin sombras salvo en lo que flota. La jerarquia la dan el espacio y el
//      peso de la letra.
// =============================================================================

import 'package:flutter/material.dart';

class Tokens extends ThemeExtension<Tokens> {
  const Tokens({
    required this.ink,
    required this.onInk,
    required this.muted,
    required this.faint,
    required this.line,
    required this.line2,
    required this.card,
    required this.soft,
    required this.ok,
    required this.okBg,
    required this.bad,
    required this.badBg,
    required this.half,
    required this.halfBg,
    required this.serie,
  });

  final Color ink;      // texto principal y acciones
  final Color onInk;    // lo que va ENCIMA de ink
  final Color muted;
  final Color faint;
  final Color line;     // separadores y bordes de tarjeta
  final Color line2;    // borde de control, algo mas marcado
  final Color card;
  final Color soft;     // relleno sutil
  final Color ok;       // abono / al dia
  final Color okBg;
  final Color bad;      // prestamo / atrasado / error
  final Color badBg;
  final Color half;     // aviso
  final Color halfBg;
  final List<Color> serie;   // series de los graficos, en orden fijo

  static const claro = Tokens(
    ink: Color(0xFF18181B),
    onInk: Colors.white,
    muted: Color(0xFF71717A),
    faint: Color(0xFFA1A1AA),
    line: Color(0xFFE8E8EB),
    line2: Color(0xFFD6D6DB),
    card: Colors.white,
    soft: Color(0xFFFAFAFA),
    ok: Color(0xFF15803D),
    okBg: Color(0xFFF1FAF3),
    bad: Color(0xFFB91C1C),
    badBg: Color(0xFFFDF2F2),
    half: Color(0xFFA16207),
    halfBg: Color(0xFFFDF9ED),
    // La paleta validada para daltonismo del proyecto web, tema claro.
    serie: [
      Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A),
      Color(0xFFEDA100), Color(0xFFE87BA4), Color(0xFF008300),
    ],
  );

  static const oscuro = Tokens(
    ink: Color(0xFFF4F4F5),
    onInk: Color(0xFF0D0D0F),
    muted: Color(0xFFA1A1AA),
    faint: Color(0xFF6F6F78),
    line: Color(0xFF26262A),
    line2: Color(0xFF3A3A41),
    card: Color(0xFF171719),
    soft: Color(0xFF1F1F23),
    ok: Color(0xFF4ADE80),
    okBg: Color(0xFF122318),
    bad: Color(0xFFF87171),
    badBg: Color(0xFF271515),
    half: Color(0xFFFBBF24),
    halfBg: Color(0xFF251D0F),
    // Los mismos ocho tonos, escalonados para el fondo oscuro (no es un
    // invertido automatico: se eligieron y se validaron aparte).
    serie: [
      Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70),
      Color(0xFFC98500), Color(0xFFD55181), Color(0xFF008300),
    ],
  );

  @override
  Tokens copyWith({
    Color? ink, Color? onInk, Color? muted, Color? faint, Color? line, Color? line2,
    Color? card, Color? soft, Color? ok, Color? okBg, Color? bad, Color? badBg,
    Color? half, Color? halfBg, List<Color>? serie,
  }) =>
      Tokens(
        ink: ink ?? this.ink,
        onInk: onInk ?? this.onInk,
        muted: muted ?? this.muted,
        faint: faint ?? this.faint,
        line: line ?? this.line,
        line2: line2 ?? this.line2,
        card: card ?? this.card,
        soft: soft ?? this.soft,
        ok: ok ?? this.ok,
        okBg: okBg ?? this.okBg,
        bad: bad ?? this.bad,
        badBg: badBg ?? this.badBg,
        half: half ?? this.half,
        halfBg: halfBg ?? this.halfBg,
        serie: serie ?? this.serie,
      );

  @override
  Tokens lerp(ThemeExtension<Tokens>? other, double t) {
    if (other is! Tokens) return this;
    // Un tema no se interpola a medias en esta app: se cambia y ya.
    return t < 0.5 ? this : other;
  }
}

/// Atajo para leer los tokens en cualquier widget: `contexto.tk.ok`.
extension TokensDe on BuildContext {
  Tokens get tk => Theme.of(this).extension<Tokens>()!;
}

ThemeData _tema(Tokens t, Brightness brillo, Color fondo) {
  final base = brillo == Brightness.dark ? ThemeData.dark() : ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: fondo,
    extensions: [t],
    colorScheme: base.colorScheme.copyWith(
      brightness: brillo,
      primary: t.ink,
      onPrimary: t.onInk,
      surface: t.card,
      error: t.bad,
    ),
    // Cifras tabulares donde se alinean columnas; el monto grande usa las
    // proporcionales, que a ese tamaño se ven mejor.
    textTheme: base.textTheme.apply(bodyColor: t.ink, displayColor: t.ink),
    dividerColor: t.line,
    appBarTheme: AppBarTheme(
      backgroundColor: fondo,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: t.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: t.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.line2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.ink, width: 1.5),
      ),
      labelStyle: TextStyle(color: t.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.ink,
        foregroundColor: t.onInk,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        side: BorderSide(color: t.line2),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.card,
      indicatorColor: t.soft,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: t.muted),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.ink,
      contentTextStyle: TextStyle(color: t.onInk, fontWeight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );
}

final temaClaro = _tema(Tokens.claro, Brightness.light, const Color(0xFFF7F7F8));
final temaOscuro = _tema(Tokens.oscuro, Brightness.dark, const Color(0xFF0D0D0F));
