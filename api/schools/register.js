import { createClient } from '@supabase/supabase-js';
import { json, readJson, isEmail } from '../_lib/http.js';
const clean = (value, max) => typeof value === 'string' ? value.trim().replace(/\s+/g, ' ').slice(0, max) : '';
export async function POST(request) {
  try {
    const body = await readJson(request);
    const schoolName = clean(body.schoolName, 120), fullName = clean(body.fullName, 120), email = clean(body.email, 254).toLowerCase(), password = body.password;
    if (schoolName.length < 2 || fullName.length < 2 || !isEmail(email) || typeof password !== 'string' || password.length < 12 || password.length > 128) return json({ error: 'Enter a school name, your full name, a valid email, and a password of at least 12 characters.' }, 400);
    const { SUPABASE_URL: url, SUPABASE_ANON_KEY: anonKey, SUPABASE_SERVICE_ROLE_KEY: serviceKey } = process.env;
    if (!url || !anonKey || !serviceKey) return json({ error: 'School registration is not configured yet. Connect Supabase first.' }, 503);
    const publicClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await publicClient.auth.signUp({ email, password, options: { data: { full_name: fullName }, emailRedirectTo: (process.env.APP_URL || 'https://satgoldcloud.name.ng') + '/' } });
    if (error) return json({ error: error.message }, 400);
    if (!data.user) return json({ error: 'Account could not be created. Please try again.' }, 500);
    if (!data.session) return json({ message: 'Check your email to confirm your account. Then sign in to finish creating the school workspace.' }, 202);
    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { error: rpcError } = await admin.rpc('register_school_for_owner', { p_owner_id: data.user.id, p_school_name: schoolName, p_owner_name: fullName, p_owner_email: email });
    if (rpcError) return json({ error: 'Your account was created, but the school workspace could not be created. Contact support to reconcile registration.' }, 500);
    return json({ message: 'Your school workspace is ready. Check your email for account confirmation.' }, 201);
  } catch (error) {
    const badRequest = error instanceof SyntaxError || error.message === 'Send a JSON request body.';
    return json({ error: badRequest ? 'Enter a valid JSON request.' : 'Unable to register the school right now.' }, badRequest ? 400 : 500);
  }
}
