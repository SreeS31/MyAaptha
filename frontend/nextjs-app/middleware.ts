import { NextRequest, NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
  const nonce = btoa(crypto.randomUUID());
  const apiOrigin = process.env.NEXT_PUBLIC_API_BASE_URL || (process.env.NODE_ENV === 'production' ? '' : 'http://localhost:8080');
  const upgrade = apiOrigin.startsWith('https://') ? '; upgrade-insecure-requests' : '';
  const policy = [
    "default-src 'self'",
    "base-uri 'self'",
    "object-src 'none'",
    "frame-ancestors 'none'",
    "form-action 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${process.env.NODE_ENV === 'development' ? " 'unsafe-eval'" : ''}`,
    "style-src 'self' 'unsafe-inline'",
    `img-src 'self' data: blob: ${apiOrigin}`,
    `media-src 'self' blob: ${apiOrigin}`,
    `connect-src 'self' https://challenges.cloudflare.com ${apiOrigin}`,
    "font-src 'self' data:",
    "frame-src https://challenges.cloudflare.com",
  ].join('; ') + upgrade;
  const headers = new Headers(request.headers);
  headers.set('x-nonce', nonce);
  headers.set('Content-Security-Policy', policy);
  const response = NextResponse.next({ request: { headers } });
  response.headers.set('Content-Security-Policy', policy);
  return response;
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|myaaptha-logo.png).*)'],
};
