import localFont from "next/font/local";

const sans = localFont({ src: "../fonts/Satoshi-Regular.woff2" });
export default function RootLayout() {
  return <html className={sans.className} />;
}
