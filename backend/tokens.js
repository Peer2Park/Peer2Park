// tokens.js — PKCE + Hosted UI helper for Cognito (Node 18+)
// Usage:
//   node tokens.js             # prints "Authorization: Bearer <token>"
//   const { getAccessToken } = require('./tokens'); // in your code

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { URL, URLSearchParams } = require('url');
const { spawn } = require('child_process');

// ==== CONFIGURE THESE ====
const REGION = 'us-east-2';
const HOSTED_DOMAIN = 'peer2park-dev.auth.us-east-2.amazoncognito.com';
const CLIENT_ID = '2ttree8k40b2aih8uhugh5p973';
const REDIRECT_URI = 'http://localhost:3000/auth/callback'; // choose a free port
const SCOPES = [
  'openid',
  'email',
  'profile',
  'https://parking-api/users.read',
  'https://parking-api/users.write',
];
// =========================

const storePath = path.join(os.homedir(), '.peer2park', 'tokens.json');
fs.mkdirSync(path.dirname(storePath), { recursive: true });

/** @typedef {{access_token:string,id_token?:string,refresh_token?:string,token_type:'Bearer',expires_in:number,obtained_at:number}} Tokens */

function saveTokens(t) {
  fs.writeFileSync(storePath, JSON.stringify(t, null, 2));
}
function loadTokens() {
  if (!fs.existsSync(storePath)) return null;
  return JSON.parse(fs.readFileSync(storePath, 'utf-8'));
}
function isIdTokenFresh(tokens, skewSec = 60) {
  if (!tokens) return false;
  const now = Math.floor(Date.now() / 1000);
  return now < tokens.obtained_at + tokens.expires_in - skewSec;
}

async function tokenRequest(body) {
  const res = await fetch(`https://${HOSTED_DOMAIN}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(body),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`Token endpoint ${res.status}: ${text}`);
  }
  return res.json();
}

async function refreshWithStored() {
  const t = loadTokens();
  if (!t?.refresh_token) return null;
  const res = await tokenRequest({
    grant_type: 'refresh_token',
    client_id: CLIENT_ID,
    refresh_token: t.refresh_token,
  });
  const merged = {
    ...res,
    refresh_token: res.refresh_token ?? t.refresh_token,
    obtained_at: Math.floor(Date.now() / 1000),
  };
  saveTokens(merged);
  return merged;
}

function genPkce() {
  const verifier = crypto.randomBytes(32).toString('base64url');
  const challenge = crypto.createHash('sha256').update(verifier).digest('base64url');
  return { verifier, challenge };
}

function openBrowser(url) {
  const platform = process.platform;
  if (platform === 'darwin') spawn('open', [url], { stdio: 'ignore', detached: true });
  else if (platform === 'win32') spawn('rundll32', ['url.dll,FileProtocolHandler', url], { stdio: 'ignore', detached: true });
  else spawn('xdg-open', [url], { stdio: 'ignore', detached: true });
}

async function interactiveLogin() {
  const { verifier, challenge } = genPkce();

  const authUrl =
    `https://${HOSTED_DOMAIN}/oauth2/authorize` +
    `?client_id=${encodeURIComponent(CLIENT_ID)}` +
    `&response_type=code` +
    `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
    `&scope=${encodeURIComponent(SCOPES.join(' '))}` +
    `&code_challenge=${encodeURIComponent(challenge)}` +
    `&code_challenge_method=S256`;

  // tiny local server to catch the ?code=...
  const codePromise = new Promise((resolve, reject) => {
    const serverUrl = new URL(REDIRECT_URI);
    const server = http.createServer((req, res) => {
      const u = new URL(req.url || '/', REDIRECT_URI);
      const code = u.searchParams.get('code');
      const error = u.searchParams.get('error');
      if (error) {
        res.writeHead(400).end('OAuth error: ' + error);
        server.close();
        reject(new Error(error));
        return;
      }
      if (code) {
        res.writeHead(200).end('Login complete. You can close this tab.');
        server.close();
        resolve(code);
      } else {
        res.writeHead(404).end('Not found');
      }
    });
    server.listen(Number(serverUrl.port));
  });

  openBrowser(authUrl);
  const code = await codePromise;

  const res = await tokenRequest({
    grant_type: 'authorization_code',
    client_id: CLIENT_ID,
    code,
    redirect_uri: REDIRECT_URI,
    code_verifier: verifier,
  });

  const tokens = {
    ...res,
    obtained_at: Math.floor(Date.now() / 1000),
  };
  saveTokens(tokens);
  return tokens;
}

async function getIdToken() {
  const existing = loadTokens();
  if (isIdTokenFresh(existing)) return existing.id_token;

  if (existing?.refresh_token) {
    const refreshed = await refreshWithStored();
    if (refreshed) return refreshed.id_token;
  }
  const fresh = await interactiveLogin();
  console.log(fresh);
  return fresh.id_token;
}

module.exports = { getIdToken };

// If run directly: print a ready-to-use Authorization header
if (require.main === module) {
  getIdToken()
    .then((t) => console.log(`Authorization: Bearer ${t}`))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}

