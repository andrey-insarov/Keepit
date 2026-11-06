// node --test functions/api — no network, no Workers runtime: the pure parts only.
import { test } from "node:test";
import assert from "node:assert/strict";
import { sniffImage, validate, TYPES, LIMITS, IMAGE_MAX_EDGE } from "./feedback.js";

const png = (w, h, depth = 8, colour = 6) => {
  const b = new Uint8Array(33);
  b.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], 0);
  b.set([0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52], 8);
  new DataView(b.buffer).setUint32(16, w); new DataView(b.buffer).setUint32(20, h);
  b[24] = depth; b[25] = colour;
  return b.buffer;
};

test("a bare PNG signature is not a PNG", () => {
  assert.equal(sniffImage(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0]).buffer), null);
  assert.equal(sniffImage(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).buffer), null);
});

test("a PNG with a sane IHDR is a PNG; absurd or invalid headers are not", () => {
  assert.equal(sniffImage(png(1280, 800)), "image/png");
  assert.equal(sniffImage(png(IMAGE_MAX_EDGE + 1, 10)), null);
  assert.equal(sniffImage(png(0, 10)), null);
  assert.equal(sniffImage(png(10, 10, 7)), null);
  assert.equal(sniffImage(png(10, 10, 8, 5)), null);
});

test("JPEG, GIF, WebP and HEIC need their first structure, not three bytes", () => {
  assert.equal(sniffImage(new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 16]).buffer), "image/jpeg");
  assert.equal(sniffImage(new Uint8Array([0xff, 0xd8, 0xff]).buffer), null);
  assert.equal(sniffImage(new Uint8Array([0xff, 0xd8, 0xff, 0x01]).buffer), null);
  const gif = new Uint8Array([...Buffer.from("GIF89a"), 0x10, 0x00, 0x08, 0x00]);
  assert.equal(sniffImage(gif.buffer), "image/gif");
  const gifHuge = new Uint8Array([...Buffer.from("GIF89a"), 0xff, 0xff, 0xff, 0xff]);
  assert.equal(sniffImage(gifHuge.buffer), null);
  const webp = new Uint8Array(20); webp.set(Buffer.from("RIFF"), 0); webp.set([12, 0, 0, 0], 4); webp.set(Buffer.from("WEBPVP8 "), 8);
  assert.equal(sniffImage(webp.buffer), "image/webp");
  webp.set([99, 0, 0, 0], 4);
  assert.equal(sniffImage(webp.buffer), null, "RIFF size must match the file");
  const heic = new Uint8Array(24); heic.set([0, 0, 0, 24], 0); heic.set(Buffer.from("ftypheic"), 4);
  assert.equal(sniffImage(heic.buffer), "image/heic");
  heic.set([0, 0, 1, 0], 0);
  assert.equal(sniffImage(heic.buffer), null, "ftyp box must fit the file");
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
