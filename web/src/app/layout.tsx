import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "DXAI Leaderboard",
  description: "AI Developer Pioneer Ranking - Track your AI coding journey",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased min-h-screen`}
      >
        <nav className="border-b border-gray-800 bg-[var(--background)]/80 backdrop-blur-sm sticky top-0 z-50">
          <div className="max-w-5xl mx-auto px-4 py-3 flex items-center justify-between">
            <a href="/" className="text-lg font-bold tracking-tight">
              <span className="text-purple-400">DXAI</span>{" "}
              <span className="text-gray-400 font-normal text-sm">Leaderboard</span>
            </a>
            <a
              href="https://github.com/glen15/dxai"
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-gray-500 hover:text-gray-300 transition-colors"
            >
              GitHub
            </a>
          </div>
        </nav>
        <main className="max-w-5xl mx-auto px-4 py-8">{children}</main>
        <footer className="border-t border-gray-800 mt-16">
          <div className="max-w-5xl mx-auto px-4 py-6 text-center text-sm text-gray-600">
            DXAI - Deus eX AI | AI Developer Pioneer Ranking
          </div>
        </footer>
      </body>
    </html>
  );
}
