# Siyaq: price estimate for the work done so far

Estimate date: 2026-10-24. It covers the code on `master` as of commit `ccf2dd1`.

This is an estimate of what the work would cost to have built, priced as hours × an hourly rate. It is not a quote from a real vendor. The rates are typical ranges; check them against what you and the client agree on.

## What exists

A Flutter web app (Arabic, right-to-left) on Firebase: about 7,100 lines of app code, 1,800 lines of tests and 660 lines of documentation.

| Part | What it does | Hours |
|---|---|---|
| Landing page | Responsive marketing page, curriculum by stage, WhatsApp contact | 16–24 |
| Accounts and sign-in | Email sign-up for students, parents and tutors, with role-based home screens | 16–24 |
| Routing | Real URLs (`go_router`) and a sign-in gate | 8–12 |
| Student dashboard | Next-class card with a timed "join" button, schedule by day, progress, parent link code | 24–32 |
| Trial booking | Pick a subject, day and time slot | 12–16 |
| Parent dashboard | Link a child, follow their sessions and reports | 16–24 |
| Tutor dashboard | Accept requests safely (no double booking), Meet links, session status, progress reports | 24–32 |
| Tutor applications | Application form, plus admin approve/reject with a reason | 16–24 |
| Admin dashboard | Users, sessions, assigning tutors, suspending tutors | 20–28 |
| Tutor directory and ratings | Browse by year and subject, ranked tutors, 1–5 session ratings | 24–32 |
| Database and security | Firestore data model, security rules, 95 automated rules tests | 24–36 |
| App tests | 70 automated Flutter tests | 12–20 |
| Setup and docs | Firebase setup, deploy workflows, schema and go-live docs | 8–12 |
| **Subtotal** | | **220–316** |
| Planning, design, revisions (+15%) | | 33–47 |
| **Total** | | **≈ 250–365 hours** |

## Price

| Who builds it | Typical rate | Price for the work so far |
|---|---|---|
| Student or junior freelancer (Egypt) | $8–15 / hour | **$2,000–5,500** |
| Mid-level freelancer | $20–35 / hour | **$5,000–12,800** |
| Software agency | $40–70 / hour | **$10,000–25,500** |

To quote in EGP, multiply by the current USD→EGP rate.

**Price for the work so far: about $3,500–6,000.** That is the junior-to-mid range for ~300 hours.
