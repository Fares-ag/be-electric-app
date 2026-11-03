# App Store Review — paste into App Store Connect

Copy the sections below into **App Review Information** when submitting **Be Electric Requestor**.

**Before submission:** replace every `<!-- MUST REPLACE BEFORE SUBMISSION -->` block with real reviewer credentials. Do not upload with placeholder values.

---

## Demo account (required)

| Field | Value |
|-------|--------|
| Username | <!-- MUST REPLACE BEFORE SUBMISSION: reviewer email, e.g. reviewer@yourcompany.com --> |
| Password | <!-- MUST REPLACE BEFORE SUBMISSION: reviewer password --> |

**Pre-submission checklist for this account:**

- [ ] Role is `requestor` in Supabase `users` table
- [ ] User is linked to a **company** with `companyId`
- [ ] Company has at least one **Siemens** and one **Kostad** charger asset (manufacturer set correctly)
- [ ] Company has scheduled PM occurrences visible to this requestor (if testing Preventive Maintenance)
- [ ] Login tested on a physical iPhone with the **release IPA** (not debug)
- [ ] Demo credentials above are filled in App Store Connect (not HTML comments)

---

## How to test the app

### Requestor login

1. Open the app and wait for the splash screen (~3 seconds).
2. Log in with the demo credentials above.
3. The login screen footer states: **“Accounts are created by your organization administrator.”** Privacy Policy and Terms of Service links are available on the login screen.

### Maintenance requests

4. On the home screen, tap **Siemens** or **Kostad** to start a maintenance request.
5. Select a charger, describe the issue, optionally attach a photo, and submit.
6. Tap **More (⋯)** → **View My Requests** to see submitted requests and status.

### Preventive Maintenance (read-only + Confirm)

7. Tap **More (⋯)** → **Preventive Maintenance** to open the PM dashboard.
8. Verify overview counts, then open **Upcoming** (or **Overdue**).
9. On an open PM task, tap **Confirm** on the list card or on the detail screen to acknowledge upcoming maintenance before work begins.
10. After confirming, the task shows a **Confirmed** label.
11. Open **History** to view completed or cancelled PM tasks.
12. Requestors **cannot** complete PM tasks — there is **no Complete button** on requestor PM detail screens.

### Profile, legal, and account deletion

13. Tap **Profile** (via **More (⋯)**) for account info.
14. Open **Privacy Policy**, **Terms of Service**, and **Help & support** — each opens in the system browser.
15. Tap **Request account deletion** to start a pre-filled email to support.

---

## B2B / account creation

This is a **B2B app** for Be Electric clients. Users **cannot self-register**. Accounts are created by the customer’s administrator. The login screen states: “Accounts are created by your organization administrator.”

---

## Password reset

“Forgot password?” sends a reset email via Supabase. The user completes password reset by opening the **link in the email** (web page), not inside the app.

Ensure Supabase **custom SMTP** and **Site URL** are configured before submission so reviewers receive the email.

---

## Push / SMS / email notifications

This version does **not** use remote push notifications, SMS, or email alerts. In-app notification list is available; empty state is normal until request status changes.

Do **not** mention push notifications in App Store description or screenshots.

---

## Account deletion (Guideline 5.1.1(v))

Users can start account deletion from **Profile → Request account deletion**, which opens a pre-filled email to support. Employers may also remove accounts via their administrator.

---

## App Privacy (App Store Connect questionnaire)

Declare (linked to user, not used for tracking):

- **Contact Info:** Email, name, phone (optional on request form)
- **User Content:** Photos attached to maintenance requests, problem descriptions
- **Identifiers:** User ID for authentication and work order association

**Tracking:** No  
**App Tracking Transparency:** Not used

---

## Support & legal URLs

Use these URLs in **App Store Connect** (they match production `--dart-define` values):

| Purpose | URL |
|---------|-----|
| Privacy Policy | https://www.be-maintain.com/privacy |
| Terms of Service | https://www.be-maintain.com/terms |
| Support | https://www.be-maintain.com/support |
| Account deletion | https://www.be-maintain.com/account-deletion |
| Support email | support@be-maintain.com |

---

## Encryption

App uses standard HTTPS/TLS only. `ITSAppUsesNonExemptEncryption` is `false`.
