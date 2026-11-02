// Cloudflare Pages Function: POST /api/feedback
// Takes the support form (multipart/form-data), checks the Turnstile token, and e-mails the
// message with its attachments through Resend. Nothing is stored anywhere.
//
// Environment (Pages → Settings → Variables and Secrets):
//   TURNSTILE_SECRET  Turnstile secret key
//   RESEND_API_KEY    Resend API key
//   FEEDBACK_TO       recipient, e.g. admin@keep.it.com
//   FEEDBACK_FROM     verified sender, e.g. Keepit Support <feedback@keep.it.com>

export const LIMITS = {
  nameMax: 100,
  emailMax: 254,
  messageMin: 70,
  messageMax: 5000,
  files: 5,
  fileBytes: 1024 * 1024,
  bodyBytes: 6 * 1024 * 1024,      // 5 screenshots + text + multipart overhead; checked before the body is read
  types: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/heic"],
};

export const TYPES = { app: "App issue", translation: "Translation issue", other: "Other" };

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
  if (!(type in TYPES)) return { ok: false, error: "Please choose what the message is about." };
  if (message.length < LIMITS.messageMin) return { ok: false, error: `Please describe it in at least ${LIMITS.messageMin} characters.` };
  if (message.length > LIMITS.messageMax) return { ok: false, error: `The message is too long (${LIMITS.messageMax} characters at most).` };
  if (files.length > LIMITS.files) return { ok: false, error: `At most ${LIMITS.files} screenshots.` };
  for (const f of files) {
    if (f.size > LIMITS.fileBytes) return { ok: false, error: `“${f.name}” is larger than 1 MB.` };
    if (!LIMITS.types.includes(f.type)) return { ok: false, error: `“${f.name}” is not an image (PNG, JPEG, GIF, WebP or HEIC).` };
  }
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

const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

export async function onRequestPost({ request, env }) {
  const declared = Number(request.headers.get("content-length") || 0);
  if (declared > LIMITS.bodyBytes) return json(413, { error: "The attachments are too large (5 screenshots of 1 MB at most)." });
  const ctype = request.headers.get("content-type") || "";
  if (!ctype.startsWith("multipart/form-data")) return json(400, { error: "Could not read the form." });
  let form;
  try {
    form = await request.formData();
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
    attachments.push({ filename: f.name.replace(/[^\w.\-]+/g, "_").slice(0, 80) || "screenshot", content: b64(await f.arrayBuffer()) });
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
      text: `Hi ${name},\n\nThank you — your message has reached Keepit support. We usually reply within a day or two.\n\nYour message:\n\n${message}\n\n— Keepit, keep.it.com`,
    }),
  }).catch(() => {});
  return json(200, { ok: true });
}
