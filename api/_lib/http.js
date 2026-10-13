export function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' } });
}
export async function readJson(request) {
  if (!(request.headers.get('content-type') || '').includes('application/json')) throw new Error('Send a JSON request body.');
  const raw = await request.text();
  if (raw.length > 20_000) throw new Error('Request is too large.');
  return JSON.parse(raw);
}
export function isEmail(value) { return typeof value === 'string' && value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value); }
