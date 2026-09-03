// =============================================================================
//  El comprobante: de la cámara o la galería a lo que la API acepta.
//
//  La API exige `data:image/jpeg;base64,...` y no más de 900 KB. JPEG a
//  propósito, no por capricho: es el único formato que se puede incrustar tal
//  cual en el PDF del estado de cuenta que genera la web.
//
//  Y hay que recodificar SIEMPRE, no solo achicar:
//    - una captura de pantalla es PNG, y es justo el comprobante más común
//      (la transferencia del banco);
//    - `image_picker` en Android conserva el formato del original, así que
//      pedirle calidad 82 no convierte un PNG en JPEG.
//
//  El trabajo pesado va en otro isolate (`compute`): decodificar una imagen
//  bloquea el hilo de la interfaz lo suficiente para que se note el tirón.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// De dónde sale la imagen.
enum Origen { camara, galeria }

/// Lo que puede salir mal, ya contado en español. La UI lo muestra tal cual.
class ComprobanteError implements Exception {
  ComprobanteError(this.message);
  final String message;
  @override
  String toString() => message;
}

class ComprobanteService {
  ComprobanteService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// El lado mayor de la imagen que se sube. El mismo `RECEIPT_MAX` de la web:
  /// de sobra para leer un número de transferencia, y no manda una foto de 4 MB.
  static const _maxLado = 1280;

  /// El tope real es 900 KB en el servidor; se deja margen porque lo que cuenta
  /// es el largo del data URI, no el del JPEG.
  static const _maxDataUri = 850 * 1024;

  /// Elige una imagen y la devuelve lista para subir, o null si se canceló.
  Future<String?> elegir(Origen origen) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: origen == Origen.camara ? ImageSource.camera : ImageSource.gallery,
        // Que Android haga el primer achique por su cuenta: es nativo y rápido,
        // y así lo que se decodifica aquí ya es una imagen chica.
        maxWidth: _maxLado.toDouble(),
        maxHeight: _maxLado.toDouble(),
        imageQuality: 90,
      );
    } catch (_) {
      // Permiso denegado, cámara ocupada, un proveedor de galería que falla.
      throw ComprobanteError('No se pudo abrir ${origen == Origen.camara ? 'la cámara' : 'la galería'}.');
    }
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw ComprobanteError('No se pudo leer el archivo.');
    }
    if (bytes.isEmpty) throw ComprobanteError('Esa imagen está vacía.');

    final uri = await compute(aJpegDataUri, bytes);
    if (uri == null) {
      throw ComprobanteError(
        'La imagen es demasiado pesada. Prueba con una captura más pequeña.',
      );
    }
    return uri;
  }
}

/// Los intentos, del que se ve mejor al que pesa menos: primero se baja la
/// calidad al tamaño bueno, y solo si aun no cabe se empieza a achicar.
///
/// Hace falta llegar hasta 640: una foto de doce megapixeles llena de detalle
/// (una hoja impresa, un patio con hojas) no cabe en 850 KB ni a calidad 50 con
/// el lado en 1280, y rendirse ahi dejaria a la persona con un "es demasiado
/// pesada" y ninguna salida. A 640 se sigue leyendo un numero de transferencia.
const _intentos = <(int, int)>[
  (1280, 82), (1280, 70), (1280, 60),
  (1024, 60),
  (800, 55),
  (640, 45),
];

/// Convierte cualquier imagen en el data URI JPEG que acepta la API, o null si
/// no hay forma de que quepa.
///
/// Está fuera de la clase y es de nivel superior porque `compute` necesita una
/// función que se pueda mandar a otro isolate.
@visibleForTesting
String? aJpegDataUri(Uint8List bytes) {
  final img.Image? decodificada;
  try {
    decodificada = img.decodeImage(bytes);
  } catch (_) {
    // Un archivo truncado o que no es una imagen no devuelve null: revienta
    // leyendo la cabecera.
    throw ComprobanteError('Eso no parece una imagen.');
  }
  if (decodificada == null) throw ComprobanteError('Eso no parece una imagen.');

  int? ladoListo;
  img.Image? lista;
  for (final (lado, calidad) in _intentos) {
    // El achique se rehace solo cuando cambia el lado, no en cada calidad.
    if (lado != ladoListo) {
      lista = _sinTransparencia(_escalar(decodificada, lado));
      ladoListo = lado;
    }
    final uri = 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(lista!, quality: calidad))}';
    if (uri.length <= ComprobanteService._maxDataUri) return uri;
  }
  return null;
}

/// Achica por el lado mayor, guardando la proporción. Nunca agranda: una foto
/// chica se sube como está.
img.Image _escalar(img.Image im, int maxLado) {
  final mayor = im.width > im.height ? im.width : im.height;
  if (mayor <= maxLado) return im;
  return img.copyResize(
    im,
    width: im.width >= im.height ? maxLado : null,
    height: im.height > im.width ? maxLado : null,
    interpolation: img.Interpolation.average,
  );
}

/// Aplasta la imagen contra un fondo blanco. Un PNG puede traer transparencia y
/// el JPEG no la tiene: sin esto, lo transparente sale NEGRO y una captura con
/// fondo claro queda ilegible.
img.Image _sinTransparencia(img.Image im) {
  final plana = img.Image(width: im.width, height: im.height)
    ..clear(img.ColorRgb8(255, 255, 255));
  img.compositeImage(plana, im);
  return plana;
}

/// Los bytes de un data URI, para pintarlo con `Image.memory`. null si viene
/// algo que no se puede leer.
///
/// Está aquí porque lo necesitan las dos pantallas que muestran comprobantes:
/// la que lo elige y la que lo mira.
Uint8List? bytesDeDataUri(String? dataUri) {
  if (dataUri == null) return null;
  final coma = dataUri.indexOf(',');
  if (coma < 0) return null;
  try {
    return base64Decode(dataUri.substring(coma + 1));
  } catch (_) {
    return null;
  }
}
