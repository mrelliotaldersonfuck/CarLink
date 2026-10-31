// Dependency-free icon generator. Run with Node 18+ only when changing the artwork.
import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const size = 1024;
const raw = Buffer.alloc((size * 3 + 1) * size);
function roundedRect(x, y, cx, cy, width, height, radius) {
  const dx = Math.abs(x - cx) - width / 2 + radius;
  const dy = Math.abs(y - cy) - height / 2 + radius;
  return Math.hypot(Math.max(dx, 0), Math.max(dy, 0)) + Math.min(Math.max(dx, dy), 0) - radius;
}
function triangle(x, y) {
  return x >= 435 && x <= 665 && Math.abs(y - 485) <= (665 - x) * 0.66;
}
function pixel(x, y) {
  const glow = Math.max(0, 1 - Math.hypot(x - 250, y - 170) / 1000);
  let color = [9 + glow * 9, 16 + glow * 22, 30 + glow * 20];
  const outer = roundedRect(x, y, 512, 478, 704, 492, 100);
  const inner = roundedRect(x, y, 512, 478, 646, 434, 72);
  if (outer < 0 && inner >= 0) color = [109, 246, 195];
  if (triangle(x, y)) color = [109, 246, 195];
  if (roundedRect(x, y, 512, 816, 270, 34, 17) < 0) color = [240, 176, 96];
  if (roundedRect(x, y, 512, 754, 34, 66, 12) < 0) color = [109, 246, 195];
  return color;
}
for (let y = 0; y < size; y++) {
  const row = y * (size * 3 + 1);
  raw[row] = 0;
  for (let x = 0; x < size; x++) {
    const sum = [0, 0, 0];
    for (const oy of [0.25, 0.75]) for (const ox of [0.25, 0.75]) {
      pixel(x + ox, y + oy).forEach((v, c) => { sum[c] += v / 4; });
    }
    sum.forEach((v, c) => { raw[row + 1 + x * 3 + c] = Math.round(v); });
  }
}
const table = Array.from({ length: 256 }, (_, i) => {
  let c = i;
  for (let n = 0; n < 8; n++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function chunk(type, bytes) {
  const label = Buffer.from(type);
  const body = Buffer.concat([label, bytes]);
  let crc = 0xffffffff;
  for (const byte of body) crc = table[(crc ^ byte) & 255] ^ (crc >>> 8);
  const result = Buffer.alloc(bytes.length + 12);
  result.writeUInt32BE(bytes.length, 0);
  body.copy(result, 4);
  result.writeUInt32BE((crc ^ 0xffffffff) >>> 0, result.length - 4);
  return result;
}
const header = Buffer.alloc(13);
header.writeUInt32BE(size, 0); header.writeUInt32BE(size, 4); header[8] = 8; header[9] = 2;
const output = fileURLToPath(new URL('../CarLink/Assets.xcassets/AppIcon.appiconset/AppIcon.png', import.meta.url));
mkdirSync(fileURLToPath(new URL('../CarLink/Assets.xcassets/AppIcon.appiconset/', import.meta.url)), { recursive: true });
writeFileSync(output, Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk('IHDR', header), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))
]));
console.log('AppIcon.png: 1024×1024 RGB, no alpha');
