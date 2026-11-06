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

/**
 * What the file actually is, from its structure — the client's MIME type is just a claim, and so is a
 * signature alone: `89 50 4E 47 00 00 00 00` is not a PNG. Each format is checked to the point where
 * its first header (dimensions) can be read and bounded. Returns the MIME type or null.
 */
export function sniffImage(buf) {
  const b = new Uint8Array(buf);
  const ascii = (from, len) => String.fromCharCode(...b.subarray(from, from + len));
  const be32 = (i) => ((b[i] << 24) >>> 0) + (b[i + 1] << 16) + (b[i + 2] << 8) + b[i + 3];
  const le16 = (i) => b[i] + (b[i + 1] << 8);
  const edgeOK = (w, h) => w > 0 && h > 0 && w <= IMAGE_MAX_EDGE && h <= IMAGE_MAX_EDGE;

  // PNG: 8-byte signature, then the IHDR chunk (length 13, type "IHDR", width, height, bit depth, colour type).
  if (b.length >= 33 && ascii(0, 8) === "\x89PNG\r\n\x1a\n" && be32(8) === 13 && ascii(12, 4) === "IHDR") {
    const w = be32(16), h = be32(20), depth = b[24], colour = b[25];
    if (edgeOK(w, h) && [1, 2, 4, 8, 16].includes(depth) && [0, 2, 3, 4, 6].includes(colour)) return "image/png";
    return null;
  }
  // JPEG: SOI, then a marker segment; the first marker must be a valid one (APPn, DQT, SOF, …).
  if (b.length >= 4 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff && b[3] >= 0xc0 && b[3] !== 0xff) return "image/jpeg";
  // GIF: header, then the logical screen descriptor (width, height little-endian).
  if (b.length >= 10 && (ascii(0, 6) === "GIF87a" || ascii(0, 6) === "GIF89a")) {
    return edgeOK(le16(6), le16(8)) ? "image/gif" : null;
  }
  // WebP: RIFF container whose size field matches the file, then a VP8/VP8L/VP8X chunk.
  if (b.length >= 16 && ascii(0, 4) === "RIFF" && ascii(8, 4) === "WEBP") {
    const riffSize = b[4] + (b[5] << 8) + (b[6] << 16) + ((b[7] << 24) >>> 0);
    if (riffSize + 8 !== b.length) return null;
    return ["VP8 ", "VP8L", "VP8X"].includes(ascii(12, 4)) ? "image/webp" : null;
  }
  // HEIC: ISO BMFF "ftyp" box with a HEIF brand; the box length must fit the file.
  if (b.length >= 16 && ascii(4, 4) === "ftyp") {
    const boxLen = be32(0);
    if (boxLen < 16 || boxLen > b.length || boxLen % 4 !== 0) return null;
    return ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].includes(ascii(8, 4)) ? "image/heic" : null;
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
