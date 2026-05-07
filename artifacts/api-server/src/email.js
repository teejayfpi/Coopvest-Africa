const nodemailer = require('nodemailer');

let transporter = null;

function getTransporter() {
  if (transporter) return transporter;

  const host = process.env.SMTP_HOST;
  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (host && user && pass) {
    transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    });
    console.log(`[EMAIL] SMTP configured via ${host}:${port}`);
  } else {
    console.warn('[EMAIL] No SMTP_HOST/SMTP_USER/SMTP_PASS set — OTPs will be logged to console only');
    transporter = null;
  }

  return transporter;
}

async function sendEmail({ to, subject, html }) {
  const t = getTransporter();
  const from = process.env.SMTP_FROM || process.env.SMTP_USER || 'noreply@coopvest.africa';

  if (!t) {
    console.log(`[EMAIL-OTP] To: ${to} | Subject: ${subject}`);
    console.log(`[EMAIL-OTP] (SMTP not configured — OTP delivered via console only)`);
    return;
  }

  try {
    await t.sendMail({ from: `"Coopvest Africa" <${from}>`, to, subject, html });
    console.log(`[EMAIL] Sent "${subject}" to ${to}`);
  } catch (err) {
    console.error(`[EMAIL] Failed to send to ${to}:`, err.message);
  }
}

async function sendOTPEmail({ to, name, otp, type }) {
  const isReset = type === 'password_reset';
  const subject = isReset
    ? 'Coopvest Africa — Password Reset Code'
    : 'Coopvest Africa — Verify Your Email';
  const action = isReset ? 'reset your password' : 'verify your email address';
  const expiry = isReset ? '15 minutes' : '30 minutes';

  const html = `
    <div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;background:#f9f9f9;padding:32px;border-radius:12px;">
      <div style="text-align:center;margin-bottom:24px;">
        <h1 style="color:#1B5E20;font-size:24px;margin:0;">Coopvest Africa</h1>
        <p style="color:#666;font-size:13px;margin:4px 0 0;">Empowering Financial Inclusion</p>
      </div>
      <div style="background:#fff;border-radius:8px;padding:24px;border:1px solid #e5e7eb;">
        <p style="color:#222;font-size:16px;">Hello <strong>${name}</strong>,</p>
        <p style="color:#444;font-size:15px;">Use the code below to ${action}:</p>
        <div style="text-align:center;margin:24px 0;">
          <span style="display:inline-block;background:#1B5E20;color:#fff;font-size:36px;font-weight:bold;letter-spacing:10px;padding:16px 32px;border-radius:8px;">${otp}</span>
        </div>
        <p style="color:#888;font-size:13px;text-align:center;">This code expires in <strong>${expiry}</strong>. Do not share it with anyone.</p>
      </div>
      <p style="color:#aaa;font-size:12px;text-align:center;margin-top:20px;">
        If you did not request this, you can safely ignore this email.
      </p>
    </div>
  `;

  console.log(`[EMAIL] Dispatching OTP ${otp} → ${to}`);
  await sendEmail({ to, subject, html });
}

module.exports = { sendOTPEmail };
