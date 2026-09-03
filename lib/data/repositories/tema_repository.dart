// =============================================================================
//  El tema: claro, oscuro o el del sistema.
//
//  Se guarda en el teléfono y nada más: es una preferencia de ESTE aparato, no
//  de la cuenta. Quien entra desde dos sitios puede quererlo distinto en cada
//  uno, y mandarlo al servidor sería sincronizar algo que a nadie le importa.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemaRepository extends ChangeNotifier {
  static const _clave = 'dd_theme';

  ThemeMode _modo = ThemeMode.system;
  ThemeMode get modo => _modo;

  /// Lee lo guardado. Si no hay nada, se queda con el del sistema, que es el
  /// que acierta sin preguntar.
  Future<void> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      _modo = _desdeTexto(p.getString(_clave));
      notifyListeners();
    } catch (_) {
      // Si el almacenamiento falla, el tema del sistema sirve igual: no es
      // motivo para que la app no arranque.
    }
  }

  Future<void> cambiar(ThemeMode m) async {
    if (_modo == m) return;
    _modo = m;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_clave, _aTexto(m));
    } catch (_) {
      // Se queda puesto en esta sesión aunque no se haya podido guardar.
    }
  }

  static ThemeMode _desdeTexto(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _aTexto(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
