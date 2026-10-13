import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3';
document.querySelector('#year').textContent = new Date().getFullYear();
const token = sessionStorage.getItem('satgold_access_token'), refresh = sessionStorage.getItem('satgold_refresh_token');
const user = JSON.parse(sessionStorage.getItem('satgold_user') || 'null'), status = document.querySelector('#portal-status');
if (!token || !refresh || !user) location.replace('/#portal');
const welcome = document.querySelector('#welcome');
welcome.textContent = '';
welcome.append('Welcome back,');
const br = document.createElement('br'), em = document.createElement('em'); em.textContent = user?.email || 'school member'; welcome.append(br, em);
document.querySelector('#signout').addEventListener('click', () => { sessionStorage.removeItem('satgold_access_token'); sessionStorage.removeItem('satgold_refresh_token'); sessionStorage.removeItem('satgold_user'); location.href = '/'; });
const config = await fetch('/api/config').then((r) => r.json()).catch(() => ({}));
if (config.supabaseUrl && config.supabaseAnonKey) {
  const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { error: sessionError } = await supabase.auth.setSession({ access_token: token, refresh_token: refresh });
  if (sessionError) { status.textContent = 'Your session expired. Please sign in again.'; }
  else {
    const { data, error } = await supabase.from('school_memberships').select('role, schools(id,name,slug)').eq('user_id', user.id).eq('status', 'active');
    if (error) status.textContent = 'Your sign-in worked. School access is awaiting setup or could not be loaded.';
    else if (!data?.length) document.querySelector('#school-state').textContent = 'No active school membership is linked to this account yet.';
    else {
      document.querySelector('#school-state').textContent = 'Your active school access';
      document.querySelector('#portal-message').textContent = 'School access is role-based. Academic and administration modules will appear as they are connected to this workspace.';
      const cards = document.querySelector('#portal-cards');
      for (const row of data) {
        const card = document.createElement('article'); card.className = 'feature-card feature-cream'; card.style.cssText = 'min-height:115px;padding:17px';
        const role = document.createElement('p'); role.className = 'feature-kicker'; role.textContent = row.role.replaceAll('_', ' ').toUpperCase();
        const name = document.createElement('h3'); name.style.fontSize = '14px'; name.textContent = row.schools?.name || 'School';
        card.append(role, name); cards.append(card);
      }
    }
  }
}
