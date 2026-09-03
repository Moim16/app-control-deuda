# Arquitectura

La que **recomienda el equipo de Flutter** ([Architecture guide](https://docs.flutter.dev/app-architecture)): MVVM por capas, organizada por *feature*. No es una elección de gusto: es la que sale en la documentación oficial y la que espera cualquiera que abra el proyecto.

```
lib/
  main.dart                     arranque y cableado de dependencias
  routing/                      las rutas (go_router)
  domain/models/                qué es una deuda, un movimiento, un comentario
  data/
    services/                   habla con el mundo: HTTP, almacenamiento, cámara
    repositories/               la fuente de verdad de la app
  ui/
    core/                       tema, formato, vocabulario, widgets compartidos
    <feature>/
      view_model/               el estado y las acciones de esa pantalla
      widgets/                  la pantalla y sus piezas
  utils/                        Result y Command
```

## La regla que ordena todo: cada capa solo conoce a la de abajo

```
ui  ─────►  data  ─────►  (API / almacenamiento)
 │            │
 └────────────┴──────────►  domain
```

- **`ui`** pinta y recibe toques. Una `View` (widget) no sabe qué es HTTP; le pide todo a su `ViewModel`.
- **`data/repositories`** es a lo que la UI le pregunta. Decide de dónde sale el dato y guarda lo que hay en memoria para no volver a pedirlo.
- **`data/services`** es lo único que sabe de `http`, de `shared_preferences` y de la cámara. Si mañana cambia el transporte, se cambia aquí y nada más.
- **`domain/models`** también lleva las reglas de qué es un dato válido cuando son del negocio y no del formulario: `EntryDraft` sabe que un monto tiene que ser mayor que cero y que la fecha no puede ser de pasado mañana, y por eso se prueba sin pantalla.
- **`domain/models`** son objetos de datos sin comportamiento ni dependencias. Los conocen todas las capas.

**Nunca al revés.** Un repositorio no importa nada de `ui`; un modelo no importa nada de nadie. Es lo que permite probar la lógica sin levantar la app.

## Por qué un ViewModel por pantalla

Un `ViewModel` es un `ChangeNotifier` con dos cosas: el **estado** que la pantalla necesita y los **comandos** que puede ejecutar. La vista lo escucha y se repinta sola.

Eso resuelve el problema que tenía la versión web: allá había un objeto `S` global y había que acordarse de llamar a `renderHome()` en el sitio correcto. Si se olvidaba, la pantalla mentía. Aquí no hay repintado manual.

## Result en vez de excepciones que cruzan capas

Los servicios lanzan `ApiException`. Los repositorios la atrapan y devuelven `Result<T>` — `Ok` o `Err` con un mensaje ya escrito para leerse. Así **la UI nunca hace `try/catch`**: pregunta si salió bien y, si no, muestra el mensaje.

```dart
switch (await repo.summary()) {
  Ok(:final value) => _mostrar(value),
  Err(:final message) => _error(message),
}
```

## Command para los botones que llaman a la red

Un botón que dispara una petición necesita tres cosas siempre: saber si está corriendo (para deshabilitarse y mostrar la ruedita), guardar el error si falló, y no dispararse dos veces si le dan doble toque. `Command` lo tiene resuelto una vez, en `utils/command.dart`, en lugar de tres `bool _cargando` repartidos por pantalla.

## Lo que NO está aquí

**Reglas de negocio.** Los saldos, los totales por moneda, quién puede ver qué: eso lo resuelve la API y llega ya calculado. Si la app volviera a calcular saldos por su cuenta, un día diría algo distinto a la web, y el que tendría que averiguar cuál de las dos miente sería yo.

La única cuenta que la app hace es la del **próximo pago** de un acuerdo (`domain/pago_esperado.dart`), porque el servidor manda el acuerdo, no la fecha; y está en `domain` justo para poder probarla sin pantalla.

## El vocabulario, en un solo lugar

La misma deuda se cuenta al revés según quién mire: el dueño ve *"le debo C$3,500"*, su hermano ve *"me deben C$3,500"*. Todas esas palabras viven en `ui/core/vocabulario.dart`, igual que la constante `SIDE` de la web. Si hay que agregar una frase, se agrega a las dos entradas — nunca un `if (esCobro)` suelto en una pantalla.
