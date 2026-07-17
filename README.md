# ⚡ Grindpoint

**Nigeria's Premier Micro-Task Earning Platform**

A fully functional, production-ready micro-task website where Nigerian users complete simple online tasks and earn real Naira — paid directly to their bank account or mobile wallet.

---

## 📁 Project Structure

```
grindpoint/
├── index.html              ← Landing page (dynamic CTAs)
├── register.html           ← Sign up with referral support
├── login.html              ← Sign in with show/hide password
├── dashboard.html          ← Protected user dashboard + wallet
├── tasks.html              ← Micro-task earning hub (12 tasks)
├── referral.html           ← Referral program + share buttons
├── leaderboard.html        ← Live top-10 earners table
├── profile.html            ← User profile & settings
├── transactions.html       ← Full earnings & withdrawal history
├── forgot-password.html    ← Password reset request
├── update-password.html    ← New password after reset link
├── 404.html                ← Custom not-found page
├── supabase-setup.sql      ← Complete database schema + seed data
│
├── css/
│   └── style.css           ← Master stylesheet (dark gold theme)
│
├── js/
│   ├── supabase-config.js  ← Supabase client + session utilities
│   └── main.js             ← Toast, loading states, field errors
│
└── admin/
    ├── index.html          ← Admin dashboard with KPIs
    ├── users.html          ← User management (edit, ban, credit)
    ├── withdrawals.html    ← Process withdrawal requests
    ├── tasks-admin.html    ← Task manager + SQL schema helper
    ├── announcements.html  ← Post platform announcements
    └── settings.html       ← Site-wide settings & toggles
```

---

## 🚀 Quick Setup

### Step 1 — Set Up Supabase Database

1. Log into [supabase.com](https://supabase.com) and open your project
2. Go to **SQL Editor → New Query**
3. Copy and paste the entire contents of **`supabase-setup.sql`**
4. Click **Run**
5. All tables, RLS policies, and seed data will be created

### Step 2 — Create Your Admin Account

1. Open the site and go to `register.html`
2. Create your account normally
3. Back in Supabase **SQL Editor**, run:

```sql
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'YOUR-EMAIL@example.com';
```

4. You can now access the Admin Panel at `admin/index.html`

### Step 3 — Deploy

Upload the entire `grindpoint/` folder to any static host:
- **Netlify** (drag & drop the folder) ← Recommended, free
- **Vercel** (`vercel --prod`)
- **GitHub Pages** (push to repo, enable Pages)
- **cPanel / Shared Hosting** (upload via File Manager)

---

## 🗄️ Database Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User accounts, balance, tasks_completed, role |
| `tasks` | Platform task definitions |
| `completed_tasks` | Log of tasks each user has finished |
| `withdrawal_requests` | Withdrawal request queue |
| `announcements` | Platform-wide announcements |
| `site_settings` | Key-value platform configuration |

---

## 🎨 Design System

- **Theme:** Dark Charcoal × Gold/Amber Premium
- **Fonts:** Syne (display) + DM Sans (body) + JetBrains Mono (code)
- **Primary Color:** `#f59e0b` (Amber Gold)
- **Background:** `#0b0c0e` (Near Black)
- **Breakpoints:** Mobile-first, responsive at 768px and 480px

---

## 💰 Earning System

| Type | Amount |
|------|--------|
| Task completion | ₦120 – ₦600 (varies by task) |
| Referral (Starter, 0–9 refs) | ₦200/ref |
| Referral (Hustler, 10–49 refs) | ₦300/ref |
| Referral (Champion, 50+ refs) | ₦500/ref |
| Minimum withdrawal | ₦1,000 |

---

## 🛡️ Security

- All protected pages call `requireAuth()` which redirects unauthenticated users to `login.html`
- Admin pages check `profile.role === 'admin'` before rendering content
- Supabase Row Level Security (RLS) is enabled on all tables
- Users can only read/write their own data
- Passwords are never stored client-side — handled entirely by Supabase Auth

---

## 🔌 Supabase Config

Credentials are in `js/supabase-config.js`:

```js
const SUPABASE_URL  = "https://hfbquuhbfjfeiosktdhl.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_Mp7LjPCYeTStuHs45xjifQ_vc3B1dMQ";
```

These are **public** (anon) keys — safe to expose in client-side code. RLS policies protect your data.

---

## 📞 Support

For issues or feature requests, contact the Grindpoint development team.

---

*Built with ❤️ for Nigeria*
