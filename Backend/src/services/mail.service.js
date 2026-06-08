const nodemailer = require("nodemailer");

function getTransporter() {
    return nodemailer.createTransport({
        service: "gmail",
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS,
        },
    });
}

function buildPasswordResetHtml({ resetLink }) {
    const appName = process.env.APP_NAME || "StuEdu";

    return `
    <div style="margin:0;padding:0;background:#f4f7fb;font-family:Arial,Helvetica,sans-serif;">
      <div style="max-width:620px;margin:0 auto;padding:32px 16px;">
        <div style="background:#ffffff;border-radius:22px;overflow:hidden;border:1px solid #e5e7eb;box-shadow:0 12px 32px rgba(15,23,42,0.08);">

          <div style="background:linear-gradient(135deg,#1B2A8A,#2946D3);padding:28px;text-align:center;">
            <div style="display:inline-block;background:rgba(255,255,255,0.14);border:1px solid rgba(255,255,255,0.24);color:#ffffff;padding:12px 18px;border-radius:16px;font-size:24px;font-weight:800;letter-spacing:0.3px;">
              ${appName}
            </div>
            <div style="color:#dbeafe;font-size:14px;margin-top:10px;font-weight:600;">
              Learning Management System
            </div>
          </div>

          <div style="padding:32px 28px;">
            <h2 style="margin:0 0 12px;color:#0f172a;font-size:24px;text-align:center;">
              Đặt lại mật khẩu
            </h2>

            <p style="color:#475569;font-size:15px;line-height:1.7;margin:0 0 12px;">
              Xin chào,
            </p>

            <p style="color:#475569;font-size:15px;line-height:1.7;margin:0;">
              Bạn vừa yêu cầu đặt lại mật khẩu cho tài khoản StuEdu. Vui lòng bấm vào nút bên dưới để tạo mật khẩu mới.
            </p>

            <div style="text-align:center;margin:30px 0;">
              <a href="${resetLink}" style="background:#1B2A8A;color:#ffffff;text-decoration:none;padding:15px 26px;border-radius:14px;font-weight:800;font-size:15px;display:inline-block;">
                Đặt lại mật khẩu
              </a>
            </div>

            <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:16px;padding:16px;margin-top:18px;">
              <p style="margin:0 0 8px;color:#64748b;font-size:13px;line-height:1.6;">
                Nếu nút không hoạt động, hãy sao chép liên kết sau và mở trên trình duyệt:
              </p>
              <p style="margin:0;color:#2563eb;font-size:13px;word-break:break-all;line-height:1.5;">
                ${resetLink}
              </p>
            </div>

            <p style="color:#64748b;font-size:13px;line-height:1.6;margin:22px 0 0;">
              Nếu bạn không yêu cầu đặt lại mật khẩu, bạn có thể bỏ qua email này.
            </p>
          </div>

          <div style="padding:18px 28px;background:#f8fafc;border-top:1px solid #e5e7eb;text-align:center;">
            <p style="margin:0;color:#94a3b8;font-size:12px;line-height:1.6;">
              © 2026 StuEdu Learning Systems. All rights reserved.
            </p>
          </div>
        </div>
      </div>
    </div>
    `;
}

async function sendPasswordResetEmail({ to, resetLink }) {
    const appName = process.env.APP_NAME || "StuEdu";
    const transporter = getTransporter();

    await transporter.sendMail({
        from: `"${appName}" <${process.env.SMTP_USER}>`,
        to,
        subject: "Đặt lại mật khẩu StuEdu",
        html: buildPasswordResetHtml({ resetLink }),
    });
}

module.exports = {
    sendPasswordResetEmail,
};