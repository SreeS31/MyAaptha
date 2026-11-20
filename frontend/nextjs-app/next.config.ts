import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  outputFileTracingRoot: process.cwd(),
  typedRoutes: true,
  output: 'standalone',
  poweredByHeader: false,
  async rewrites() {
    if (process.env.NEXT_PUBLIC_API_BASE_URL) return [];
    const apiOrigin = process.env.MYAAPTHA_API_ORIGIN || 'http://localhost:8080';
    return [{ source: '/api/:path*', destination: `${apiOrigin}/api/:path*` }];
  },
  async headers() {
    return [{
      source: '/(.*)',
      headers: [
        { key: 'Referrer-Policy', value: 'no-referrer' },
        { key: 'Permissions-Policy', value: 'camera=(self), microphone=(self), geolocation=(), payment=(), usb=()' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
        { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' }
      ]
    }, ...['/contacts', '/dashboard', '/api/contact-organizer/oauth/callback/google', '/api/contact-organizer/oauth/callback/microsoft'].map(source => ({
      source,
      // Provider authorization popups must remain connected to the page that opened them.
      // All other routes retain same-origin; CSP and frame protections remain unchanged.
      headers: [{ key: 'Cross-Origin-Opener-Policy', value: 'same-origin-allow-popups' }]
    }))];
  }
};

export default nextConfig;
