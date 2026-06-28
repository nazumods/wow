// Generates icons/source.png — a 512x512 "void-dark" tile with a gold "W" wordmark,
// used as the source for `tauri icon`. No image deps: hand-rolled PNG encoder
// (deflate + CRC32) so the scaffold has no native build step just to make an icon.
import { deflateSync } from "node:zlib";
import { writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const SIZE = 512;
const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "..", "icons", "source.png");

// void-dark background (#0d0d0f) + gold accent (#ffd100)
const BG = [13, 13, 15];
const GOLD = [255, 209, 0];

// 5x5 bitmap for the letter "W", scaled up and centered.
const W = [
  [1, 0, 0, 0, 1],
  [1, 0, 0, 0, 1],
  [1, 0, 1, 0, 1],
  [1, 1, 0, 1, 1],
  [1, 0, 0, 0, 1],
];

const px = (x, y) => {
  const cell = SIZE / 8; // 8x8 grid; glyph occupies the middle 5x5
  const gx = Math.floor(x / cell) - 1;
  const gy = Math.floor(y / cell) - 1;
  if (gy >= 0 && gy < 5 && gx >= 0 && gx < 5 && W[gy][gx]) return GOLD;
  return BG;
};

// raw RGBA scanlines, each prefixed with a 0 filter byte
const raw = Buffer.alloc(SIZE * (1 + SIZE * 4));
let o = 0;
for (let y = 0; y < SIZE; y++) {
  raw[o++] = 0;
  for (let x = 0; x < SIZE; x++) {
    const [r, g, b] = px(x, y);
    raw[o++] = r;
    raw[o++] = g;
    raw[o++] = b;
    raw[o++] = 255;
  }
}

const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};

const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, "ascii");
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crc]);
};

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8; // bit depth
ihdr[9] = 6; // color type RGBA
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr),
  chunk("IDAT", deflateSync(raw, { level: 9 })),
  chunk("IEND", Buffer.alloc(0)),
]);

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, png);
console.log(`wrote ${out} (${png.length} bytes)`);
