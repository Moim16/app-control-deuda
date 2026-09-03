// =============================================================================
//  Deudas — la app nativa.
//
//  Consume la MISMA API que la PWA, así que los saldos, los permisos y el
//  "quién ve qué" ya vienen resueltos del servidor: aquí solo hay pantallas.
//
//  Para correrla apuntando a un servidor concreto:
//    flutter run --dart-define=API_URL=https://mi-app.vercel.app
//  (o se cambia desde la propia pantalla de entrada, y queda guardado).
//
//  El armado de dependencias vive aquí y en ningún otro sitio: los servicios se
//  crean una vez, los repositorios los reciben, y las pantallas piden lo que
//  necesitan con `context.read`. Ver ARQUITECTURA.md.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/repositories/auth_repository.dart';
import 'data/repositories/avisos_repository.dart';
import 'data/repositories/debt_repository.dart';
import 'data/repositories/spend_repository.dart';
import 'data/repositories/tema_repository.dart';
import 'data/repositories/vehicle_repository.dart';
import 'data/services/api_client.dart';
import 'data/services/avisos_service.dart';
import 'data/services/comprobante.dart';
import 'data/services/session_store.dart';
import 'ui/auth/view_model/login_view_model.dart';
import 'ui/auth/widgets/login_screen.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/widgets/cascara.dart';
import 'ui/core/widgets/marca.dart';
import 'ui/core/widgets/sincroniza_avisos.dart';
import 'ui/summary/view_model/summary_view_model.dart';
import 'ui/summary/widgets/summary_screen.dart';

void main() {
  // Las fechas se escriben en español ("12 may", "martes, 12 de mayo"), así que
  // hay que cargar los datos del idioma antes de pintar nada.
  initializeDateFormatting('es');

  final api = ApiClient();
  final store = SessionStore();
  final avisos = AvisosService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        // La camara y la galeria: un servicio, no un repositorio, porque no
        // guarda nada — solo traduce lo que da el telefono a lo que pide la API.
        Provider<ComprobanteService>(create: (_) => ComprobanteService()),
        Provider<AvisosService>.value(value: avisos),
        ChangeNotifierProvider(
          create: (_) => AuthRepository(api: api, store: store),
        ),
        ChangeNotifierProvider(
          create: (_) => DebtRepository(api: api),
        ),
        ChangeNotifierProvider(
          create: (_) => SpendRepository(api: api),
        ),
        ChangeNotifierProvider(
          create: (_) => VehicleRepository(api: api),
        ),
        // El tema se lee al crearlo: es una preferencia del telefono, no de la
        // cuenta, asi que no espera a que nadie entre.
        ChangeNotifierProvider(
          create: (_) => TemaRepository()..restore(),
        ),
        // Los recordatorios: la preferencia es del telefono, asi que se lee al
        // arrancar sin esperar a que nadie entre.
        ChangeNotifierProvider(
          create: (_) => AvisosRepository(service: avisos)..restore(),
        ),
      ],
      child: const AppDeudas(),
    ),
  );
}

class AppDeudas extends StatelessWidget {
  const AppDeudas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deudas',
      debugShowCheckedModeBanner: false,
      theme: temaClaro,
      darkTheme: temaOscuro,
      // El que se haya elegido; por defecto, el del telefono.
      themeMode: context.watch<TemaRepository>().modo,
      home: const SincronizaAvisos(child: Puerta()),
    );
  }
}

/// Decide qué se ve: la pantalla de entrada o la app. Son dos estados, no un
/// mapa de rutas, así que no hace falta un router todavía.
class Puerta extends StatefulWidget {
  const Puerta({super.key});

  @override
  State<Puerta> createState() => _PuertaState();
}

class _PuertaState extends State<Puerta> {
  /// Mientras se comprueba la sesión guardada se muestra la marca, no un login
  /// que va a desaparecer en medio segundo.
  bool _comprobando = true;

  @override
  void initState() {
    super.initState();
    _restaurar();
  }

  Future<void> _restaurar() async {
    await context.read<AuthRepository>().restore();
    if (mounted) setState(() => _comprobando = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepository>();

    if (_comprobando) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Marca(size: 56),
              const SizedBox(height: 22),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.tk.faint),
              ),
            ],
          ),
        ),
      );
    }

    if (!auth.signedIn) {
      // El vaciado de los repositorios NO va aquí: avisar a quien escucha en
      // medio de un build es ilegal en Flutter. Se hace al cerrar sesión, que
      // es el único camino para llegar a este estado (ver ui/core/cerrar_sesion).
      return ChangeNotifierProvider(
        create: (_) => LoginViewModel(auth: auth),
        child: const LoginScreen(),
      );
    }

    // El dueño tiene deudas y gastos, asi que va con la barra de abajo. Quien
    // entra de solo lectura no tiene mas que su deuda: se le da la pantalla
    // sola, sin ofrecerle pestañas que la API le va a negar.
    return ChangeNotifierProvider(
      create: (_) => SummaryViewModel(debts: context.read<DebtRepository>()),
      child: auth.me?.isOwner == true ? const Cascara() : const SummaryScreen(),
    );
  }
}
