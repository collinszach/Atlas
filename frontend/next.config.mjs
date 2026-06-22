/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  experimental: {},
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "img.clerk.com" },
    ],
  },
};

export default nextConfig;
