// Cloudflare Worker: AI proxy for "Not Programming"
// 1) Create a Worker at dash.cloudflare.com  2) Paste this file
// 3) Settings > Variables > add secret ANTHROPIC_API_KEY
// 4) Put the Worker URL in the platform: Teacher > Settings > AI server URL
// Tip: replace '*' below with your site's domain to block other sites.
export default {
  async fetch(req, env) {
    const cors = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'content-type',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
    };
    if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
    const b = await req.json();
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 1000,
        system: String(b.system || '').slice(0, 4000),
        messages: (b.messages || []).slice(-12),
      }),
    });
    return new Response(await r.text(), {
      status: r.status,
      headers: { ...cors, 'content-type': 'application/json' },
    });
  },
};
