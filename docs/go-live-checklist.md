# Siyaq go-live checklist

Work top to bottom. Each item says how to tell it is done. Commands run from the project folder (`C:\Users\LENOVO\siyaq`).

Firebase project: `siyaq-dc1a6`. Web launch first; the phone apps are in section 10 and can wait.

**Status when this was written:** nothing in sections 1–4 or 7–9 had been done against the live project. The app and the security rules had only been tested locally (Flutter widget tests and the Firestore emulator).

---

## 0. Decide first

Settle these before spending time on the rest, because they change what you build.

- [ ] **Web only, or web plus phone apps?** Web-only is much less work. iOS also needs a Mac and a paid Apple developer account.
- [ ] **Where does the site live?** Vercel (your reference site is on Vercel) or Firebase Hosting. Section 7 covers both.
- [ ] **Which known gaps can wait for version 1?** Tick the ones you accept:
  - [ ] No email or push notifications. Tutors and parents learn about requests only by opening the app.
  - [ ] Tutors apply with typed text only. No certificate upload, so an admin approves on the tutor's word unless they check outside the app.
  - [ ] Students and parents can't see the tutor's name.
  - [ ] No payments.
  - [ ] No way to unlink a parent from a student.
  - [ ] Class times have no time zone (fine if everyone is in one zone).
  - [ ] Booking slots are fixed hours and don't reflect real tutor availability.

---

## 1. Accounts and access

- [ ] You can open `siyaq-dc1a6` in the [Firebase console](https://console.firebase.google.com) with the Google account you'll use for launch.
- [ ] The Firebase command line is signed in as that account. When this was written it was signed in as `jeromaged2018@gmail.com`, not `omarjeromecoding@gmail.com`.

  ```bash
  firebase login:list
  firebase login --reauth
  firebase projects:list
  ```

  Done when `siyaq-dc1a6` appears in the project list.
- [ ] Link the folder to the project. This creates `.firebaserc`, which doesn't exist yet.

  ```bash
  firebase use siyaq-dc1a6
  ```
- [ ] More than one person has owner access to the project, so you aren't locked out if one account is lost.

---

## 2. Firebase console setup

### Firestore database
- [ ] **Firestore Database → Create database.** Choose **production mode** and a region close to your users. The region can't be changed later.
- [ ] If a database already exists, open **Rules** and check what is there. Test-mode rules (`allow read, write: if true` or a date cutoff) leave everything open until section 3 replaces them.

### Authentication
- [ ] **Authentication → Sign-in method → enable Email/Password.**
- [ ] **Authentication → Settings → Authorized domains:** add the domain the site will run on (for example `siyaq-liard.vercel.app` or your own). `localhost` is there by default. Done when sign-in works on the deployed site, not just locally.
- [ ] **Authentication → Templates:** set the language of the password-reset email to Arabic and review the wording. Test it once in section 8.
- [ ] Decide whether to require email verification. The app doesn't check it today.

### API key
- [ ] In [Google Cloud console](https://console.cloud.google.com) → **APIs & Services → Credentials**, open the browser API key for this project and restrict it:
  - **Application restrictions:** websites, listing your launch domain and `localhost`.
  - **API restrictions:** leave the Firebase-related APIs (Identity Toolkit, Token Service, Cloud Firestore) enabled.

  The key is public by design, so this limits abuse by other sites. Test sign-in again afterwards.

### Optional but recommended
- [ ] **App Check** for the web app, to block requests that don't come from your site. Set it to monitor first, then enforce once you've confirmed real traffic passes.
- [ ] A **budget alert** if you move to the paid Blaze plan.

---

## 3. Deploy the security rules and indexes

The rules (`firestore.rules`) and indexes (`firestore.indexes.json`) are in the project but are **not deployed** until you do this.

- [ ] Run the local tests first. All of them should pass before anything is deployed.

  ```bash
  firebase emulators:exec --only firestore --project siyaq-rules-test "npm --prefix firestore-tests test"
  ```

  Done when the summary shows 67 passing, 0 failing.
- [ ] Deploy.

  ```bash
  firebase deploy --only firestore --project siyaq-dc1a6
  ```
- [ ] Check in the console. **Firestore → Rules** shows today's date and the new text. **Firestore → Indexes** lists two `sessions` indexes and both reach "Enabled" (building takes a few minutes).
- [ ] The rules include `tutor_applications`. If the Rules tab doesn't mention it, the deploy didn't take effect.
- [ ] Re-deploy the rules any time `firestore.rules` changes, **before** releasing an app version that depends on the change.

---

## 4. Create the first admin

The app can't create admins. Do this once.

- [ ] Open the live site and **sign up as a student** using the email you want for the admin account.
- [ ] In the console: **Firestore → `users` → the document with that uid.** Change the field `role` from `student` to `admin`.
- [ ] Sign out and sign in again. Done when you land on the admin dashboard.
- [ ] Use a strong, unique password. Admins can see every user and session.

Any tutors who registered before the application feature have no application. They'll see the form on their next login.

---

## 5. Content and branding to replace

These are in the code today and would embarrass you on launch day.

- [ ] **WhatsApp number.** `whatsappNumber` in `lib/data/curriculum.dart` is a placeholder (`201000000000`). Every "book via WhatsApp" and "support" button uses it. Use the international format with no `+`.
- [ ] **Landing page links that go nowhere:** "انضمام كمعلم" (join as a tutor), "الشروط والضمان" (terms), "سياسة الخصوصية" (privacy). "Join as a tutor" should open sign-up with the tutor role selected.
- [ ] **Copyright line** still says ٢٠٢٥.
- [ ] **Claims you show:** "4.9/5 parent rating" and "100% vetted tutors". Keep them only if they're true for your platform.
- [ ] **Subjects and grades.** The curriculum list was partly written from one page of the reference site. Check it matches what you actually teach.
- [ ] **Web page metadata** in `web/index.html` and `web/manifest.json` are Flutter defaults:
  - [ ] `<title>` is `siyaq` → "سياق | Siyaq".
  - [ ] Description is "A new Flutter project." → a real one, in Arabic.
  - [ ] Add `lang="ar" dir="rtl"` to the `<html>` tag.
  - [ ] Manifest `name`, `short_name` and the blue `theme_color` / `background_color` are defaults.
  - [ ] Check `web/icons/` and `web/favicon.png`. Replace them if they are still the Flutter logo.
  - [ ] Add social-preview (Open Graph) tags if you'll share the link in chats.
- [ ] **Fonts.** The Cairo font is fetched from Google at runtime. Decide whether that's acceptable for privacy and slow connections, or bundle the font file.

---

## 6. Quality gates

All must pass on the exact code you're releasing.

- [ ] Static analysis is clean. (Two harmless `const` hints in the landing page are expected.)

  ```bash
  flutter analyze
  ```
- [ ] App tests pass (35 at the time of writing).

  ```bash
  flutter test
  ```
- [ ] Rules tests pass (section 3).
- [ ] **Unused packages.** `googleapis`, `googleapis_auth`, `table_calendar`, `go_router` and `firebase_storage` aren't used by any screen. Remove the ones you won't use soon to keep the web build lean. Keep `firebase_storage` if you plan certificate uploads.

  ```bash
  flutter pub remove googleapis googleapis_auth table_calendar go_router
  ```
- [ ] The project is under version control and the commit you release is tagged. A `.git` folder exists; commit your work.
- [ ] `lib/firebase_options.dart` points at `siyaq-dc1a6` (it does today).

---

## 7. Build and host the web app

- [ ] Build.

  ```bash
  flutter build web --release
  ```
- [ ] Preview the build locally before uploading, then sign in with a test account.

  ```bash
  python -m http.server 4000 --directory build/web
  ```

  Open `http://localhost:4000`. If port 4000 is taken, pick another that Windows hasn't reserved.
- [ ] Deploy with **one** of these:
  - **Vercel:** upload the `build/web` folder as a static site.

    ```bash
    npx vercel deploy build/web --prod
    ```
  - **Firebase Hosting:** add a `hosting` section to `firebase.json` with `"public": "build/web"`, then:

    ```bash
    firebase deploy --only hosting --project siyaq-dc1a6
    ```
- [ ] The app navigates without changing the address, so there are no deep links to break and no special rewrite rules are needed. A refresh returns to the landing page or your dashboard.
- [ ] Custom domain is attached, HTTPS works, and the domain is in Firebase's authorized domains (section 2).
- [ ] The deployed site is the **release** build, not a debug build. The first load should not show a "debug" banner.

---

## 8. Smoke test on the live site

Use fresh test accounts, ideally in a private window, and note anything that fails. Open the browser console while you test: a Firestore error that mentions an index or "permission-denied" points straight at the cause.

| # | As | Do | Expect |
|---|---|---|---|
| 1 | Signed out | Open the site, browse stages, grades and subjects, press the WhatsApp button | Landing page works; WhatsApp opens your real number with the subject in the message |
| 2 | New student | Sign up | Student dashboard with a link code and an empty schedule |
| 3 | Student | Book a trial: subject, day, time | Confirmation screen; the class shows as "بانتظار تعيين معلم" |
| 4 | New parent | Sign up, enter the student's link code | Child appears; the parent sees the pending class; booking for the child works |
| 5 | New tutor | Sign up, fill the application, send it | "قيد المراجعة"; the tutor cannot reach the dashboard |
| 6 | Admin | Open the application, **reject** with a reason | Tutor sees the reason, the form is pre-filled, and they can resubmit |
| 7 | Admin | **Approve** the resubmitted application | Tutor's dashboard opens without signing in again |
| 8 | Tutor | Accept the student's request with a Meet link | Student dashboard shows "مؤكدة" and the countdown |
| 9 | Student | At about 15 minutes before the class | Join button unlocks. To test without waiting, edit the session's `scheduledAt` in the console to a time a few minutes ahead |
| 10 | Tutor | Mark the class complete and write a report | Student and parent both see the score and note |
| 11 | Admin | Book another trial as a student, then assign a tutor from the admin sessions list | Class becomes confirmed with that tutor |
| 12 | Any | Use "forgot password" | Reset email arrives in Arabic and the link works |
| 13 | Any | Phone-sized window, and a throttled slow connection | Layout holds; loading states show; nothing overflows |
| 14 | Any | Sign out, close the tab, come back | Session persists or signs in cleanly |

- [ ] All 14 rows pass.
- [ ] **Clean up.** Delete the test users and their data (console → Authentication and Firestore). Keep the admin. Do this **before** announcing.

---

## 9. Privacy, legal and safety

The platform stores children's names and learning records, and tutors' phone numbers and qualifications. Check what applies to you in your country.

- [ ] A **privacy policy** page explaining what you collect, why, who can see it, and how long you keep it. Link it from the footer and sign-up.
- [ ] **Terms of use**, including the free-trial and cancellation rules and what the "guarantee" covers.
- [ ] A **way to delete an account and its data on request**. The app has none; the console is the only route today, so write down who does it and how.
- [ ] A **parental consent** approach for under-age students, if your rules require one.
- [ ] A contact channel for safety concerns (the WhatsApp support number is fine if staffed).
- [ ] Decide who reviews tutor applications, what you check (ID, certificates, references) and where you keep what you checked, since the app only stores typed answers.
- [ ] Firebase **backups.** Scheduled Firestore backups and point-in-time recovery require the paid plan. If you stay on the free plan, schedule a periodic manual export and keep it somewhere safe.

---

## 10. Android and iOS apps (skip if web-only)

**Android**
- [ ] Release signing. `android/app/build.gradle` signs release builds with the **debug** key. Create an upload keystore, keep it and its passwords somewhere safe (losing it blocks updates), and configure it.
- [ ] Application id is `com.siyaq.siyaq`. Confirm you want it permanent, because it can't change after publishing.
- [ ] Bump `version` in `pubspec.yaml` (`1.0.0+1`) for every store upload.
- [ ] App icon, store listing, screenshots, content rating, and the Play **Data safety** form. It needs your privacy policy URL.
- [ ] Build and test the bundle on a real phone.

  ```bash
  flutter build appbundle --release
  ```

**iOS**
- [ ] Needs a Mac, Xcode and a paid Apple developer account. Bundle id is `com.siyaq.siyaq`.
- [ ] Sign in with Apple is **not** required for email/password sign-in, but App Store review will ask for a demo account and a privacy policy.

---

## 11. Launch day

- [ ] Do sections 3, 4 and 7 in that order on the same day, then run section 8 on the live site.
- [ ] Watch **Authentication → Users**, and **Firestore → Usage**, for the first hours.
- [ ] Be ready to review tutor applications quickly. Until you approve them, tutors can't take any requests, and unassigned bookings will sit.
- [ ] Have a plan for new booking requests that no tutor accepts (the admin sessions list has a "needs a tutor" filter).
- [ ] Announce only after cleanup in section 8.

---

## 12. Rollback

- [ ] **Site:** keep the previous deployment available. On Vercel you can promote an earlier deployment; on Firebase Hosting you can roll back from the Hosting page.
- [ ] **Rules:** Firestore → Rules keeps a history. Save a copy of the previous rules file before each deploy so you can redeploy it.
- [ ] **Data:** nothing in the app deletes documents, so a bad release can't erase data through the app. A bad *rules* deploy can lock users out, which is why section 3 tests them first.
- [ ] Write down who can do each of the above, and how to reach them.

---

## After launch

- [ ] Add Crashlytics or another error reporting service, since no error reporting is wired in.
- [ ] Add notifications (tutor: new request; student: class confirmed; tutor: application decision). This needs Cloud Functions and the paid plan.
- [ ] Add certificate uploads for tutor applications (Firebase Storage rules and tests).
- [ ] Copy the tutor's name onto the session when it's accepted so students and parents can see it.
- [ ] Move class times to Firestore timestamps and handle time zones.
- [ ] Tutor-set availability instead of fixed hourly slots.
