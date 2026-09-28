/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // No Vercel-specific config here on purpose (no `output: 'standalone'`
  // requirement, no Edge Runtime, no platform adapters) — this app is meant
  // to run as a plain `next start` Node process on Hostinger Node.js
  // hosting, a VPS, or any other Node host.
};

module.exports = nextConfig;
