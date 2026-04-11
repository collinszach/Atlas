import type { Metadata } from "next";
import { ClerkProvider } from "@clerk/nextjs";
import { QueryProvider } from "@/providers/QueryProvider";
import "./globals.css";

export const metadata: Metadata = {
  title: "Atlas — Travel Intelligence",
  description: "Your personal travel archive, journal, and planner.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body>
          <QueryProvider>{children}</QueryProvider>
        </body>
      </html>
    </ClerkProvider>
  );
}
