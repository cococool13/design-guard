import { Inter, Geist_Mono } from "next/font/google";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html>{children}</html>;
}
