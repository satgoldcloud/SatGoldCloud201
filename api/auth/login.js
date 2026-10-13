import { createClient } from '@supabase/supabase-js';
import { json, readJson, isEmail } from '../_lib/http.js';
export async function POST(request) {
  try {
    const { email, password, pendingSchoolName } = await readJson(request);
    if (!isEmail(email) || typeof password !== 'string' || password.length < 1 || password.length > 256) return json({ error: 'Enter a valid email and password.' }, 400);
    const { SUPABASE_URL: url, SUPABASE_ANON_KEY: key } = process.env;
    if (!url || !key) return json({ error: 'Login is not configured yet. Add the Supabase project URL and anonymous key.' }, 503);
    const supabase = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
    if (error) return json({ error: 'We could not sign you in. Check your credentials or verify your email.' }, 401);
    if (typeof pendingSchoolName === 'string' && pendingSchoolName.trim()) {
      const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
      if (!serviceKey) return json({ error: 'Your account is verified, but school registration is not configured. Contact support.' }, 503);
      const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
      const { error: rpcError } = await admin.rpc('register_school_for_owner', {
        p_owner_id: data.user.id, p_school_name: pendingSchoolName.trim().slice(0, 120),
        p_owner_name: String(data.user.user_metadata?.full_name || data.user.email).slice(0, 120), p_owner_email: data.user.email
      });
      if (rpcError && !String(rpcError.message).toLowerCase().includes('duplicate key')) return json({ error: 'Your sign-in succeeded, but the school workspace could not be created. Contact support to reconcile registration.' }, 500);
    }
    return json({ message: 'Signed in.', accessToken: data.session.access_token, refreshToken: data.session.refresh_token, user: { id: data.user.id, email: data.user.email } });
  } catch (error) {
    const badRequest = error instanceof SyntaxError || error.message === 'Send a JSON request body.';
    return json({ error: badRequest ? 'Enter a valid JSON request.' : 'Unable to sign in right now.' }, badRequest ? 400 : 500);
  }
}
