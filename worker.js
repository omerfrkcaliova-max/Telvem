// Cloudflare Worker: uygulama -> Claude API koprusu (API anahtari telefonda durmaz)
// Ayarlar > Variables: ANTHROPIC_API_KEY (secret), APP_KEY (secret)
export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return new Response('ok');
    if (req.headers.get('X-App-Key') !== env.APP_KEY) return new Response('yetkisiz', { status: 401 });
    const { prompt, images = [] } = await req.json();
    if (!prompt || prompt.length > 4000 || images.length > 3) return new Response('gecersiz', { status: 400 });
    const content = images.map(d => ({ type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: d } }));
    content.push({ type: 'text', text: prompt });
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-api-key': env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({ model: 'claude-sonnet-5-5', max_tokens: 1200, messages: [{ role: 'user', content }] }),
    });
    if (!r.ok) return new Response('upstream ' + r.status, { status: 502 });
    const j = await r.json();
    const text = (j.content || []).filter(b => b.type === 'text').map(b => b.text).join('\n');
    return new Response(JSON.stringify({ text }), { headers: { 'content-type': 'application/json' } });
  },
};
