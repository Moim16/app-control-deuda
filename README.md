# Deudas — app nativa

La app de Android para lo mismo que hace la PWA: **lo que debo, lo que me deben y cómo va bajando**. Consume la **misma API** desplegada en Vercel, así que los saldos, los permisos y el "quién ve qué" ya vienen resueltos del servidor y aquí solo hay pantallas.

Hecha en **Flutter** (Dart), con la arquitectura que recomienda el equipo de Flutter. Ver [`ARQUITECTURA.md`](ARQUITECTURA.md).

---

## Por qué una app nativa si ya hay PWA

Tres cosas que la PWA no puede dar:

1. **Notificaciones push de verdad**, también en iPhone. Los recordatorios de "ya toca pagar" viven hoy dentro de la pantalla; una app puede avisar sin que la abras.
2. **Estar en la Play Store**, que es donde la gente busca las apps.
3. **La cámara y el almacenamiento nativos**, para la captura de un comprobante sin pasar por el selector del navegador.

Lo que **no** cambia: la API. No hay una línea de servidor distinta para la app.

---

## Cómo se corre

```bash
flutter pub get
flutter run --dart-define=API_URL=https://<tu-app>.vercel.app
```

El `API_URL` es opcional: si no se pasa, la app pide la dirección del servidor en la propia pantalla de entrada y la recuerda. Eso permite apuntar la misma app a producción o a la máquina de desarrollo sin recompilar.

> Contra el servidor local, el teléfono no llega a `localhost`: hay que usar la IP de la máquina en la red (`http://192.168.x.x:3000`) y tener `scripts/dev.mjs` corriendo. Desde el emulador de Android, `http://10.0.2.2:3000`.

```bash
flutter analyze     # sin avisos
flutter test        # 45 pruebas
flutter build apk   # el APK para instalar
```

En un Xiaomi con HyperOS hay que activar, dentro de *Opciones de desarrollador*,
**Depuración USB** y también **Instalar vía USB**; si no, `adb` responde
`INSTALL_FAILED_USER_RESTRICTED`. El teléfono vuelve a pedir confirmación cada
vez que la instalación es nueva y no una actualización — por ejemplo después de
cambiar el icono, que obliga a desinstalar.

### Lo que hace falta instalado

Flutter SDK, JDK 17 y el Android SDK (`platform-tools`, `platforms;android-36`, `build-tools;36.0.0`). **Android Studio no es necesario**: basta con las *command-line tools* del SDK, y se edita en VS Code con la extensión de Flutter. En esta máquina está todo bajo `C:\dev`.

---

## Qué hay hecho y qué falta

| | |
|---|---|
| ✅ | Entrar, con la sesión guardada y la dirección del servidor configurable |
| ✅ | Resumen: pestañas *Debo* / *Me deben*, totales por moneda, lo que toca pagar |
| ✅ | Ficha de una deuda: saldo, movimientos con su saldo corrido, comprobantes |
| ✅ | Comentarios: leer, escribir y borrar los propios |
| ✅ | Tema claro y oscuro, siguiendo el del teléfono |
| ✅ | Registrar préstamos y abonos, con comprobante de la cámara o la galería |
| ✅ | Corregir y borrar un movimiento |
| ⬜ | Crear una deuda nueva (se crean desde la web) |
| ⬜ | Gastos del hogar, ingresos y vehículo |
| ⬜ | Gráficos |
| ⬜ | Notificaciones push — la razón principal de tener app nativa |
| ⬜ | Publicar en la Play Store |

---

## Las decisiones que importan

**Las reglas de negocio no se repiten.** Los saldos y los totales por moneda llegan calculados de la API. Si la app los volviera a calcular, un día diría algo distinto a la web y habría que averiguar cuál de las dos miente.

La única cuenta que hace la app es la del **próximo pago** de un acuerdo, porque el servidor manda el acuerdo y no la fecha. Está en `domain/pago_esperado.dart` para poder probarla sin pantalla — y escribir esa prueba destapó un fallo que la web tenía desde el principio: quien nunca había pagado veía *"toca en 12 días"* en lugar de *"atrasado 50 días"*. Arreglado en las dos.

**Córdobas y dólares nunca se suman.** Los saldos van por moneda, y donde hay dos, la pantalla muestra las dos: *C$3,500 + US$100*. No hay tipo de cambio en esta app, así que sumarlas sería inventárselo.

**La misma deuda se lee al revés según quién mire.** El dueño ve *"le debo C$3,500"*; su hermano, que es el acreedor, ve *"me deben C$3,500"*. Todo ese vocabulario vive en `ui/core/vocabulario.dart`, igual que la constante `SIDE` de la web.

**El separador de miles se fija a mano.** Los datos de `es_NI` que trae `intl` usan el punto para los miles (`C$3.500`); en Nicaragua se escribe con coma (`C$3,500.50`), que es lo que ya muestra la web. Las dos apps tienen que decir lo mismo.

**El comprobante se recodifica a JPEG siempre.** La API solo lo acepta en JPEG, porque es el único formato que se puede incrustar tal cual en el PDF del estado de cuenta. Y hay que recodificar, no solo achicar: el comprobante más común es una captura de la transferencia, que es PNG, y `image_picker` en Android conserva el formato del original — pedirle calidad 82 no convierte un PNG en JPEG. Va en `data/services/comprobante.dart`, en otro isolate para que no se note el tirón, con fondo blanco por debajo (el JPEG no tiene transparencia: sin eso, lo transparente sale negro) y bajando calidad y tamaño hasta que quepa en el tope del servidor.

**La fecha se valida con ida y vuelta.** `DateTime.parse('2026-02-30')` no falla en Dart: devuelve el 2 de marzo. Sin comparar la fecha reconstruida con la que entró, el 30 de febrero pasaría la validación y se guardaría otro día. Es la misma vuelta que da `parseDay` en la API.

**El icono se genera con un script, no es un binario suelto.** `node tool/make_icons.mjs` dibuja los mipmaps de las cinco densidades pixel a pixel y codifica el PNG a mano con `zlib`, que ya viene en Node: cero dependencias de imagen y el icono se puede rehacer cuando cambie el diseño, en vez de quedar como un archivo que nadie sabe de dónde salió. La misma cartera se pinta dentro de la app con un `CustomPainter` (`ui/core/widgets/marca.dart`), así que se ve nítida a cualquier tamaño y toma los colores de los tokens.

La geometría está duplicada a propósito en `scripts/make-icons.mjs` del repo web: son dos repos, y acoplarlos por un dibujo de cuarenta líneas sería peor que copiarlo. Los comentarios de los dos avisan que tienen que decir lo mismo.
