// node --test functions/api — no network, no Workers runtime: the pure parts only.
import { test } from "node:test";
import assert from "node:assert/strict";
import { sniffImage, validate, TYPES, LIMITS, IMAGE_MAX_EDGE } from "./feedback.js";

const png = (w, h, depth = 8, colour = 6, complete = true) => {
  const b = new Uint8Array(complete ? 45 : 33);
  b.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], 0);
  b.set([0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52], 8);
  new DataView(b.buffer).setUint32(16, w); new DataView(b.buffer).setUint32(20, h);
  b[24] = depth; b[25] = colour;
  if (complete) { b.set([0, 0, 0, 0, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82], 33); }
  return b.buffer;
};
const jpeg = (w, h, { eoi = true, sof = true } = {}) => {
  // SOI, APP0 (JFIF, 16 bytes), SOF0 (height, width, 1 component), EOI
  const out = [0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00];
  if (sof) out.push(0xff, 0xc0, 0x00, 0x0b, 0x08, h >> 8, h & 0xff, w >> 8, w & 0xff, 0x01, 0x01, 0x11, 0x00);
  if (eoi) out.push(0xff, 0xd9);
  return new Uint8Array(out).buffer;
};

test("a bare PNG signature is not a PNG", () => {
  assert.equal(sniffImage(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0]).buffer), null);
  assert.equal(sniffImage(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).buffer), null);
});

test("a PNG needs a sane IHDR and an IEND at the end", () => {
  assert.equal(sniffImage(png(1280, 800)), "image/png");
  assert.equal(sniffImage(png(1280, 800, 8, 6, false)), null, "truncated: no IEND");
  assert.equal(sniffImage(png(IMAGE_MAX_EDGE + 1, 10)), null);
  assert.equal(sniffImage(png(0, 10)), null);
  assert.equal(sniffImage(png(10, 10, 7)), null);
  assert.equal(sniffImage(png(10, 10, 8, 5)), null);
});

test("a JPEG needs segments that fit, a frame header with a sane size, and EOI", () => {
  assert.equal(sniffImage(jpeg(640, 480)), "image/jpeg");
  assert.equal(sniffImage(new Uint8Array([0xff, 0xd8, 0xff, 0xe0]).buffer), null, "four bytes are not a JPEG");
  assert.equal(sniffImage(new Uint8Array([0xff, 0xd8, 0xff]).buffer), null);
  assert.equal(sniffImage(jpeg(640, 480, { eoi: false })), null, "no EOI");
  assert.equal(sniffImage(jpeg(640, 480, { sof: false })), null, "no frame header");
  assert.equal(sniffImage(jpeg(IMAGE_MAX_EDGE + 1, 10)), null);
  assert.equal(sniffImage(jpeg(0, 10)), null);
});

test("GIF, WebP and HEIC need their structure and, where the format has one, their end", () => {
  const gif = new Uint8Array([...Buffer.from("GIF89a"), 0x10, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x3b]);
  assert.equal(sniffImage(gif.buffer), "image/gif");
  assert.equal(sniffImage(gif.subarray(0, 10).buffer.slice(0, 10)), null, "no trailer");
  const gifHuge = new Uint8Array([...Buffer.from("GIF89a"), 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0x3b]);
  assert.equal(sniffImage(gifHuge.buffer), null);
  const webp = new Uint8Array(30); webp.set(Buffer.from("RIFF"), 0); webp.set([22, 0, 0, 0], 4); webp.set(Buffer.from("WEBPVP8 "), 8); webp.set([10, 0, 0, 0], 16);
  assert.equal(sniffImage(webp.buffer), "image/webp");
  webp.set([99, 0, 0, 0], 4);
  assert.equal(sniffImage(webp.buffer), null, "RIFF size must match the file");
  webp.set([22, 0, 0, 0], 4); webp.set([99, 0, 0, 0], 16);
  assert.equal(sniffImage(webp.buffer), null, "chunk size must fit the file");
  const heic = new Uint8Array(40); heic.set([0, 0, 0, 24], 0); heic.set(Buffer.from("ftypheic"), 4); heic.set([0, 0, 0, 16], 24); heic.set(Buffer.from("meta"), 28);
  assert.equal(sniffImage(heic.buffer), "image/heic");
  heic.set([0, 0, 1, 0], 24);
  assert.equal(sniffImage(heic.buffer), null, "meta box must fit the file");
  heic.set([0, 0, 0, 16], 24); heic.set(Buffer.from("mdat"), 28);
  assert.equal(sniffImage(heic.buffer), null, "ftyp must be followed by meta");
  const ftypOnly = new Uint8Array(24); ftypOnly.set([0, 0, 0, 24], 0); ftypOnly.set(Buffer.from("ftypheic"), 4);
  assert.equal(sniffImage(ftypOnly.buffer), null, "ftyp alone is not an image");
});

const form = (fields) => ({
  get: (k) => fields[k] ?? null,
  getAll: (k) => (Array.isArray(fields[k]) ? fields[k] : fields[k] ? [fields[k]] : []),
  entries: () => Object.entries(fields).filter(([, v]) => typeof v === "string"),
});
const good = { name: "A", email: "a@example.test", type: "app", message: "x".repeat(LIMITS.messageMin) };

test("type must be an own key of TYPES — prototype names are refused with a 400-style result", () => {
  assert.equal(validate(form(good)).ok, true);
  for (const t of ["constructor", "__proto__", "toString", "hasOwnProperty", "", "App issue"]) {
    const r = validate(form({ ...good, type: t }));
    assert.equal(r.ok, false, t);
    assert.match(r.error, /what the message is about/);
  }
  assert.equal(Object.getPrototypeOf(TYPES), null);
  assert.ok(Object.isFrozen(TYPES));
});
