import type { Metadata } from "next";
import "./globals.css";
import { SiteHeader } from "@/components/site-header";
export const metadata: Metadata = { title: "DropZone | Gaming Giveaways", description: "Free-entry gaming rewards and community drops." };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body><SiteHeader/><main>{children}</main><footer style={{maxWidth:1180,margin:"auto",padding:"20px 24px 35px",borderTop:"1px solid #1b2332",color:"#69758a",fontSize:10,display:"flex",justifyContent:"space-between"}}><span>© {new Date().getFullYear()} DROPZONE · COMMUNITY GAMING REWARDS</span><span>Free-entry platform · Rules apply</span></footer></body></html>; }
