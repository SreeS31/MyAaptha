import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  typedRoutes: true,
  output: 'standalone',
  poweredByHeader: false,
  async headers() {
    const apiOrigin = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080';
    const upgradeInsecureRequests = apiOrigin.startsWith('https://') ? '; upgrade-insecure-requests' : '';
    return [{
      source: '/(.*)',
      headers: [
        { key: 'Content-Security-Policy', value: `default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: ${apiOrigin}; media-src 'self' blob: ${apiOrigin}; connect-src 'self' ${apiOrigin}; font-src 'self' data:${upgradeInsecureRequests}` },
        { key: 'Referrer-Policy', value: 'no-referrer' },
        { key: 'Permissions-Policy', value: 'camera=(self), microphone=(self), geolocation=(), payment=(), usb=()' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
        { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' }
      ]
    }];
  }
};

export default nextConfig;
