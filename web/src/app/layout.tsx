import type { Metadata } from "next";
import { JetBrains_Mono, Geist } from "next/font/google";
import "./globals.css";
import { cn } from "@/lib/utils";
import { ClickSpark } from "@/components/ui/click-spark";

const geist = Geist({subsets:['latin'],variable:'--font-sans'});

const jetbrains = JetBrains_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
});

export const metadata: Metadata = {
  title: "AI Vanguard Leaderboard — DXAI",
  description: "Vanguard by DXAI - Track your AI coding journey and compete on the leaderboard",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={cn("dark", "font-sans", geist.variable)}>
      <body
        className={`${jetbrains.variable} antialiased min-h-screen scanlines`}
      >
        <nav className="border-b border-white/[0.04] bg-[#020617]/90 backdrop-blur-md sticky top-0 z-50">
          <div className="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
            <a href="/" className="flex items-center gap-2.5 group">
              <img src="/logo-512.png" alt="DXAI" className="w-7 h-7 rounded-md" />
              <div className="flex items-baseline gap-2">
                <span className="text-sm font-semibold tracking-wide text-white/90 group-hover:text-white transition-colors">
                  Vanguard
                </span>
                <span className="text-xs text-white/30 font-light tracking-widest uppercase">
                  by DXAI
                </span>
              </div>
            </a>
            <a
              href="https://github.com/glen15/dxai"
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-white/30 hover:text-white/60 transition-colors flex items-center gap-1.5 cursor-pointer"
            >
              <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
              </svg>
              GitHub
            </a>
          </div>
        </nav>
        <ClickSpark sparkColor="rgba(167, 139, 250, 0.7)" sparkCount={8} sparkRadius={18}>
          <main className="max-w-6xl mx-auto px-4 py-8">{children}</main>
        </ClickSpark>
        <footer className="border-t border-white/[0.03] mt-16">
          <div className="max-w-6xl mx-auto px-4 py-6 text-center text-xs text-white/20 tracking-wider">
            DXAI — Deus eX AI
          </div>
        </footer>
      </body>
    </html>
  );
}
