# Siyaq database schema

Cloud Firestore project `siyaq-dc1a6`. Four collections. Authentication is Firebase Auth (email and password); the Auth `uid` is the document id of the user's profile.

This document describes what the app writes and what `firestore.rules` enforces. If the two ever disagree, the rules win. Rules are tested in `firestore-tests/`.

## Overview

```
Firebase Auth (uid)
      │ same id
      ▼
users/{uid} ──────────────────────────────┐
   role: student | parent | tutor | admin │
   parent.childIds[] ─────► users/{studentUid}
                                          │
sessions/{autoId}                         │
   studentId ─────────────────────────────┤ references users
   tutorId   ─────────────────────────────┤ ("TBD" until accepted)
                                          │
progress_reports/{autoId}                 │
   studentId ─────────────────────────────┤
   tutorId   ─────────────────────────────┘

tutor_applications/{tutorUid}   (same id as the tutor's users doc)
```

All references are plain string ids. Firestore does not enforce them, so the rules and app code check what matters.

Conventions:
- **Dates** are ISO-8601 strings in the device's local time with no zone (for example `2030-01-10T16:00:00.000`). They sort correctly as text. They are not Firestore Timestamps.
- **Enums** are stored as their lowercase name.
- **Optional fields** are either absent or `null`, as noted per field.
- **Ids** for sessions and reports are Firestore auto-ids.

---

## `users/{uid}`

One document per account. Created by the app at sign-up.

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | 1–100 characters. |
| `email` | string | yes | Stored lowercase, up to 254 characters. |
| `role` | string | yes | `student`, `parent` or `tutor`. `admin` is never created by the app. |
| `childIds` | string[] | parents only | Student uids this parent has linked. Starts as `[]`, at most 30. Absent for other roles. |
| `approved` | bool | tutors only | `false` at sign-up. An admin sets it `true`. Absent for other roles. |

Behaviour that is not obvious from the fields:
- A tutor profile with no `approved` field is treated as not approved.
- A student's **link code** is their `uid`. A parent enters it to add the student to `childIds`.
- `admin` accounts are created by hand in the Firebase console by setting `role: "admin"` on a profile.

Example (tutor, awaiting approval):

```json
{ "name": "منى أحمد", "email": "mona@example.com", "role": "tutor", "approved": false }
```

Example (parent with one child):

```json
{ "name": "خالد", "email": "khaled@example.com", "role": "parent", "childIds": ["Zk3...studentUid"] }
```

### Who can do what

| Action | Allowed for |
|---|---|
| Create | The signed-in user, for their own uid, with the shape above. Tutors must start with `approved: false`. |
| Read one profile | The owner. An admin. An approved tutor or a parent, but only if the target is a student. |
| List all profiles | Admin only. |
| Update | The owner may change `name`, and a parent may add one student to `childIds` per write (the target must exist and be a student). An admin may change only `approved`, and only on a tutor. |
| Delete | Nobody. |

---

## `sessions/{sessionId}`

One document per booked class, including trials.

| Field | Type | Required | Notes |
|---|---|---|---|
| `studentId` | string | yes | `users` uid of the student. |
| `tutorId` | string | yes | `users` uid of the tutor, or the literal `"TBD"` while unassigned. |
| `subject` | string | yes | Up to 100 characters. Free text, but the app offers the curriculum subject names. |
| `scheduledAt` | string | yes | Start time, ISO-8601 local string, up to 40 characters. |
| `isTrial` | bool | yes | `true` for free trial bookings. The booking screen currently always sets `true`. |
| `status` | string | yes | `pending`, `confirmed`, `completed` or `cancelled`. |
| `googleMeetLink` | string or null | no | `https://…`, up to 300 characters. Added by the tutor. |

Example (just booked):

```json
{
  "studentId": "Zk3...",
  "tutorId": "TBD",
  "subject": "الرياضيات",
  "scheduledAt": "2030-01-11T16:00:00.000",
  "isTrial": true,
  "status": "pending",
  "googleMeetLink": null
}
```

### Lifecycle

```
            student/parent creates
                    │
        tutorId = "TBD", status = pending
                    │
      ┌─────────────┴──────────────┐
      │ tutor accepts              │ admin assigns an approved tutor
      │ (transaction)              │
      └─────────────┬──────────────┘
                    ▼
   tutorId = <tutor uid>, status = confirmed
                    │
      tutor marks done        tutor cancels
                    ▼                ▼
               completed         cancelled
```

Allowed transitions made by the assigned tutor:
- `pending` → `confirmed` or `cancelled`
- `confirmed` → `completed` or `cancelled`
- `completed` and `cancelled` are final.

Accepting an unassigned booking is a Firestore transaction, so two tutors cannot both claim it. An admin can only assign a tutor who is approved, and only while the booking is `pending` and `TBD`.

### Who can do what

| Action | Allowed for |
|---|---|
| Create | A student for themselves, or a parent for a linked child. Must be `tutorId: "TBD"`, `status: "pending"`, with no Meet link. |
| Read | The student. A parent of that student. The assigned approved tutor. Any approved tutor, for sessions still `TBD`. An admin. |
| Update | An approved tutor (accept, change status, set link), or an admin (assign). Students and parents cannot edit. |
| Delete | Nobody. |

---

## `progress_reports/{reportId}`

A tutor's note about a student after a class. Write-once.

| Field | Type | Required | Notes |
|---|---|---|---|
| `studentId` | string | yes | `users` uid of the student. |
| `tutorId` | string | yes | Must equal the author's uid. |
| `subject` | string | yes | 1–100 characters. |
| `score` | number | yes | 0 to 100. |
| `tutorNotes` | string | yes | Up to 2000 characters. May be empty. |
| `date` | string | yes | ISO-8601 local string, set when the report is written. |

Example:

```json
{
  "studentId": "Zk3...",
  "tutorId": "T9q...",
  "subject": "الرياضيات",
  "score": 80,
  "tutorNotes": "أداء جيد في الجبر، يحتاج مراجعة الهندسة.",
  "date": "2030-01-12T18:05:00.000"
}
```

### Who can do what

| Action | Allowed for |
|---|---|
| Create | An approved tutor, with `tutorId` equal to their own uid. |
| Read | The student. A parent of that student. The tutor who wrote it. An admin. |
| Update, delete | Nobody. |

---

## `tutor_applications/{tutorUid}`

What a tutor submits before an admin approves them. The document id is the tutor's uid, so each tutor has at most one. An unapproved tutor sees this form instead of the tutor dashboard.

| Field | Type | Required | Notes |
|---|---|---|---|
| `phone` | string | yes | Digits, optional leading `+` and spaces, 8–20 characters. |
| `qualification` | string | yes | 2–200 characters. |
| `experienceYears` | int | yes | 0–50. |
| `subjects` | string[] | yes | 1–10 items, each one of the curriculum subject names. |
| `stages` | string[] | yes | 1–3 items from `primary`, `prep`, `secondary`. |
| `bio` | string | yes | 20–1000 characters. |
| `availability` | string | yes | 1–300 characters, free text. |
| `status` | string | yes | `submitted`, `approved` or `rejected`. |
| `submittedAt` | string | yes | ISO-8601 local string. |
| `reviewNote` | string | rejected only | The admin's reason, 3–500 characters. The tutor sees it. |
| `reviewedAt` | string | after a decision | ISO-8601 local string. |

The subject names are listed inside `firestore.rules` as well as in `lib/data/curriculum.dart`. A Flutter test (`test/tutor_application_test.dart`) fails if the two drift apart, so renaming a subject means updating both.

### Lifecycle

```
 (none) ──submit──► submitted ──admin approves──► approved
                        │                            │
                        └──admin rejects + reason──► rejected
                                                     │
                       ◄────── tutor edits and resubmits
```

- **Approving** writes the application and sets `users/{uid}.approved = true` in one batch.
- **Resubmitting** rewrites the whole document, so the old `reviewNote` and `reviewedAt` disappear.
- **Suspending** an approved tutor only changes `users/{uid}.approved`. The application stays `approved`, which is how the admin screen tells a suspended tutor from a new applicant.
- A tutor who registered before this feature has no application. They see the form on their next login and the admin sees "لم يقدّم طلباً".

### Who can do what

| Action | Allowed for |
|---|---|
| Create | The tutor, for their own uid, only while not approved, in the exact shape above with `status: "submitted"` and no review fields. |
| Read | The tutor who owns it. An admin. |
| List all | Admin only. |
| Update | An admin, only on a `submitted` application: set `status` to `approved` or `rejected` (rejection needs a reason) and `reviewedAt`. The owner, only on a `rejected` application, by resubmitting a valid replacement. |
| Delete | Nobody. |

---

## Queries and indexes

Every query the app runs, and the index it needs.

| Screen | Query | Index |
|---|---|---|
| Student, parent | `sessions` where `studentId == X`, ordered by `scheduledAt` | Composite: `studentId` ↑, `scheduledAt` ↑ |
| Tutor | `sessions` where `tutorId == uid`, ordered by `scheduledAt` | Composite: `tutorId` ↑, `scheduledAt` ↑ |
| Tutor (new requests) | `sessions` where `tutorId == "TBD"` (filtered to pending and sorted in the app) | None |
| Student, parent | `progress_reports` where `studentId == X` (sorted in the app) | None |
| Admin | `users` (all), `sessions` (all), `tutor_applications` (all) | None |
| Tutor (before approval) | `tutor_applications/{uid}` single read and live listener | None |
| Any signed-in user | `users/{uid}` single reads and live listeners | None |

The two composite indexes are in `firestore.indexes.json`. Deploy them with the rules:

```bash
firebase deploy --only firestore --project siyaq-dc1a6
```

Why queries look the way they do:
- Names are read as separate single-document reads, not one `whereIn` query, because the rules authorise profiles one at a time.
- The unassigned-requests and report queries are sorted in the app to avoid extra indexes.

---

## Relationships and integrity

| Relationship | Stored as | Enforced by |
|---|---|---|
| Parent → students | `users/{parent}.childIds` | Rules check each added id is a real student. Nothing removes a link. |
| Session → student | `sessions.studentId` | Rules: the booker must be that student or their linked parent. |
| Session → tutor | `sessions.tutorId` | Rules: only an approved tutor or an admin can set it. |
| Report → student, tutor | `studentId`, `tutorId` | Rules check `tutorId` is the author. They do **not** check the tutor has had a session with that student. |

Nothing is ever deleted through the app, so there are no dangling-reference cleanups to run.

## Known limitations

- **Dates are strings with no timezone.** Fine while everyone is in one zone. Moving to Firestore `Timestamp` would fix zones and let the rules reject past dates; it needs a migration.
- **Tutor names are not visible to students or parents.** Profiles are only readable by their owner, admins, and (for students) approved tutors and parents. Showing a tutor's name would need a `tutorName` field copied onto the session when it is accepted.
- **No tutor availability data.** Booking slots are fixed hours; a tutor confirms or ignores them. The application records a free-text availability note, but nothing uses it.
- **Applications have no documents.** A tutor describes their qualification in text. Certificates and ID cannot be uploaded, so an admin approves on the tutor's word unless they verify outside the app. Uploads need Firebase Storage, which has no rules yet.
- **Application rejections are not notified.** The tutor sees the reason the next time they open the app. Nothing emails them.
- **Admins can approve a tutor from the profile alone.** The admin screen routes approvals through the application, but the rules still let an admin set `approved` directly (used for re-activating suspended tutors).
- **Student grade and parent phone are still not stored.**
- **No unlink and no delete.** A parent cannot be unlinked from a student, and profiles cannot be removed.
- **A report can name any student id** the tutor knows, because the rules cannot check for a shared session.
- **Subjects are free text** on sessions and reports. A rename in the curriculum would not update old documents.
- **Parent link code never expires** and cannot be regenerated.

## Changing the schema safely

1. Add the field to the model class in `lib/models/` (with a default for old documents).
2. Update the matching `validNew…` function and `hasOnly` key list in `firestore.rules`. Rules reject unknown fields, so a new field is refused until the rules allow it.
3. Add a case to `firestore-tests/rules.test.js`.
4. Run the rules tests, then deploy the rules before releasing the app version that writes the field.

```bash
firebase emulators:exec --only firestore --project siyaq-rules-test "npm --prefix firestore-tests test"
```
