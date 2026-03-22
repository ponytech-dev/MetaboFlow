/**
 * Auth token management.
 *
 * - Access token is stored in memory only (never in localStorage).
 * - The server sets an httpOnly refresh_token cookie on login.
 * - On 401, we auto-refresh and retry the original request once.
 */

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000';

let _accessToken: string | null = null;

export function setAccessToken(token: string): void {
  _accessToken = token;
}

export function getAccessToken(): string | null {
  return _accessToken;
}

export function clearAccessToken(): void {
  _accessToken = null;
}

/** Attempt to refresh the access token using the httpOnly refresh cookie. */
export async function refreshAccessToken(): Promise<string | null> {
  try {
    const res = await fetch(`${API_BASE}/api/v1/auth/refresh`, {
      method: 'POST',
      credentials: 'include', // send the httpOnly cookie
    });
    if (!res.ok) return null;
    const data = (await res.json()) as { access_token: string };
    setAccessToken(data.access_token);
    return data.access_token;
  } catch {
    return null;
  }
}

/** Authenticated fetch — auto-refreshes on 401 and retries once. */
export async function authFetch(
  input: RequestInfo | URL,
  init?: RequestInit
): Promise<Response> {
  const makeRequest = (token: string | null) =>
    fetch(input, {
      ...init,
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        ...(init?.headers as Record<string, string> | undefined),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    });

  let res = await makeRequest(_accessToken);

  if (res.status === 401) {
    const newToken = await refreshAccessToken();
    if (newToken) {
      res = await makeRequest(newToken);
    }
  }

  return res;
}

export interface LoginPayload {
  email: string;
  password: string;
}

export interface RegisterPayload {
  email: string;
  password: string;
  invite_code: string;
}

export interface AuthTokens {
  access_token: string;
  user_id: string;
}

export async function login(payload: LoginPayload): Promise<AuthTokens> {
  const res = await fetch(`${API_BASE}/api/v1/auth/login`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(text);
  }
  const data = (await res.json()) as AuthTokens;
  setAccessToken(data.access_token);
  return data;
}

export async function register(payload: RegisterPayload): Promise<AuthTokens> {
  const res = await fetch(`${API_BASE}/api/v1/auth/register`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(text);
  }
  const data = (await res.json()) as AuthTokens;
  setAccessToken(data.access_token);
  return data;
}
