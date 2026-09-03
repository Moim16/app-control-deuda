// =============================================================================
//  Genera los iconos de Android a partir de la misma geometria que usa la PWA.
//
//    node tool/make_icons.mjs
//
//  Dibuja pixel a pixel y codifica el PNG a mano con `zlib`, que ya viene en
//  Node: cero dependencias de imagen y el icono se puede regenerar cuando
//  cambie el diseño. Es el mismo enfoque que `scripts/make-icons.mjs` del
//  proyecto web, y la geometria de abajo es LA MISMA a proposito: el icono de
//  la app instalada desde la tienda y el de la instalada desde el navegador
//  tienen que ser el mismo icono.
//
//  Genera:
//    mipmap-*/ic_launcher.png             el icono de siempre (Android 7 y antes)
//    mipmap-*/ic_launcher_foreground.png  la capa de dibujo del icono adaptativo
//    mipmap-anydpi-v26/ic_launcher.xml    el icono adaptativo (Android 8+)
//    values/ic_launcher_background.xml    el color de fondo de esa capa
// =============================================================================

import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const RES = join(ROOT, 'android', 'app', 'src', 'main', 'res');

/* ------------------------------------------------------------- geometria ----
   Todo en un lienzo de 512x512: una cartera.

   Se probaron dos cosas antes:
     - una flecha hacia abajo sobre un billete: a tamaño de lanzador es el
       icono universal de DESCARGA;
     - tres monedas apiladas de canto: es el icono universal de BASE DE DATOS.
   Una cartera no se confunde con nada, se lee a 48px y ademas es el icono que
   la propia app usa para "Deuda", asi que el lanzador y la pantalla dicen lo
   mismo.
--------------------------------------------------------------------------- */
const FONDO = [0x18, 0x18, 0x1b];    // el mismo --ink de la app
const CARTERA = [0xf4, 0xf4, 0xf5];  // y el mismo --ink del tema oscuro

// El cuerpo de la cartera.
const CUERPO = { x: 84, y: 156, w: 344, h: 216, r: 44 };
// El bolsillo de la tarjeta, en oscuro sobre el cuerpo: es lo que la hace
// reconocible de un vistazo.
const BOLSILLO = { x: 300, y: 222, w: 148, h: 84, r: 30 };
// El broche.
const BROCHE = { cx: 368, cy: 264, r: 17 };

const dist = (x, y, px, py) => Math.hypot(x - px, y - py);

function enRectRedondeado(x, y, { x: rx, y: ry, w, h, r }) {
  const cx = Math.max(rx + r, Math.min(x, rx + w - r));
  const cy = Math.max(ry + r, Math.min(y, ry + h - r));
  return dist(x, y, cx, cy) <= r
      || (x >= rx && x <= rx + w && y >= ry + r && y <= ry + h - r)
      || (y >= ry && y <= ry + h && x >= rx + r && x <= rx + w - r);
}

/// El color en un punto, o null si ahi no hay nada que pintar.
///
///   `fondo`: si se pinta el cuadrado oscuro. La capa de dibujo del icono
///            adaptativo va TRANSPARENTE, porque el fondo lo pone Android.
///   `sangre`: el cuadrado ocupa todo el lienzo, sin esquinas redondeadas.
function colorEn(x, y, { fondo = true, sangre = false } = {}) {
  if (enRectRedondeado(x, y, CUERPO)) {
    // El broche va encima del bolsillo, y el bolsillo encima del cuerpo.
    if (dist(x, y, BROCHE.cx, BROCHE.cy) <= BROCHE.r) return CARTERA;
    if (enRectRedondeado(x, y, BOLSILLO)) return fondo ? FONDO : null;
    return CARTERA;
  }
  if (!fondo) return null;
  const dentro = sangre
    ? true
    : enRectRedondeado(x, y, { x: 0, y: 0, w: 512, h: 512, r: 96 });
  return dentro ? FONDO : null;
}

/* ----------------------------------------------------------- rasterizado ---- */
const SS = 4;   // submuestreo, para que los bordes no queden dentados

function dibujar(size, { fondo = true, sangre = false, escala = 1 } = {}) {
  const px = Buffer.alloc(size * size * 4);
  const off = (512 - 512 * escala) / 2;

  for (let py = 0; py < size; py++) {
    for (let pxx = 0; pxx < size; pxx++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const u = ((pxx + (sx + 0.5) / SS) / size) * 512;
          const v = ((py + (sy + 0.5) / SS) / size) * 512;
          const c = colorEn((u - off) / escala, (v - off) / escala, { fondo, sangre });
          if (c) { r += c[0]; g += c[1]; b += c[2]; a += 255; }
        }
      }
      const n = SS * SS;
      const i = (py * size + pxx) * 4;
      const cuenta = a / 255;
      px[i] = cuenta ? Math.round(r / cuenta) : 0;
      px[i + 1] = cuenta ? Math.round(g / cuenta) : 0;
      px[i + 2] = cuenta ? Math.round(b / cuenta) : 0;
      px[i + 3] = Math.round(a / n);
    }
  }
  return px;
}

/* ------------------------------------------------------------------ PNG ----- */
const TABLA_CRC = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = TABLA_CRC[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(tipo, datos) {
  const largo = Buffer.alloc(4);
  largo.writeUInt32BE(datos.length);
  const cuerpo = Buffer.concat([Buffer.from(tipo, 'ascii'), datos]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(cuerpo));
  return Buffer.concat([largo, cuerpo, crc]);
}

function png(size, pixeles) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;   // 8 bits por canal
  ihdr[9] = 6;   // RGBA

  // Cada linea lleva delante su byte de filtro (0 = sin filtro).
  const crudo = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    crudo[y * (size * 4 + 1)] = 0;
    pixeles.copy(crudo, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(crudo, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/* --------------------------------------------------------------- salida ----- */
// Las densidades de Android: el icono clasico es de 48dp y la capa del
// adaptativo de 108dp, cada uno multiplicado por la densidad de la pantalla.
const DENSIDADES = [
  ['mipmap-mdpi', 1],
  ['mipmap-hdpi', 1.5],
  ['mipmap-xhdpi', 2],
  ['mipmap-xxhdpi', 3],
  ['mipmap-xxxhdpi', 4],
];

let total = 0;
for (const [carpeta, d] of DENSIDADES) {
  const dir = join(RES, carpeta);
  mkdirSync(dir, { recursive: true });

  // El clasico: 48dp con su cuadrado redondeado.
  const size = Math.round(48 * d);
  const clasico = png(size, dibujar(size));
  writeFileSync(join(dir, 'ic_launcher.png'), clasico);
  total += clasico.length;

  // La capa de dibujo del adaptativo: 108dp, transparente y con el dibujo al
  // 62% para que quede dentro de la zona que Android no recorta (66%).
  const fgSize = Math.round(108 * d);
  const fg = png(fgSize, dibujar(fgSize, { fondo: false, escala: 0.62 }));
  writeFileSync(join(dir, 'ic_launcher_foreground.png'), fg);
  total += fg.length;

  console.log(`  ${carpeta.padEnd(16)} ${size}x${size} + ${fgSize}x${fgSize}`);
}

// El icono adaptativo de Android 8+: una capa de color y una de dibujo.
const anydpi = join(RES, 'mipmap-anydpi-v26');
mkdirSync(anydpi, { recursive: true });
writeFileSync(
  join(anydpi, 'ic_launcher.xml'),
  `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
`,
);

const values = join(RES, 'values');
mkdirSync(values, { recursive: true });
writeFileSync(
  join(values, 'ic_launcher_background.xml'),
  `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- El mismo negro que el token \`ink\` de la app. (Ojo: un comentario
         XML no admite dos guiones seguidos, asi que no se puede escribir el
         nombre de la variable CSS tal cual.) -->
    <color name="ic_launcher_background">#18181B</color>
</resources>
`,
);

console.log(`\nIconos generados (${(total / 1024).toFixed(1)} KB en total).`);
