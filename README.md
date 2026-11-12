# DropZone — Free-entry gaming giveaway platform

Professional Next.js + Supabase starter with a gaming UI, auth, user dashboard, admin console, giveaway management, admin ticket grants, and SQL-backed draw RPC.

## Setup
1. Install Node.js 20+ and unzip this project.
2. `npm install`
3. Create a Supabase project at https://supabase.com.
4. In Supabase SQL Editor, run `supabase/schema.sql` in full.
5. Copy `.env.example` to `.env.local` and fill the project URL and anon key.
6. In Supabase Auth settings, configure site URL (local `http://localhost:3000`) and email confirmation as desired.
7. `npm run dev`, then open http://localhost:3000.

## Make an admin
Sign up normally, then in Supabase SQL Editor (replace email):
```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'your-email@example.com');
```
Admin role is server/database protected; don't expose service-role key in browser.

## Implemented in this starter
- Supabase email/password sign up and sign in.
- Session-aware account and admin pages.
- Giveaway listing/details with status and ticket count.
- Admin giveaway creation, free ticket grants to registered users.
- Draw action via a database RPC using server-side database logic and admin checks.
- Row-level security policies and admin audit records.

## Production checklist
This is a deployable starter, not a turnkey production service. Add branded email templates, CAPTCHA/rate limiting, audit review, secure operational backups, observability, and legal review for the target jurisdiction. Keep giveaways free-entry; do not add paid ticket checkout without qualified local legal/payment compliance approval. Verify Garena terms before offering account transfers; prefer officially permitted top-ups/items. Test RLS, draw fairness, admin flows, and recovery in a staging project. Add a proper public rules page and privacy policy before launch.
