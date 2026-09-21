import { readFile } from "node:fs/promises";

function parseEnv(source) {
  return Object.fromEntries(source.split(/\r?\n/u).flatMap((line) => {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/u);
    return match ? [[match[1], match[2].replace(/^(['"])(.*)\1$/u, "$2")]] : [];
  }));
}

const env = parseEnv(await readFile(".env.local", "utf8"));
const token = env.SUPABASE_ACCESS_TOKEN;
let projectRef = env.SUPABASE_PROJECT_REF;
if (!projectRef) {
  try { projectRef = new URL(env.NEXT_PUBLIC_SUPABASE_URL ?? "").hostname.split(".")[0]; } catch { projectRef = undefined; }
}
if (!token || !/^[a-z0-9]{20}$/u.test(projectRef ?? "")) throw new Error("SUPABASE_AUDIT_CONFIG_REQUIRED");

const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/config/auth`, {
  headers: { authorization: `Bearer ${token}` },
  redirect: "error",
});
if (!response.ok) throw new Error(`SUPABASE_AUTH_CONFIG_READ_FAILED_${response.status}`);
const config = await response.json();
const redirectUrls = String(config.uri_allow_list ?? "").split(",").map((value) => value.trim()).filter(Boolean);
const origin = (value) => { try { return new URL(value).origin; } catch { return "INVALID"; } };

console.log(JSON.stringify({
  signupEnabled: config.disable_signup === false,
  emailAutoconfirm: config.mailer_autoconfirm === true,
  refreshTokenRotationEnabled: config.refresh_token_rotation_enabled === true,
  captchaEnabled: config.security_captcha_enabled === true,
  passwordMinLength: Number.isSafeInteger(config.password_min_length) ? config.password_min_length : null,
  otpExpirySeconds: Number.isSafeInteger(config.mailer_otp_exp) ? config.mailer_otp_exp : null,
  otpLength: Number.isSafeInteger(config.mailer_otp_length) ? config.mailer_otp_length : null,
  smtpConfigured: Boolean(config.smtp_host && config.smtp_user && config.smtp_pass),
  siteOrigin: origin(config.site_url),
  redirectOrigins: [...new Set(redirectUrls.map(origin))].sort(),
}, null, 2));
