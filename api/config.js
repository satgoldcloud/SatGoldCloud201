import { json } from './_lib/http.js';
export function GET() { return json({ supabaseUrl: process.env.SUPABASE_URL || '', supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '' }); }
