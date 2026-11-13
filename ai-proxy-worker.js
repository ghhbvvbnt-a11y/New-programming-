// Cloudflare Worker: "Not Programming" — AI proxy + إرسال الدرجة لولي الأمر (/notify)
// Settings > Variables:
//   ANTHROPIC_API_KEY (secret)           — للمساعد الذكي
//   --- إرسال تلقائي (اختر واحد أو الاتنين) ---
//   A) Twilio:  TWILIO_SID, TWILIO_TOKEN (secret), TWILIO_FROM
//        SMS:      TWILIO_FROM = +1xxxxxxxxxx           NOTIFY_CHANNEL = sms
//        WhatsApp: TWILIO_FROM = whatsapp:+14155238886  NOTIFY_CHANNEL = whatsapp
//   B) أي خدمة تانية (Make / n8n / Zapier / Telegram bot / بوابة SMS مصرية):
//        NOTIFY_WEBHOOK = رابط يستقبل POST JSON: {to, message, student, exam, course, score, max}
//   اختياري: COUNTRY_CODE (افتراضي 20) ، MSG_TEMPLATE (قالب الرسالة، المتغيرات {name} {exam} {course} {score} {max})
const SB = 'https://qfjfwhdyurlxiavomdgu.supabase.co';
const ANON = 'sb_publishable_YqeKTLR2mmkRQrEda28H8w_WrNa9nIj';
const J = (o, s, c) => new Response(JSON.stringify(o), { status: s || 200, headers: { ...c, 'content-type': 'application/json' } });

function phone(p, cc) {
  p = String(p || '').replace(/[^\d+]/g, '');
  if (p[0] === '+') return p.slice(1);
  if (p.startsWith('00')) return p.slice(2);
  if (p[0] === '0') return (cc || '20') + p.slice(1);
  return p;
}

async function notify(req, env, cors) {
  const auth = req.headers.get('authorization') || '';
  const { id } = await req.json().catch(() => ({}));
  if (!auth || !id) return J({ ok: false, reason: 'bad_request' }, 400, cors);
  const h = { apikey: ANON, authorization: auth };
  // نقرأ الدرجة من القاعدة بصلاحيات الطالب نفسه → مستحيل يزوّر الدرجة
  const r = (await (await fetch(`${SB}/rest/v1/exam_results?id=eq.${encodeURIComponent(id)}&select=uid,name,examTitle,courseTitle,score,max,ts`, { headers: h })).json())[0];
  if (!r) return J({ ok: false, reason: 'not_found' }, 404, cors);
  if (Date.now() - Number(r.ts) > 15 * 60 * 1000) return J({ ok: false, reason: 'too_old' }, 400, cors);
  const pr = (await (await fetch(`${SB}/rest/v1/profiles?id=eq.${r.uid}&select=parent`, { headers: h })).json())[0];
  const to = phone(pr && pr.parent, env.COUNTRY_CODE);
  if (!to) return J({ ok: false, reason: 'no_parent_phone' }, 200, cors);
  const tpl = env.MSG_TEMPLATE || 'مرحبًا، نتيجة الطالب/ة {name} في امتحان "{exam}" (كورس {course}): {score} من {max}. — Not Programming';
  const v = { name: r.name, exam: r.examTitle, course: r.courseTitle, score: r.score, max: r.max };
  const message = tpl.replace(/\{(\w+)\}/g, (_, k) => v[k]);
  const sent = [];
  if (env.TWILIO_SID && env.TWILIO_TOKEN && env.TWILIO_FROM) {
    const wa = (env.NOTIFY_CHANNEL || '').toLowerCase() === 'whatsapp';
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${env.TWILIO_SID}/Messages.json`, {
      method: 'POST',
      headers: { authorization: 'Basic ' + btoa(env.TWILIO_SID + ':' + env.TWILIO_TOKEN), 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ To: (wa ? 'whatsapp:+' : '+') + to, From: env.TWILIO_FROM, Body: message }),
    });
    sent.push({ twilio: res.status });
  }
  if (env.NOTIFY_WEBHOOK) {
    const res = await fetch(env.NOTIFY_WEBHOOK, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ to, message, student: r.name, exam: r.examTitle, course: r.courseTitle, score: r.score, max: r.max }),
    });
    sent.push({ webhook: res.status });
  }
  return J({ ok: sent.length > 0, sent }, 200, cors);
}

export default {
  async fetch(req, env) {
    const cors = {
      'Access-Control-Allow-Origin': '*', // الأفضل تحط دومين موقعك بدل *
      'Access-Control-Allow-Headers': 'content-type,authorization',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
    };
    if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (new URL(req.url).pathname === '/notify') return notify(req, env, cors);
    const b = await req.json();
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-api-key': env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({ model: 'claude-sonnet-4-6', max_tokens: 1000, system: String(b.system || '').slice(0, 4000), messages: (b.messages || []).slice(-12) }),
    });
    return new Response(await r.text(), { status: r.status, headers: { ...cors, 'content-type': 'application/json' } });
  },
};
