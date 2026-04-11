/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  experimental: {
    typedRoutes: true,
  },
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "img.clerk.com" },
    ],
  },
};

export default nextConfig;
