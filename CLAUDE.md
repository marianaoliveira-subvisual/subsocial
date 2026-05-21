# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

SubSocial — Subvisual's internal social-media analytics dashboard. **No build system, no package manager, no tests.** Every page is a standalone `.html` file with inline `<style>` and `<script>`, served as static assets by Vercel.

## Commands

- **Local preview**: open the `.html` files directly in a browser, or run `python3 -m http.server` from the repo root. Supabase calls work fine from `file://` and `localhost`.
- **Deploy**: `vercel deploy --prod` (the repo switched from Netlify to Vercel CLI deploys — see commit `a6f1de8`). Root `/` is rewritten to `/dashboard.html` via `vercel.json`.
- **Database**: there is no migration tooling. Edit `schema.sql` and paste it into the Supabase SQL editor (URL is in the file header).

## Architecture

### Auth gate (top of every protected page)

Each protected page begins with a small inline IIFE that:

1. Creates `window._sb = supabase.createClient(<url>, <anon-key>)` — the Supabase project URL `bgdyahjipkxwosbbkkqd` and anon key are **hardcoded into every page**. This is intentional (anon key + RLS), not a leak.
2. Hides `<html>` (`visibility:hidden`) until session is resolved, to prevent a flash of unauthenticated content.
3. Calls `_sb.auth.getSession()`. If no session → `window.location.replace('supabase-auth.html')`. Otherwise → restores visibility and invokes `window._onAuthReady(session)`.

Each page defines its own `_onAuthReady` to do its initial data load. When adding a new protected page, copy this IIFE verbatim from `dashboard.html` or `settings.html` — there is no shared `<script src="...">` to import.

`signup.html`, `supabase-auth.html`, and `reset-password.html` are the only unauthenticated pages. They create their own `_sb` client (not on `window`).

### Data model (Supabase, 3 tables, RLS-protected)

```
platforms (id, slug, label, color)              -- seeded, read by anon
reports   (id, platform_id, period_start,       -- authenticated read/insert
           period_end, source, notes, created_at)
metrics   (id, report_id, key, value)           -- authenticated read/insert
```

`metrics` is a flexible **key/value store** — there is no per-platform column schema in the database. The "shape" of a platform's metrics lives only in client code (see below).

### Platform config lives in TWO places — keep them in sync

- `dashboard.html` → `const PLATFORMS = [...]` (~line 1328): the 6 platforms shown on the overview (linkedin, twitter, bluesky, youtube, dribbble, website). Defines which metric `key` to read for each KPI (reach/eng/followers/clicks).
- `upload.html` → `const PLATFORM_META = {...}` (~line 454): the **9** platforms supported by the upload flow — the 6 above plus `linkedin-ads`, `twitter-ads`, `google-ads`. Defines the manual-entry field list and the page each platform links to.

**Gotcha**: `schema.sql` only seeds the 6 organic platforms. The 3 ads platforms (`linkedin-ads`, `twitter-ads`, `google-ads`) must be inserted into the `platforms` table manually before uploads for them will succeed — `upload.html` looks up `platform_id` by `slug` and fails if missing.

### Upload flow (`upload.html`)

User picks a platform → uploads CSV/XLSX or enters fields manually → saves to Supabase as:
1. Insert one row into `reports` (with `source` = file extension if uploaded, else `'manual'`).
2. Insert one row per metric into `metrics` (`{report_id, key, value}`).

XLSX/CSV parsing happens client-side (`mapXlsxRows`). Time-series CSVs are summed across daily rows for the period total (see commit `70b875a`).

### UI conventions

- **Sidebar nav is duplicated in every page** — no template engine. When adding/renaming a sidebar item, update all `*.html` files.
- **User pill in sidebar**: `_updateSidebarUser(session)` sets the avatar initial and shows the email. The Admin badge is hard-coded to display **only** for `mariana.oliveira@subvisual.co` — everyone else is shown as "Team member".
- **Theme**: light/dark via `[data-theme]` attribute on `<html>`. Persisted in `localStorage` under `sb-theme`. Every page has a tiny inline script at the top of `<head>` that applies the saved theme before paint to avoid a flash.
- **Default time range**: persisted in `localStorage` under `sb-default-period` (`'7'` | `'30'` | `'90'`). Platform pages read it in `_onAuthReady` and pass to `setRange()`.
- **Design tokens**: `--blue #045CFC`, `--indigo #2421AB`, plus per-platform colors that match the `platforms.color` column. Fonts are Google Fonts (DM Sans + Playfair Display) loaded via `@import` in each page's `<style>`.

## Conventions

- **Don't introduce a build step or framework** unless explicitly asked. The whole point of this codebase is "edit the HTML, deploy".
- **Don't extract shared JS into modules** for the same reason — duplication across pages is the chosen tradeoff for zero tooling.
- **Gitignored one-shot scripts**: `patch-*.js`, `build-pages.js`, `wire-platforms.js`, `patch-clean.js` are throwaway scripts for cross-page edits (see `.gitignore`). If you need to bulk-edit all pages, write one of these locally, run it, then leave it uncommitted.
