'use strict';

const byID = id => document.getElementById(id);
const auth = byID('auth-form');
const authFields = byID('auth-fields');
const email = byID('email');
const password = byID('password');
const consent = byID('consent');
const authError = byID('auth-error');
const authSubmit = byID('auth-submit');
const authMode = byID('auth-mode');
const accessBack = byID('access-back');
const feed = byID('feed');
const filters = byID('filters');
const clearFilter = byID('clear-filter');
const collectionSearch = byID('collection-search');
const cardCache = new Map();
const pageSize = 10;
let signingUp = false;
let requestInFlight = false;
let filter = 'all';
let shown = pageSize;
let lines = [];
let refreshPending = false;

function request(action, data = {}) {
  const channel = window.webkit?.messageHandlers?.nina;
  if (!channel) {
    throw new Error('Open this community in the iPhone app.');
  }
  return channel.postMessage({action, data});
}

function message(node, value) {
  node.textContent = value || '';
  node.hidden = !value;
}

async function publishAuthState() {
  try {
    await request('authState', {
      visible: !byID('access').hidden,
      accepted: consent.checked,
      busy: requestInFlight,
    });
  } catch (error) {
    message(authError, error?.message || 'Sign-in options are unavailable. Try again.');
  }
}

async function perform(control, feedback, work) {
  if (requestInFlight) return;
  requestInFlight = true;
  control.disabled = true;
  message(feedback, '');
  publishAuthState();
  try {
    await work();
  } catch (error) {
    message(feedback, error?.message || 'Try that again.');
  } finally {
    requestInFlight = false;
    control.disabled = false;
    publishAuthState();
    if (refreshPending) void refreshState();
  }
}

async function refreshState() {
  if (!refreshPending || requestInFlight) return;
  refreshPending = false;
  requestInFlight = true;
  try {
    show(await request('snapshot'));
  } catch (error) {
    message(byID('notice'), error?.message || 'Could not refresh the collection. Open this tab again.');
  } finally {
    requestInFlight = false;
    if (refreshPending) void refreshState();
  }
}

window.ninaRefresh = () => {
  refreshPending = true;
  void refreshState();
};

function clearAuthError() {
  for (const control of [email, password, consent]) {
    control.removeAttribute('aria-invalid');
    control.removeAttribute('aria-errormessage');
  }
  message(authError, '');
}

function authIssue(control, text) {
  control.setAttribute('aria-invalid', 'true');
  control.setAttribute('aria-errormessage', 'auth-error');
  message(authError, text);
  control.focus();
  return false;
}

function validateAuth() {
  clearAuthError();
  const address = email.value.trim();
  if (address.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(address)) return authIssue(email, 'Enter a valid email address.');
  if (!password.value.trim()) return authIssue(password, 'Enter a password to continue.');
  if (password.value.length > 256) return authIssue(password, 'Use a password with 256 characters or fewer.');
  if (!consent.checked) return authIssue(consent, 'Agree to the Terms and Privacy Policy to continue.');
  return true;
}

function setMode(register) {
  signingUp = register;
  password.value = '';
  password.autocomplete = register ? 'new-password' : 'current-password';
  byID('auth-title').textContent = register ? 'Create your profile' : 'Welcome back';
  authMode.textContent = register ? 'Already have a profile? Sign in' : 'New here? Create a profile';
  authSubmit.textContent = register ? 'Create profile' : 'Sign in';
  clearAuthError();
}

function showWelcome() {
  byID('access').hidden = true;
  byID('welcome').hidden = false;
  accessBack.hidden = true;
  document.body.dataset.screen = 'welcome';
  publishAuthState();
}

function openAccess(register) {
  if (requestInFlight) return;
  setMode(register);
  byID('welcome').hidden = true;
  byID('access').hidden = false;
  accessBack.hidden = false;
  document.body.dataset.screen = 'access';
  publishAuthState();
  window.scrollTo(0, 0);
  byID('auth-title').focus({preventScroll: true});
}

function updateCard(article, line) {
  const like = article.querySelector('[data-action="like"]');
  const save = article.querySelector('[data-action="save"]');
  like.setAttribute('aria-pressed', String(line.liked));
  save.setAttribute('aria-pressed', String(line.saved));
  like.querySelector('span').textContent = (line.liked ? 'Liked' : 'Like') + (line.likes > 0 ? ' ' + line.likes : '');
  save.querySelector('span').textContent = line.saved ? 'Saved' : 'Save';
  article.querySelector('summary').textContent = 'Comments (' + line.comments.length + ')';
  article.querySelector('[data-action="discussion"] span').textContent = 'Comment' + (line.comments.length ? ' ' + line.comments.length : '');
  const comments = line.comments.map(comment => {
    const item = document.createElement('li');
    const name = document.createElement('strong');
    name.textContent = comment.name;
    item.append(name, document.createTextNode(comment.body));
    return item;
  });
  article.querySelector('[data-item="comments"]').replaceChildren(...comments);
}

function makeCard(line) {
  const article = byID('line-template').content.firstElementChild.cloneNode(true);
  cardCache.set(line.id, article);
  article.dataset.line = line.id;
  article.querySelector('[data-item="collection"]').textContent =
    line.label + (line.type === 'video' ? ' / Clip' : ' / Photo');
  article.querySelector('[data-item="title"]').textContent = line.title;
  const open = article.querySelector('[data-action="open"]');
  const ratio = Number(line.width) / Math.max(1, Number(line.height));
  if (Number.isFinite(ratio)) open.style.setProperty('--line-ratio', String(Math.max(.8, Math.min(1.5, ratio))));
  article.querySelector('[data-item="play"]').hidden = line.type !== 'video';
  article.querySelector('[data-action="report"]').setAttribute('aria-label', 'Report ' + line.title);
  const discussion = article.querySelector('.discussion');
  discussion.id = 'discussion-' + line.id;
  const discussionButton = article.querySelector('[data-action="discussion"]');
  discussionButton.setAttribute('aria-controls', discussion.id);
  discussion.addEventListener('toggle', () => discussionButton.setAttribute('aria-expanded', String(discussion.open)));
  const label = line.type === 'video' ? 'Watch clip' : 'View photo';
  open.querySelector('[data-item="open-label"]').textContent = label;
  open.setAttribute('aria-label', label + ' ' + line.title);
  const frame = article.querySelector('.line-image');
  const photo = frame.querySelector('img');
  const missing = article.querySelector('[data-item="image-error"]');
  if (line.image) {
    photo.addEventListener('error', () => {
      frame.hidden = true;
      missing.hidden = false;
    }, {once: true});
    frame.hidden = false;
    photo.src = line.image;
  } else {
    missing.hidden = false;
  }
  updateCard(article, line);
  return article;
}

function renderFeed() {
  const query = collectionSearch.value.trim().toLocaleLowerCase();
  const matching = lines.filter(line => (filter === 'all' || (filter === 'saved' ? line.saved : line.collection === filter)) &&
    (!query || (line.title + ' ' + line.label).toLocaleLowerCase().includes(query)));
  const cards = matching.slice(0, shown).map(line => {
    const article = cardCache.get(line.id) || makeCard(line);
    updateCard(article, line);
    return article;
  });
  for (const child of [...feed.children]) {
    if (!cards.includes(child)) child.remove();
  }
  cards.forEach((article, index) => {
    if (feed.children[index] !== article) feed.insertBefore(article, feed.children[index] || null);
  });
  const empty = matching.length === 0;
  byID('empty-state').hidden = !empty;
  byID('empty').textContent = empty
    ? (query ? 'No matching lines. Try another title or terrain.' : filter === 'saved' ? 'Nothing saved yet. Save a photo or clip to find it here.' : 'No lines match this filter. Choose another filter to keep browsing.')
    : '';
  clearFilter.hidden = filter === 'all' && !query;
  const saved = filters.querySelector('[data-filter="saved"]');
  const savedCount = lines.filter(line => line.saved).length;
  saved.textContent = 'Saved' + (savedCount ? ' ' + savedCount : '');
  byID('more').hidden = shown >= matching.length;
}

function selectFilter(button) {
  if (requestInFlight || button.dataset.filter === filter) return;
  filter = button.dataset.filter;
  shown = pageSize;
  filters.querySelectorAll('button[data-filter]').forEach(choice => {
    choice.setAttribute('aria-pressed', String(choice === button));
  });
  renderFeed();
}

function show(state) {
  const signedIn = state.name !== null;
  message(byID('startup'), '');
  byID('access').hidden = true;
  byID('welcome').hidden = signedIn;
  accessBack.hidden = true;
  document.body.dataset.screen = signedIn ? 'community' : 'welcome';
  byID('community').hidden = !signedIn;
  byID('community-bar').hidden = !signedIn;
  message(byID('notice'), state.warning);
  if (signedIn) {
    byID('profile-name').textContent = 'Hi, ' + state.name;
    lines = state.lines;
    renderFeed();
  } else {
    lines = [];
    cardCache.clear();
    feed.replaceChildren();
    setMode(false);
  }
  publishAuthState();
}

async function start() {
  if (requestInFlight) return;
  requestInFlight = true;
  const retry = byID('retry');
  retry.hidden = true;
  message(byID('startup'), 'Opening your community…');
  try {
    show(await request('snapshot'));
  } catch (error) {
    message(byID('startup'), error.message);
    retry.hidden = false;
  } finally {
    requestInFlight = false;
    if (refreshPending) void refreshState();
  }
}

byID('retry').addEventListener('click', start);
document.querySelectorAll('button[data-access]').forEach(button => {
  button.addEventListener('click', () => openAccess(button.dataset.access === 'register'));
});
accessBack.addEventListener('click', () => {
  if (requestInFlight) return;
  password.value = '';
  clearAuthError();
  showWelcome();
  window.scrollTo(0, 0);
  byID('welcome-title').focus({preventScroll: true});
});
authMode.addEventListener('click', () => {
  if (requestInFlight) return;
  setMode(!signingUp);
  byID('auth-title').focus();
});
auth.addEventListener('input', clearAuthError);
consent.addEventListener('change', publishAuthState);
auth.addEventListener('submit', event => {
  event.preventDefault();
  if (requestInFlight || !validateAuth()) return;
  void perform(authSubmit, authError, async () => {
    const label = authSubmit.textContent;
    const credentials = {email: email.value, password: password.value, consent: 'agreed'};
    authSubmit.textContent = signingUp ? 'Creating profile…' : 'Signing in…';
    auth.setAttribute('aria-busy', 'true');
    authFields.disabled = true;
    authMode.disabled = true;
    accessBack.disabled = true;
    try {
      const state = await request(signingUp ? 'register' : 'signIn', credentials);
      auth.reset();
      show(state);
      if (state.name !== null) byID('community-title').focus();
    } finally {
      authSubmit.textContent = label;
      auth.removeAttribute('aria-busy');
      authFields.disabled = false;
      authMode.disabled = false;
      accessBack.disabled = false;
    }
  });
});

document.querySelectorAll('button[data-policy]').forEach(button => {
  button.addEventListener('click', () => {
    void perform(button, byID('notice'), () => request('policy', {name: button.dataset.policy}));
  });
});
document.querySelectorAll('button[data-tab]').forEach(button => {
  button.addEventListener('click', () => {
    void perform(button, byID('notice'), () => request('journal', {tab: button.dataset.tab, page: button.dataset.page || ''}));
  });
});

filters.addEventListener('click', event => {
  const button = event.target.closest('button[data-filter]');
  if (button) selectFilter(button);
});
clearFilter.addEventListener('click', () => {
  if (requestInFlight) return;
  collectionSearch.value = '';
  filter = '';
  const all = filters.querySelector('[data-filter="all"]');
  selectFilter(all);
  all.focus();
});
collectionSearch.addEventListener('input', () => {
  shown = pageSize;
  renderFeed();
});
byID('more').addEventListener('click', () => {
  if (requestInFlight) return;
  const firstNew = feed.childElementCount;
  shown += pageSize;
  renderFeed();
  feed.children[firstNew]?.querySelector('[data-action="open"]')?.focus();
});

function acceptChange(article, updated) {
  lines = lines.map(line => line.id === updated.id ? updated : line);
  if (filter === 'saved' && !updated.saved) {
    const neighbor = article.nextElementSibling ?? article.previousElementSibling;
    article.remove();
    renderFeed();
    const nextCard = neighbor ?? feed.firstElementChild;
    const nextControl = nextCard?.querySelector('[data-action="save"]') ?? byID('empty');
    nextControl.focus();
  } else {
    renderFeed();
  }
}

feed.addEventListener('click', event => {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const article = button.closest('article');
  const id = article.dataset.line;
  const action = button.dataset.action;
  if (action === 'discussion') {
    const discussion = article.querySelector('.discussion');
    discussion.open = !discussion.open;
    if (discussion.open) discussion.querySelector('textarea').focus();
    return;
  }
  if (!['open', 'report', 'like', 'save'].includes(action)) return;
  void perform(button, article.querySelector('[data-item="feedback"]'), async () => {
    if (action === 'report') {
      await request('journal', {tab: 'lines', page: 'report', id});
    } else if (action === 'open') {
      await request('journal', {tab: 'lines', id});
    } else {
      acceptChange(article, await request(action, {id}));
    }
  });
});
feed.addEventListener('submit', event => {
  event.preventDefault();
  if (requestInFlight) return;
  const form = event.target;
  const article = form.closest('article');
  const text = form.querySelector('textarea');
  const feedback = form.querySelector('[data-item="comment-feedback"]');
  if (!text.value.trim()) {
    message(feedback, 'Write a comment first.');
    text.focus();
    return;
  }
  void perform(form.querySelector('button'), feedback, async () => {
    text.readOnly = true;
    try {
      const updated = await request('comment', {id: article.dataset.line, body: text.value});
      text.value = '';
      acceptChange(article, updated);
    } finally {
      text.readOnly = false;
    }
  });
});

void start();
