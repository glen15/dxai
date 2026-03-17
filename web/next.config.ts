import type { NextConfig } from "next";

// 보안 헤더는 CloudFront Response Headers Policy로 처리
const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
};

export default nextConfig;
