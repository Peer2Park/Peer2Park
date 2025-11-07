// auth/tokens.ts
import { CognitoIdentityProviderClient, InitiateAuthCommand } from "@aws-sdk/client-cognito-identity-provider";
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import * as dotenv from "dotenv";

dotenv.config();

const REGION     = process.env.AWS_REGION || "us-east-2";
const CLIENT_ID  = mustEnv("COGNITO_CLIENT_ID");   // User pool app client (no secret)
const USERNAME   = mustEnv("TEST_USERNAME");       // test user for automation
const PASSWORD   = mustEnv("TEST_PASSWORD");       // test user password
const SKEW_SEC   = 60;                              // clock skew buffer

type TokenKind = "id" | "access";

interface StoredTokens {
  id_token?: string;
  access_token?: string;
  refresh_token?: string;
  token_type?: "Bearer";
  expires_in?: number;           // seconds (from last obtain)
  obtained_at?: number;          // epoch seconds
}

const STORE_DIR  = path.join(os.homedir(), ".peer2park");
const STORE_PATH = path.join(STORE_DIR, "tokens.json");

const cip = new CognitoIdentityProviderClient({ region: REGION });

// ---------- public API ----------
/** Returns a fresh JWT string for the requested kind ('id' for REST/Cognito authorizer, 'access' for JWT authorizer). */
export async function getJwt(kind: TokenKind = "id"): Promise<string> {
  // 1) Try disk cache
  let t = loadTokens();

  // 2) If token exists and not expired, use it
  if (t && isTokenFresh(kind, t)) {
    return kind === "id" ? (t.id_token as string) : (t.access_token as string);
  }

  // 3) Try refresh flow if we have a refresh_token
  if (t?.refresh_token) {
    t = await refreshWithCognito(t.refresh_token);
    saveTokens(t);
    return kind === "id" ? (t.id_token as string) : (t.access_token as string);
  }

  // 4) Fall back to username/password sign-in
  t = await loginWithPassword(USERNAME, PASSWORD);
  saveTokens(t);
  return kind === "id" ? (t.id_token as string) : (t.access_token as string);
}

// ---------- internals ----------
function mustEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

function ensureStoreDir() {
  if (!fs.existsSync(STORE_DIR)) fs.mkdirSync(STORE_DIR, { recursive: true });
}

function loadTokens(): StoredTokens | null {
  try {
    if (!fs.existsSync(STORE_PATH)) return null;
    const raw = fs.readFileSync(STORE_PATH, "utf8");
    return JSON.parse(raw) as StoredTokens;
  } catch {
    return null;
  }
}

function saveTokens(t: StoredTokens) {
  ensureStoreDir();
  fs.writeFileSync(STORE_PATH, JSON.stringify(t, null, 2));
}

function decodeJwtPayload<T = any>(jwt?: string): T | null {
  if (!jwt) return null;
  const parts = jwt.split(".");
  if (parts.length !== 3 || !parts[1]) return null;
  const payload = parts[1]
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .padEnd(Math.ceil(parts[1].length / 4) * 4, "=");
  try {
    return JSON.parse(Buffer.from(payload, "base64").toString("utf8")) as T;
  } catch {
    return null;
  }
}

function isExpValid(exp?: number): boolean {
  if (!exp) return false;
  const now = Math.floor(Date.now() / 1000);
  return exp > (now + SKEW_SEC);
}

function isTokenFresh(kind: TokenKind, t: StoredTokens): boolean {
  const jwt = kind === "id" ? t.id_token : t.access_token;
  const payload = decodeJwtPayload<{ exp?: number }>(jwt);
  return isExpValid(payload?.exp);
}

async function loginWithPassword(username: string, password: string): Promise<StoredTokens> {
  const cmd = new InitiateAuthCommand({
    AuthFlow: "USER_PASSWORD_AUTH",    // must be enabled on the app client
    ClientId: CLIENT_ID,
    AuthParameters: { USERNAME: username, PASSWORD: password },
  });
  const res = await cip.send(cmd);
  if (!res.AuthenticationResult) throw new Error("Auth failed: no AuthenticationResult");
  const { IdToken, AccessToken, RefreshToken, ExpiresIn, TokenType } = res.AuthenticationResult;
  return {
    id_token: IdToken!,
    access_token: AccessToken!,
    refresh_token: RefreshToken,       // may be undefined if client not configured to return it
    token_type: (TokenType as "Bearer") ?? "Bearer",
    expires_in: ExpiresIn ?? 3600,
    obtained_at: Math.floor(Date.now() / 1000),
  };
}

async function refreshWithCognito(refreshToken: string): Promise<StoredTokens> {
  const cmd = new InitiateAuthCommand({
    AuthFlow: "REFRESH_TOKEN_AUTH",
    ClientId: CLIENT_ID,
    AuthParameters: {
      REFRESH_TOKEN: refreshToken,
    },
  });
  const res = await cip.send(cmd);
  if (!res.AuthenticationResult) throw new Error("Refresh failed: no AuthenticationResult");
  const { IdToken, AccessToken, ExpiresIn, TokenType, RefreshToken } = res.AuthenticationResult;

  // Cognito may or may not return a new refresh token; keep the old one if omitted
  return {
    id_token: IdToken!,
    access_token: AccessToken!,
    refresh_token: RefreshToken ?? refreshToken,
    token_type: (TokenType as "Bearer") ?? "Bearer",
    expires_in: ExpiresIn ?? 3600,
    obtained_at: Math.floor(Date.now() / 1000),
  };
}
