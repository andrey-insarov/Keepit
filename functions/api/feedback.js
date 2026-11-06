// Cloudflare Pages Function: POST /api/feedback
// Takes the support form (multipart/form-data), checks the Turnstile token, and e-mails the
// message with its attachments through Resend. Nothing is stored anywhere.
//
// Environment (Pages → Settings → Variables and Secrets):
//   TURNSTILE_SECRET  Turnstile secret key
//   RESEND_API_KEY    Resend API key
//   FEEDBACK_TO       recipient, e.g. admin@keep.it.com
//   FEEDBACK_FROM     verified sender, e.g. Keepit Support <support@keep.it.com>

export const LIMITS = {
  nameMax: 100,
  emailMax: 254,
  messageMin: 70,
  messageMax: 5000,
  files: 5,
  fileBytes: 1024 * 1024,
  bodyBytes: 6 * 1024 * 1024,      // 5 screenshots + text + multipart overhead; checked against Content-Length
                                   // before the body is read AND against the parsed parts afterwards
  types: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/heic"],
};

/** Largest edge a screenshot may claim in its header — a 1 MB file cannot be a 30 000-pixel image. */
export const IMAGE_MAX_EDGE = 16384;
/** Boxes, chunks or segments walked before a file is refused as too complex for an attachment. */
const MAX_UNITS = 256;

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let i = 0; i < 256; i++) { let c = i; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[i] = c >>> 0; }
  return t;
})();
const crc32 = (b, from, to) => { let c = 0xffffffff; for (let i = from; i < to; i++) c = CRC_TABLE[(c ^ b[i]) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };

/**
 * What the file actually is, from a bounded walk of its structure down to the image data — the
 * client's MIME type is just a claim, a signature alone is not an image, and neither is a header
 * with the right footer glued on. Each format is checked to a documented subset: the required
 * boxes/chunks/segments in order, lengths that fit the file, sane dimensions, and at least one unit
 * that carries pixel data. Anything else — including valid but exotic files — returns null, and the
 * form says so. Returns the MIME type or null.
 */
export function sniffImage(buf) {
  const b = new Uint8Array(buf);
  const n = b.length;
  const ascii = (from, len) => String.fromCharCode(...b.subarray(from, from + len));
  const be32 = (i) => ((b[i] << 24) >>> 0) + (b[i + 1] << 16) + (b[i + 2] << 8) + b[i + 3];
  const be16 = (i) => (b[i] << 8) + b[i + 1];
  const le16 = (i) => b[i] + (b[i + 1] << 8);
  const le32 = (i) => b[i] + (b[i + 1] << 8) + (b[i + 2] << 16) + ((b[i + 3] << 24) >>> 0);
  const edgeOK = (w, h) => w > 0 && h > 0 && w <= IMAGE_MAX_EDGE && h <= IMAGE_MAX_EDGE;

  // PNG (W3C): signature; chunks each [len][type][data][crc] with the CRC over type+data; IHDR first,
  // one or more non-empty IDAT, IEND last and nothing after it; legal depth/colour combinations.
  if (n >= 8 && ascii(0, 8) === "\x89PNG\r\n\x1a\n") {
    let i = 8, units = 0, sawIHDR = false, idatBytes = 0, sawIEND = false;
    while (i + 12 <= n && units++ < MAX_UNITS) {
      const len = be32(i), type = ascii(i + 4, 4);
      if (len > 0x7fffffff || i + 12 + len > n) return null;
      if (crc32(b, i + 4, i + 8 + len) !== be32(i + 8 + len)) return null;
      if (units === 1) {
        if (type !== "IHDR" || len !== 13) return null;
        const w = be32(i + 8), h = be32(i + 12), depth = b[i + 16], colour = b[i + 17];
        const legal = { 0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8], 4: [8, 16], 6: [8, 16] }[colour];
        if (!edgeOK(w, h) || !legal || !legal.includes(depth) || b[i + 18] !== 0 || b[i + 19] !== 0 || b[i + 20] > 1) return null;
        sawIHDR = true;
      } else if (type === "IHDR") return null;
      else if (type === "IDAT") idatBytes += len;
      else if (type === "IEND") { if (len !== 0) return null; sawIEND = true; i += 12; break; }
      i += 12 + len;
    }
    return sawIHDR && idatBytes > 0 && sawIEND && i === n ? "image/png" : null;
  }

  // JPEG (ITU T.81 B.2.2 / B.2.3): SOI; marker segments whose lengths fit; a frame header (SOF0/1/2)
  // whose length matches its component count, with sane dimensions and legal component fields;
  // then a scan header whose length matches its component count, whose selectors name declared
  // components without repeats and whose spectral/approximation fields fit the process; scan data
  // present; EOI as the last two bytes. Lossless, hierarchical and arithmetic processes are not accepted.
  if (n >= 4 && b[0] === 0xff && b[1] === 0xd8) {
    if (!(b[n - 2] === 0xff && b[n - 1] === 0xd9)) return null;
    let i = 2, units = 0, frame = null;
    while (i + 4 <= n - 2 && units++ < MAX_UNITS) {
      if (b[i] !== 0xff) return null;
      const marker = b[i + 1];
      if (marker === 0xff) { i++; continue; }                        // fill byte
      if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) { i += 2; continue; }   // no length
      if (marker === 0xd8 || marker === 0xd9) return null;           // SOI again / early EOI
      const len = be16(i + 2);
      if (len < 2 || i + 2 + len > n - 2) return null;
      const p = i + 4;                                                // first payload byte
      if (marker === 0xc0 || marker === 0xc1 || marker === 0xc2) {
        if (frame) return null;                                       // one frame
        if (len < 8) return null;
        const precision = b[p], h = be16(p + 1), w = be16(p + 3), nf = b[p + 5];
        if (!(precision === 8 || (marker !== 0xc0 && precision === 12))) return null;   // T.81: baseline 8-bit; extended/progressive 8 or 12
        if (!edgeOK(w, h) || nf < 1 || nf > 4 || len !== 8 + 3 * nf) return null;
        const ids = new Set();
        for (let c = 0; c < nf; c++) {
          const id = b[p + 6 + 3 * c], hv = b[p + 7 + 3 * c], tq = b[p + 8 + 3 * c];
          const hs = hv >> 4, vs = hv & 15;
          if (ids.has(id) || hs < 1 || hs > 4 || vs < 1 || vs > 4 || tq > 3) return null;
          ids.add(id);
        }
        frame = { marker, ids };
      } else if (marker >= 0xc3 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
        return null;                                                  // lossless / hierarchical / arithmetic: not supported
      } else if (marker === 0xda) {
        if (!frame) return null;                                      // scan before any frame header
        const ns = b[p];
        if (ns < 1 || ns > 4 || len !== 6 + 2 * ns) return null;
        const seen = new Set();
        for (let c = 0; c < ns; c++) {
          const id = b[p + 1 + 2 * c], tdta = b[p + 2 + 2 * c];
          if (!frame.ids.has(id) || seen.has(id) || (tdta >> 4) > 3 || (tdta & 15) > 3) return null;
          seen.add(id);
        }
        const ss = b[p + 1 + 2 * ns], se = b[p + 2 + 2 * ns], ah = b[p + 3 + 2 * ns] >> 4, al = b[p + 3 + 2 * ns] & 15;
        if (frame.marker === 0xc2) {                                  // progressive: spectral selection / successive approximation
          if (ss > 63 || se > 63 || se < ss || (ss === 0 && se !== 0) || ah > 13 || al > 13) return null;
        } else if (ss !== 0 || se !== 63 || ah !== 0 || al !== 0) return null;   // baseline / extended: full spectrum, no approximation
        const scanStart = i + 2 + len;
        return scanStart < n - 2 ? "image/jpeg" : null;               // entropy-coded data must exist
      }
      i += 2 + len;
    }
    return null;
  }

  // GIF (89a/87a): header; logical screen descriptor; optional global colour table; blocks — extensions
  // (sub-blocks that fit), image descriptors inside the screen with a non-empty LZW data stream —
  // at least one image; the trailer as the last byte.
  if (n >= 14 && (ascii(0, 6) === "GIF87a" || ascii(0, 6) === "GIF89a")) {
    const sw = le16(6), sh = le16(8);
    if (!edgeOK(sw, sh) || b[n - 1] !== 0x3b) return null;
    let i = 13;
    if (b[10] & 0x80) i += 3 << ((b[10] & 7) + 1);                 // global colour table
    const subBlocks = () => { while (i < n) { const l = b[i++]; if (l === 0) return true; i += l; } return false; };
    let images = 0, units = 0;
    while (i < n - 1 && units++ < MAX_UNITS) {
      const sep = b[i++];
      if (sep === 0x21) { if (i >= n) return null; i++; if (!subBlocks()) return null; }           // extension
      else if (sep === 0x2c) {                                                                    // image descriptor
        if (i + 9 > n) return null;
        const x = le16(i), y = le16(i + 2), w = le16(i + 4), h = le16(i + 6), flags = b[i + 8];
        if (!edgeOK(w, h) || x + w > sw || y + h > sh) return null;
        i += 9;
        if (flags & 0x80) i += 3 << ((flags & 7) + 1);                                            // local colour table
        if (i >= n) return null;
        const minCode = b[i++];
        if (minCode < 2 || minCode > 11) return null;
        if (i >= n || b[i] === 0) return null;                                                    // empty data stream
        if (!subBlocks()) return null;
        images++;
      } else return null;
    }
    return images > 0 && i === n - 1 ? "image/gif" : null;
  }

  // WebP (RIFF container): RIFF size = file - 8; chunks [fourcc][size][data][pad]; the first is
  // VP8 (key-frame start code, 14-bit dimensions), VP8L (signature byte, 14-bit dimensions) or VP8X
  // (canvas dimensions, followed somewhere by a VP8/VP8L chunk); bitstream chunks are non-empty.
  if (n >= 20 && ascii(0, 4) === "RIFF" && ascii(8, 4) === "WEBP") {
    if (le32(4) + 8 !== n) return null;
    let i = 12, units = 0, sawCanvas = false, sawBitstream = false;
    while (i + 8 <= n && units++ < MAX_UNITS) {
      const fourcc = ascii(i, 4), size = le32(i + 4), d = i + 8;
      if (d + size > n) return null;
      if (fourcc === "VP8 ") {
        if (size < 10 || b[d + 3] !== 0x9d || b[d + 4] !== 0x01 || b[d + 5] !== 0x2a || (b[d] & 1) !== 0) return null;  // key frame
        if (!edgeOK(le16(d + 6) & 0x3fff, le16(d + 8) & 0x3fff)) return null;
        sawBitstream = true;
      } else if (fourcc === "VP8L") {
        if (size < 5 || b[d] !== 0x2f) return null;
        const bits = le32(d + 1);
        if (!edgeOK((bits & 0x3fff) + 1, ((bits >>> 14) & 0x3fff) + 1)) return null;
        sawBitstream = true;
      } else if (fourcc === "VP8X") {
        if (units !== 1 || size < 10) return null;
        const w = (b[d + 4] | (b[d + 5] << 8) | (b[d + 6] << 16)) + 1, h = (b[d + 7] | (b[d + 8] << 8) | (b[d + 9] << 16)) + 1;
        if (!edgeOK(w, h)) return null;
        sawCanvas = true;
      } else if (units === 1) return null;                            // first chunk must be a bitstream or VP8X
      i = d + size + (size & 1);
    }
    return sawBitstream && i === n ? "image/webp" : null;
  }

  // HEIC (ISO BMFF / HEIF): top-level boxes that fit; ftyp with a HEIF brand first; a meta box whose
  // hdlr says "pict"; a non-empty mdat or idat box carrying the image data.
  if (n >= 24 && ascii(4, 4) === "ftyp") {
    let i = 0, units = 0, sawFtyp = false, sawPict = false, dataBytes = 0;
    while (i + 8 <= n && units++ < MAX_UNITS) {
      let size = be32(i);
      const type = ascii(i + 4, 4);
      if (size === 0) size = n - i;                                   // "to end of file"
      if (size === 1) return null;                                    // 64-bit sizes: not an attachment
      if (size < 8 || i + size > n) return null;
      if (units === 1) {
        if (type !== "ftyp" || size < 16 || !["heic", "heix", "hevc", "hevx", "mif1", "msf1"].includes(ascii(i + 8, 4))) return null;
        sawFtyp = true;
      } else if (type === "meta") {
        // FullBox: 4 bytes version/flags, then child boxes; the handler box names the content type.
        let j = i + 12;
        while (j + 8 <= i + size && units++ < MAX_UNITS) {                 // one budget for the whole file
          const cs = be32(j), ct = ascii(j + 4, 4);
          if (cs < 8 || j + cs > i + size) return null;
          if (ct === "hdlr" && cs >= 24 && ascii(j + 16, 4) === "pict") sawPict = true;
          j += cs;
        }
      } else if (type === "mdat" || type === "idat") dataBytes += size - 8;
      i += size;
    }
    return sawFtyp && sawPict && dataBytes > 0 && i === n ? "image/heic" : null;
  }
  return null;
}

export const TYPES = Object.freeze(Object.assign(Object.create(null), { app: "App issue", translation: "Translation issue", other: "Other" }));

const json = (status, body) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8" } });

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** Validate the submitted fields. Returns { ok, error } or { ok, data }. */
export function validate(form) {
  const name = (form.get("name") || "").toString().trim();
  const email = (form.get("email") || "").toString().trim();
  const type = (form.get("type") || "").toString();
  const message = (form.get("message") || "").toString().trim();
  const files = form.getAll("files").filter((f) => f && typeof f === "object" && f.size > 0);

  if (!name || name.length > LIMITS.nameMax) return { ok: false, error: "Please enter your name." };
  if (!EMAIL.test(email) || email.length > LIMITS.emailMax) return { ok: false, error: "Please enter a valid e-mail address." };
  if (!Object.hasOwn(TYPES, type)) return { ok: false, error: "Please choose what the message is about." };   // not `in`: "constructor" is in every object
  if (message.length < LIMITS.messageMin) return { ok: false, error: `Please describe it in at least ${LIMITS.messageMin} characters.` };
  if (message.length > LIMITS.messageMax) return { ok: false, error: `The message is too long (${LIMITS.messageMax} characters at most).` };
  if (files.length > LIMITS.files) return { ok: false, error: `At most ${LIMITS.files} screenshots.` };
  for (const f of files) {
    if (f.size > LIMITS.fileBytes) return { ok: false, error: `“${f.name}” is larger than 1 MB.` };
    if (!LIMITS.types.includes(f.type)) return { ok: false, error: `“${f.name}” is not an image (PNG, JPEG, GIF, WebP or HEIC).` };
  }
  // Actual size of what was parsed, whatever Content-Length said (or did not say).
  let total = files.reduce((n, f) => n + f.size, 0);
  for (const [k, v] of form.entries()) if (typeof v === "string") total += k.length + v.length;
  if (total > LIMITS.bodyBytes) return { ok: false, error: "The attachments are too large (5 screenshots of 1 MB at most)." };
  return { ok: true, data: { name, email, type, message, files } };
}

async function turnstileOK(token, secret, ip) {
  if (!token) return false;
  const body = new FormData();
  body.append("secret", secret);
  body.append("response", token);
  if (ip) body.append("remoteip", ip);
  const r = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", { method: "POST", body });
  const j = await r.json().catch(() => ({}));
  return j.success === true;
}

function b64(buf) {
  let s = "";
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

/** Collect the request body, or return null as soon as it exceeds `max` bytes (the stream is cancelled). */
export async function readBodyUpTo(request, max) {
  if (!request.body) return new Uint8Array(0);
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) { await reader.cancel().catch(() => {}); return null; }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) { out.set(c, off); off += c.byteLength; }
  return out;
}

const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

export async function onRequestPost({ request, env }) {
  // Browsers always send Content-Length for a multipart form; a request without one (or with a
  // nonsense value) is not the support form, and parsing it would mean reading an unbounded body.
  const declared = Number(request.headers.get("content-length"));
  if (!Number.isFinite(declared) || declared <= 0) return json(411, { error: "Could not read the form." });
  if (declared > LIMITS.bodyBytes) return json(413, { error: "The attachments are too large (5 screenshots of 1 MB at most)." });
  const ctype = request.headers.get("content-type") || "";
  if (!ctype.startsWith("multipart/form-data")) return json(400, { error: "Could not read the form." });
  // Read the body ourselves with a running total and stop at the limit — formData() would buffer
  // the whole stream first, so a lying Content-Length would still cost the memory.
  const body = await readBodyUpTo(request, LIMITS.bodyBytes);
  if (body === null) return json(413, { error: "The attachments are too large (5 screenshots of 1 MB at most)." });
  let form;
  try {
    form = await new Response(body, { headers: { "content-type": ctype } }).formData();
  } catch {
    return json(400, { error: "Could not read the form." });
  }

  const v = validate(form);
  if (!v.ok) return json(400, { error: v.error });
  const { name, email, type, message, files } = v.data;

  const ip = request.headers.get("cf-connecting-ip") || "";
  if (!(await turnstileOK(form.get("cf-turnstile-response"), env.TURNSTILE_SECRET, ip))) {
    return json(400, { error: "The anti-spam check did not pass. Please try again." });
  }

  const attachments = [];
  for (const f of files) {
    const buf = await f.arrayBuffer();
    if (sniffImage(buf) === null) return json(400, { error: `“${f.name}” is not an image (PNG, JPEG, GIF, WebP or HEIC).` });
    attachments.push({ filename: f.name.replace(/[^\w.\-]+/g, "_").slice(0, 80) || "screenshot", content: b64(buf) });
  }

  const subject = `[Keepit] ${TYPES[type]} — ${name}`;
  const text = `${TYPES[type]}\nFrom: ${name} <${email}>\n\n${message}\n`;
  const html = `<p><b>${esc(TYPES[type])}</b><br>From: ${esc(name)} &lt;${esc(email)}&gt;</p><pre style="white-space:pre-wrap;font:14px/1.5 -apple-system,sans-serif">${esc(message)}</pre>`;

  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({ from: env.FEEDBACK_FROM, to: [env.FEEDBACK_TO], reply_to: email, subject, text, html, attachments }),
  });
  if (!r.ok) return json(502, { error: "The message could not be sent right now. Please e-mail us instead." });

  // Confirmation to the sender. Best effort: the message itself is already delivered.
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({
      from: env.FEEDBACK_FROM, to: [email], reply_to: env.FEEDBACK_TO,
      subject: "We received your message — Keepit",
      text: `Hi ${name},\n\nThank you — your message has reached Keepit support.\n\nYour message:\n\n${message}\n\n— Keepit, keep.it.com`,
    }),
  }).catch(() => {});
  return json(200, { ok: true });
}
