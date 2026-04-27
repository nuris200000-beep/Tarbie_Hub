// Отправка кода сброса пароля на email (Resend).
// Секреты в Dashboard: Project Settings → Edge Functions → Secrets:
//   RESEND_API_KEY — API key с https://resend.com
// Опционально: MAIL_FROM — например "Tarbie <noreply@ваш-домен.com>"
//
// Деплой: supabase functions deploy send-reset-code
// Клиент вызывает с JWT anon из приложения (verify_jwt по умолчанию включён).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const MAIL_FROM = Deno.env.get("MAIL_FROM") ?? "Tarbie Hub <onboarding@resend.dev>";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  let body: { email?: string; code?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const email = body.email?.trim().toLowerCase();
  const code = body.code?.trim();
  if (!email || !code) {
    return new Response(JSON.stringify({ error: "email and code required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (!RESEND_API_KEY) {
    return new Response(JSON.stringify({ error: "RESEND_API_KEY not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: MAIL_FROM,
      to: [email],
      subject: "Код сброса пароля Tarbie Hub",
      html:
        `<p>Код для сброса пароля (действует 15 минут):</p>` +
        `<p><strong style="font-size:24px;letter-spacing:4px">${code}</strong></p>` +
        `<p>Если вы не запрашивали сброс, проигнорируйте письмо.</p>`,
    }),
  });

  if (!res.ok) {
    const t = await res.text();
    return new Response(JSON.stringify({ error: t }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }
  return new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
