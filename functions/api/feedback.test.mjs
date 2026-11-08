// node --test functions/api — no network, no Workers runtime: the pure parts only.
import { test } from "node:test";
import assert from "node:assert/strict";
import { sniffImage, validate, TYPES, LIMITS, IMAGE_MAX_EDGE, turnstileVerdict, allowedTurnstileHostnames, confirmationEmail, DEFAULT_TURNSTILE_HOSTNAMES } from "./feedback.js";

import { deflateSync } from "node:zlib";

const crcTable = Array.from({ length: 256 }, (_, i) => { let c = i; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc32 = (bytes) => { let c = 0xffffffff; for (const x of bytes) c = crcTable[(c ^ x) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const be32 = (v) => [(v >>> 24) & 255, (v >>> 16) & 255, (v >>> 8) & 255, v & 255];
const le32 = (v) => [v & 255, (v >>> 8) & 255, (v >>> 16) & 255, (v >>> 24) & 255];
const chunk = (type, data = []) => { const t = [...Buffer.from(type), ...data]; return [...be32(data.length), ...t, ...be32(crc32(t))]; };
const buf = (arr) => Uint8Array.from(arr).buffer;

/** A real PNG: IHDR, a zlib-compressed row of pixels in IDAT, IEND. */
const png = (w, h, { depth = 8, colour = 6, idat = true, iend = true, badCRC = false } = {}) => {
  const ihdr = chunk("IHDR", [...be32(w), ...be32(h), depth, colour, 0, 0, 0]);
  if (badCRC) ihdr[ihdr.length - 1] ^= 0xff;
  const bpp = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colour] * Math.ceil(depth / 8);
  const raw = Buffer.alloc((1 + w * bpp) * h);
  const data = idat ? chunk("IDAT", [...deflateSync(raw)]) : [];
  return buf([137, 80, 78, 71, 13, 10, 26, 10, ...ihdr, ...data, ...(iend ? chunk("IEND") : [])]);
};
/** A valid baseline 1×1 greyscale JPEG built per T.81: DQT, SOF0, two one-code Huffman tables, a scan of two bits, EOI. */
const jpegBytes = (() => {
  const dqt = [0xff, 0xdb, 0x00, 0x43, 0x00, ...new Array(64).fill(1)];
  const sof0 = [0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00];
  const dht = (cls) => [0xff, 0xc4, 0x00, 0x14, cls << 4, 1, ...new Array(15).fill(0), 0x00];
  const sos = [0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00];
  return [0xff, 0xd8, ...dqt, ...sof0, ...dht(0), ...dht(1), ...sos, 0x3f, 0xff, 0xd9];
})();
const jpeg = ({ eoi = true, scan = true } = {}) => {
  let a = [...jpegBytes];
  if (!scan) a = a.slice(0, a.indexOf(0xda, 2) - 1).concat([0xff, 0xd9]);
  if (!eoi) a = a.slice(0, -2);
  return buf(a);
};
/** A valid 1×1 GIF89a: global table of two colours, one image with a two-byte LZW stream, trailer. */
const gifBytes = [...Buffer.from("GIF89a"), 1, 0, 1, 0, 0x80, 0, 0, 0, 0, 0, 255, 255, 255, 0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b];
/** A lossless WebP per the container spec: VP8L signature, 14-bit dimensions, a bitstream. */
const webp = ({ payload = [0x2f, 0, 0, 0, 0, 0x07, 0x10, 0x11, 0x11, 0x88, 0x88, 0xfe, 0x07, 0], riffSize } = {}) => {
  const body = [...Buffer.from("WEBP"), ...Buffer.from("VP8L"), ...le32(payload.length), ...payload, ...(payload.length & 1 ? [0] : [])];
  return buf([...Buffer.from("RIFF"), ...le32(riffSize ?? body.length), ...body]);
};
/** A HEIF skeleton: ftyp, meta with a "pict" handler, mdat with bytes. */
const heic = ({ handler = "pict", mdatBytes = 16, metaFits = true } = {}) => {
  const hdlr = [...be32(33), ...Buffer.from("hdlr"), 0, 0, 0, 0, 0, 0, 0, 0, ...Buffer.from(handler), ...new Array(13).fill(0)];
  const meta = [...be32(metaFits ? 12 + hdlr.length : 0x10000), ...Buffer.from("meta"), 0, 0, 0, 0, ...hdlr];
  const mdat = mdatBytes > 0 ? [...be32(8 + mdatBytes), ...Buffer.from("mdat"), ...new Array(mdatBytes).fill(1)] : [];
  return buf([...be32(24), ...Buffer.from("ftypheic"), 0, 0, 0, 0, ...Buffer.from("mif1"), ...Buffer.from("heic"), ...meta, ...mdat]);
};

test("real images are recognised", () => {
  assert.equal(sniffImage(png(2, 2)), "image/png");
  assert.equal(sniffImage(png(1, 1, { depth: 1, colour: 0 })), "image/png");
  assert.equal(sniffImage(jpeg()), "image/jpeg");
  assert.equal(sniffImage(buf(gifBytes)), "image/gif");
  assert.equal(sniffImage(webp()), "image/webp");
  assert.equal(sniffImage(heic()), "image/heic");
});

test("a header with the right footer is not an image: pixel data is required", () => {
  assert.equal(sniffImage(png(1, 1, { idat: false })), null, "PNG without IDAT");
  assert.equal(sniffImage(buf([255, 216, 255, 192, 0, 11, 8, 0, 1, 0, 1, 1, 1, 17, 0, 255, 217])), null, "JPEG SOF without a scan");
  assert.equal(sniffImage(buf([...Buffer.from("GIF89a"), 1, 0, 1, 0, 0, 0, 0, 0x3b])), null, "GIF without an image block");
  assert.equal(sniffImage(buf([...Buffer.from("RIFF"), ...le32(12), ...Buffer.from("WEBPVP8 "), ...le32(0)])), null, "WebP with an empty bitstream");
  assert.equal(sniffImage(buf([...be32(16), ...Buffer.from("ftypheic"), 0, 0, 0, 0, ...be32(12), ...Buffer.from("meta"), 0, 0, 0, 0])), null, "HEIC with an empty meta and no data");
  assert.equal(sniffImage(heic({ mdatBytes: 0 })), null, "HEIC without mdat");
  assert.equal(sniffImage(heic({ handler: "vide" })), null, "HEIC whose handler is not pict");
});

test("truncated, oversized, inconsistent or illegal structures are refused", () => {
  assert.equal(sniffImage(buf([0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0])), null);
  assert.equal(sniffImage(png(1, 1, { iend: false })), null, "no IEND");
  assert.equal(sniffImage(png(1, 1, { badCRC: true })), null, "wrong CRC");
  assert.equal(sniffImage(png(IMAGE_MAX_EDGE + 1, 1)), null);
  assert.equal(sniffImage(png(1, 1, { depth: 1, colour: 6 })), null, "1-bit RGBA is not a legal PNG");
  assert.equal(sniffImage(png(1, 1, { depth: 7, colour: 0 })), null);
  assert.equal(sniffImage(buf([0xff, 0xd8, 0xff, 0xe0])), null, "four bytes are not a JPEG");
  assert.equal(sniffImage(jpeg({ eoi: false })), null, "no EOI");
  assert.equal(sniffImage(jpeg({ scan: false })), null, "frame header but no scan");
  // T.81 header grammar: a scan header needs its fields, a frame header needs its components.
  const dqt = [0xff, 0xdb, 0x00, 0x43, 0x00, ...new Array(64).fill(1)];
  const dht = (cls) => [0xff, 0xc4, 0x00, 0x14, cls << 4, 1, ...new Array(15).fill(0), 0x00];
  const wrap = (frame, scan) => buf([0xff, 0xd8, ...dqt, ...frame, ...dht(0), ...dht(1), ...scan, 0x3f, 0xff, 0xd9]);
  const sof0 = [0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00];
  const sos = [0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00];
  assert.equal(sniffImage(wrap(sof0, sos)), "image/jpeg");
  assert.equal(sniffImage(wrap(sof0, [0xff, 0xda, 0x00, 0x02])), null, "SOS without header fields");
  assert.equal(sniffImage(wrap([0xff, 0xc0, 0x00, 0x08, 0x08, 0x00, 0x01, 0x00, 0x01, 0x00], sos)), null, "SOF with zero components");
  assert.equal(sniffImage(wrap(sof0, [0xff, 0xda, 0x00, 0x08, 0x01, 0x02, 0x00, 0x00, 0x3f, 0x00])), null, "scan selects an undeclared component");
  assert.equal(sniffImage(wrap(sof0, [0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x01, 0x3f, 0x00])), null, "baseline scan must cover the full spectrum");
  assert.equal(sniffImage(wrap([0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00], sos)), null, "sampling factor 0");
  assert.equal(sniffImage(wrap([0xff, 0xc0, 0x00, 0x0e, 0x08, 0x00, 0x01, 0x00, 0x01, 0x02, 0x01, 0x11, 0x00, 0x01, 0x11, 0x00], sos)), null, "duplicate component id");
  assert.equal(sniffImage(buf(gifBytes.slice(0, -1))), null, "no trailer");
  assert.equal(sniffImage(buf([...Buffer.from("GIF89a"), 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0x3b])), null);
  assert.equal(sniffImage(webp({ riffSize: 99 })), null, "RIFF size must match the file");
  assert.equal(sniffImage(webp({ payload: [0x2e, 0, 0, 0, 0, 1, 2, 3] })), null, "VP8L without its signature byte");
  assert.equal(sniffImage(heic({ metaFits: false })), null, "meta box must fit the file");
  assert.equal(sniffImage(buf([...be32(24), ...Buffer.from("ftypheic"), 0, 0, 0, 0, ...Buffer.from("mif1heic")])), null, "ftyp alone");
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

test("Turnstile: success alone is not enough — the token must have been solved on an allowed host (SEC09)", () => {
  assert.equal(turnstileVerdict({ success: true, hostname: "keep.it.com" }), true);
  assert.equal(turnstileVerdict({ success: true, hostname: "KEEP.IT.COM" }), true, "case-insensitive");
  assert.equal(turnstileVerdict({ success: true, hostname: "evil.example" }), false, "another site using the same site key");
  assert.equal(turnstileVerdict({ success: true }), false, "a missing hostname is refused");
  assert.equal(turnstileVerdict({ success: false, hostname: "keep.it.com" }), false);
  assert.equal(turnstileVerdict(undefined), false);
  assert.equal(turnstileVerdict({ success: true, hostname: "staging.keep.it.com" }, ["staging.keep.it.com"]), true);
});

test("Turnstile hostnames come from TURNSTILE_HOSTNAMES, default the production host", () => {
  assert.deepEqual(allowedTurnstileHostnames({}), DEFAULT_TURNSTILE_HOSTNAMES);
  assert.deepEqual(allowedTurnstileHostnames({ TURNSTILE_HOSTNAMES: "" }), DEFAULT_TURNSTILE_HOSTNAMES);
  assert.deepEqual(allowedTurnstileHostnames({ TURNSTILE_HOSTNAMES: "Keep.it.com, staging.keep.it.com ," }), ["keep.it.com", "staging.keep.it.com"]);
});

test("the confirmation to the (unverified) sender carries nothing the submitter wrote (SEC09)", () => {
  const m = confirmationEmail("support@keep.it.com", "a@example.test", "support@keep.it.com");
  assert.deepEqual(m.to, ["a@example.test"]);
  assert.equal(m.reply_to, "support@keep.it.com");
  assert.doesNotMatch(m.text, /\$\{|Hi /, "no name, no message");
  assert.match(m.text, /did not write to us/);
  const fixed = confirmationEmail("f", "t", "r").text;
  assert.equal(fixed, confirmationEmail("f", "u", "r").text, "the same text for every recipient");
});
