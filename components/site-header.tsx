import Link from "next/link";
import { Gamepad2 } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
export async function SiteHeader(){const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();return <header className="site-header"><Link href="/" className="brand"><span className="brand-mark"><Gamepad2 size={20}/></span><span>DROP<em>ZONE</em></span></Link><nav className="nav"><Link href="/giveaways">Giveaways</Link>{user?<><Link href="/dashboard">My account</Link><Link className="nav-cta" href="/admin">Admin / Console</Link></>:<><Link href="/login">Sign in</Link><Link className="nav-cta" href="/signup">Join free</Link></>}</nav></header>}
