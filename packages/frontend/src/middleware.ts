/**
 * Next.js Edge Middleware — redirect unauthenticated users to /login.
 *
 * We check for the presence of the httpOnly `refresh_token` cookie set by the
 * backend on login.  The access token is in-memory only and is not visible
 * here, so the refresh cookie is the only server-side signal we have.
 *
 * Public paths (login, register, and the home page) are exempted.
 */

import { NextRequest, NextResponse } from 'next/server';

const PUBLIC_PATHS = new Set(['/', '/login', '/register']);

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Allow public paths and Next.js internals
  if (
    PUBLIC_PATHS.has(pathname) ||
    pathname.startsWith('/_next') ||
    pathname.startsWith('/favicon')
  ) {
    return NextResponse.next();
  }

  const hasRefreshToken = request.cookies.has('refresh_token');
  if (!hasRefreshToken) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('next', pathname);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
