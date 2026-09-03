// El comprobante tiene que salir en JPEG sí o sí: la API rechaza cualquier otra
// cosa, y una captura de pantalla —el comprobante más común— es PNG.

import 'package:deudas_app/data/services/comprobante.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Una imagen de prueba con algo dibujado, para que el JPEG no salga vacío.
img.Image lienzo(int w, int h, {bool conAlfa = false}) {
  final im = img.Image(width: w, height: h, numChannels: conAlfa ? 4 : 3);
  img.fill(im, color: conAlfa ? img.ColorRgba8(0, 0, 0, 0) : img.ColorRgb8(255, 255, 255));
  img.fillRect(im, x1: 0, y1: 0, x2: w ~/ 2, y2: h ~/ 2, color: img.ColorRgb8(20, 20, 25));
  return im;
}

void main() {
  test('un PNG sale convertido a JPEG', () {
    final png = img.encodePng(lienzo(400, 300));
    final uri = aJpegDataUri(png)!;

    expect(uri, startsWith('data:image/jpeg;base64,'));
    // El mismo patrón que valida la API.
    expect(RegExp(r'^data:image/jpeg;base64,[A-Za-z0-9+/=]+$').hasMatch(uri), isTrue);
  });

  test('lo que sale se puede volver a leer y es un JPEG de verdad', () {
    final uri = aJpegDataUri(img.encodePng(lienzo(400, 300)))!;
    final bytes = bytesDeDataUri(uri)!;

    // Firma de JPEG: FF D8 FF.
    expect(bytes.take(3), [0xFF, 0xD8, 0xFF]);
    final vuelta = img.decodeImage(bytes)!;
    expect(vuelta.width, 400);
    expect(vuelta.height, 300);
  });

  test('una imagen grande se achica al lado mayor, guardando la proporción', () {
    final uri = aJpegDataUri(img.encodeJpg(lienzo(3000, 2000)))!;
    final vuelta = img.decodeImage(bytesDeDataUri(uri)!)!;

    expect(vuelta.width, 1280);
    expect(vuelta.height, closeTo(853, 1));
  });

  test('una imagen vertical también, por el lado que le toca', () {
    final uri = aJpegDataUri(img.encodeJpg(lienzo(1000, 2500)))!;
    final vuelta = img.decodeImage(bytesDeDataUri(uri)!)!;

    expect(vuelta.height, 1280);
    expect(vuelta.width, closeTo(512, 1));
  });

  test('una imagen chica no se agranda', () {
    final uri = aJpegDataUri(img.encodePng(lienzo(200, 120)))!;
    final vuelta = img.decodeImage(bytesDeDataUri(uri)!)!;

    expect(vuelta.width, 200);
    expect(vuelta.height, 120);
  });

  test('lo transparente queda blanco, no negro', () {
    // Sin fondo blanco, el JPEG pinta de negro lo que era transparente y una
    // captura con fondo claro se vuelve ilegible.
    final uri = aJpegDataUri(img.encodePng(lienzo(60, 60, conAlfa: true)))!;
    final vuelta = img.decodeImage(bytesDeDataUri(uri)!)!;

    final esquina = vuelta.getPixel(59, 59);
    expect(esquina.r, greaterThan(240));
    expect(esquina.g, greaterThan(240));
    expect(esquina.b, greaterThan(240));
  });

  test('cabe en el tope que acepta el servidor', () {
    // Una foto llena de ruido es el peor caso para el JPEG: si esta cabe,
    // cualquier comprobante cabe.
    final ruido = img.Image(width: 3000, height: 3000);
    for (var y = 0; y < ruido.height; y++) {
      for (var x = 0; x < ruido.width; x++) {
        ruido.setPixelRgb(x, y, (x * 7 + y * 13) % 256, (x * 31) % 256, (y * 17) % 256);
      }
    }
    final uri = aJpegDataUri(img.encodeJpg(ruido, quality: 100))!;

    expect(uri.length, lessThanOrEqualTo(850 * 1024));

    // Y no a costa de dejarla ilegible: un numero de transferencia se tiene que
    // seguir leyendo.
    final vuelta = img.decodeImage(bytesDeDataUri(uri)!)!;
    expect(vuelta.width, greaterThanOrEqualTo(640));
  });

  test('lo que no es una imagen se dice, no se manda', () {
    expect(
      () => aJpegDataUri(img.encodePng(lienzo(2, 2)).sublist(0, 4)),
      throwsA(isA<ComprobanteError>()),
    );
  });

  group('leer un data URI', () {
    test('un URI sin coma no revienta', () {
      expect(bytesDeDataUri('data:image/jpeg;base64'), isNull);
      expect(bytesDeDataUri(null), isNull);
    });

    test('base64 roto no revienta', () {
      expect(bytesDeDataUri('data:image/jpeg;base64,####'), isNull);
    });
  });
}
