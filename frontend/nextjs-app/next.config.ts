import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  typedRoutes: true,
  output: 'standalone',
  poweredByHeader: false,
  async rewrites() {
    if (process.env.NEXT_PUBLIC_API_BASE_URL) return [];
    const apiOrigin = process.env.MYAAPTHA_API_ORIGIN || 'http://localhost:8080';
    return [{ source: '/api/:path*', destination: `${apiOrigin}/api/:path*` }];
  },
  async headers() {
    const apiOrigin = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8080';
    const upgradeInsecureRequests = apiOrigin.startsWith('https://') ? '; upgrade-insecure-requests' : '';
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
    }];
  }
};

export default nextConfig;
