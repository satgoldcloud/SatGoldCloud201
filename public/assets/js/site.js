const menuButton = document.querySelector('.menu-toggle');
const nav = document.querySelector('.main-nav');
menuButton?.addEventListener('click', () => {
  const open = nav.classList.toggle('open');
  menuButton.setAttribute('aria-expanded', String(open));
});
nav?.querySelectorAll('a').forEach((link) => link.addEventListener('click', () => {
  nav.classList.remove('open');
  menuButton?.setAttribute('aria-expanded', 'false');
}));
document.querySelector('#year').textContent = new Date().getFullYear();

async function submitForm(form, endpoint, payload) {
  const status = form.querySelector('.form-status');
  const button = form.querySelector('button[type="submit"]');
  status.textContent = 'Please wait…';
  status.classList.remove('error');
  button.disabled = true;
  try {
    const response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'The request could not be completed.');
    status.textContent = result.message || 'Your request was received.';
    if (result.accessToken) {
      sessionStorage.setItem('satgold_access_token', result.accessToken);
      sessionStorage.setItem('satgold_refresh_token', result.refreshToken);
      sessionStorage.setItem('satgold_user', JSON.stringify(result.user));
      sessionStorage.removeItem('satgold_pending_school');
      location.href = '/portal.html';
    } else if (form.id === 'register-form') {
      sessionStorage.setItem('satgold_pending_school', payload.schoolName);
      form.reset();
    }
  } catch (error) {
    status.textContent = error.message;
    status.classList.add('error');
  } finally { button.disabled = false; }
}

document.querySelector('#register-form')?.addEventListener('submit', (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const data = new FormData(form);
  submitForm(form, '/api/schools/register', { schoolName: data.get('schoolName'), fullName: data.get('fullName'), email: data.get('email'), password: data.get('password') });
});
document.querySelector('#login-form')?.addEventListener('submit', (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const data = new FormData(form);
  submitForm(form, '/api/auth/login', { email: data.get('email'), password: data.get('password'), pendingSchoolName: sessionStorage.getItem('satgold_pending_school') });
});
