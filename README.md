# SatGold Cloud

Responsive marketing site and early Supabase/Vercel foundation for SatGold Cloud, a multi-school management SaaS concept from SatGold Technol. The repository was empty at the start of this implementation; there was no existing site or application code to preserve.

## Current implementation

- Responsive public home page with original SatGold visual identity, marketing copy, feature overview, pricing, FAQs and structured footer.
- About page, draft Terms and Privacy pages, canonical URLs, sitemap, robots rules and SoftwareApplication structured data.
- Vercel Node.js functions for Supabase email/password sign-in and school registration.
- Supabase PostgreSQL initial migration with school-scoped relationships, memberships, core academic/operational records, subscriptions, audit rows, RLS and an atomic owner school-registration RPC.
- Login sends users to a minimal membership view. Full role-specific workspaces and academic workflows are not implemented.

## Local setup

1. Use Node.js 22 or newer.
2. Create a Supabase project for development and apply `supabase/migrations/202610120001_initial_school_platform.sql` using the Supabase CLI or SQL editor.
3. Copy `.env.example` to `.env.local` and set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and `APP_URL`. Keep the service-role key server-side.
4. In Supabase Auth, configure email confirmation, the site URL, and the local/Vercel redirect URLs. The registration flow asks the owner to verify email and then sign in to finish creating the school workspace.
5. Run `npm install`, then `npm run dev`.

The public `SUPABASE_ANON_KEY` is returned by `/api/config`; this is expected and safe only with RLS correctly configured. The service-role key is read only inside the server functions and must never be added to `public/` or client code.

## Deploy to Vercel

Import the repository into Vercel, set the four required environment values separately for Preview and Production, and deploy. The project uses Vercel's built-in Node.js Functions under `/api`. Confirm Supabase Auth redirect URLs against the actual preview/production hostnames. Add `satgoldcloud.name.ng` in the Vercel project domain settings and use only the DNS records Vercel provides after ownership is verified. GitHub automatic deployment requires connecting the repository and selecting the production branch in Vercel.

## Migration and security notes

The migration defines school membership roles, core school and academic tables, scoped foreign keys for core records, family visibility for published results, private payroll reads, and RLS policies. `register_school_for_owner` is executable only by the Supabase service role. It creates the profile, school, owner membership and audit entry in one database transaction. Parent-child association requires a verified guardian link; the provisioning/invitation workflow that creates and verifies those links is not implemented yet.

Apply the migration to a disposable Supabase project and review generated RLS behavior before production. This initial schema is a foundation, not a finished security certification. In particular, exam timing, answer-key delivery, upload buckets, administrator-mediated publication APIs, platform super-admin procedures, rate limiting, security monitoring, and comprehensive tenant isolation tests remain to be implemented and verified. The Supabase service role bypasses RLS; server functions using it must validate the caller and constrain every operation.

## Integrations and current limits

- **Supabase Auth/Postgres:** registration, sign-in and database foundation implemented; workspace continuation after email confirmation is supported by the login flow. No local Supabase credentials were supplied, so the integration was not exercised against a live project.
- **Vercel:** compatible project/function structure is present; no Vercel account, deployment or domain DNS was available to configure.
- **Paystack, Flutterwave, Resend, Gemini:** variables are placeholders only. Checkout initialization/verification, signed and idempotent webhooks, outbound email templates/delivery, and authorized server-side AI are not implemented. Do not accept payments or send private student information to AI through this starter.
- **Plans:** Starter ₦20,000 and Premium ₦50,000 monthly display on the site, with Custom contact option. The database has editable monthly plan rows and a trial duration seed; annual prices, trial eligibility automation, entitlements enforcement and billing lifecycle are not implemented. Displayed pricing must be confirmed by SatGold Technol before launch.
- **Legal:** Terms and Privacy pages are clearly drafts. Verify the operator's legal details and obtain appropriate review before launch, especially for child/student information.
- **School public pages:** school slug and profile fields exist; public school page authoring/preview/publication and public API are not implemented.

## Verification performed

Repository inspection confirmed an empty starting directory and no existing Git checkout. Source changes were inspected after creation. No database service, Supabase credentials, Vercel account or DNS access were available; live workflows, SQL execution, security tests, provider sandboxes and deployment have not been verified. No production-completion claim is made.
