# Help & Support — Be Electric CMMS Apps

Welcome to support for **Be Electric Requestor** and **Be Electric Tech**.

These apps help organizations manage **EV charger maintenance**. Accounts are created by your **organization administrator** — you cannot self-register in the app.

---

## Getting help

### Before you contact us

1. Confirm you are using the **correct app** for your role:
   - **Requestor** → Be Electric Requestor
   - **Technician, manager, or admin** → Be Electric Tech
2. Confirm your organization has **provisioned your account** and linked you to a company (requestors need a valid `companyId` to submit requests).
3. Check that you have a **stable internet connection** (the apps require network access to Supabase backend services).

### Contact support

| Channel | Details |
|---------|---------|
| **Email** | **support@be-maintain.com** |
| **Support page** | **https://www.be-maintain.com/support** (this page) |
| **In-app** | Login screen → **Contact support** · Profile → **Help & support** |

When emailing support, include:

- Your **full name** and **account email**
- Which app you use (Requestor or Tech)
- Your **organization / company name** (if known)
- A clear description of the issue and steps to reproduce
- Screenshots if applicable

---

## Common issues

### “I don’t have an account” / “Invalid login”

- Accounts are **created by your organization’s administrator**, not through the app store download.
- Contact your **internal IT or Be Electric account administrator** to request access.
- If your organization confirms you should have access, email **support@be-maintain.com** with your work email address.

### “Wrong app for my role”

- The **Requestor** app accepts only users with the **requestor** role.
- The **Tech** app accepts **technician**, **manager**, and **admin** roles — not requestors.
- If you see a “wrong app” message, install the correct app or ask your administrator to verify your role.

### “I can’t submit a maintenance request”

Common causes:

- Your account is not linked to a **company** with registered charger assets
- No **Siemens** or **Kostad** charger assets are available for your company
- Required fields (problem description, asset selection) are incomplete
- Network connectivity issues

Try again on a stable connection. If the problem persists, contact support with the charger/site you selected and any error message shown.

### Password reset

1. On the login screen, tap **Forgot password?**
2. Enter your account email
3. Open the **reset link in your email** (password reset completes in the browser, not inside the app)

If you do not receive the email, check spam/junk folders and confirm your organization uses the correct email address for your account. Your administrator may need to verify Supabase email delivery settings.

**Manual confirmation required:** custom SMTP and Site URL configuration for production Supabase Auth.

### Notifications

This version of the apps **does not use remote push notifications**, SMS, or email alerts. You may see an **in-app notification list**; an empty list is normal until there is activity on your requests or assigned work.

Do not expect lock-screen push alerts from the app in the current release.

### Work order status not updating

The apps use **realtime sync** for work order updates. If status appears stale:

- Pull to refresh or navigate away and back
- Confirm internet connectivity
- Wait a few moments and retry

If updates never appear, contact support with your ticket number.

---

## Login problems

| Symptom | What to try |
|---------|-------------|
| “Invalid email or password” | Verify credentials; use Forgot password? |
| Login succeeds but immediately logs out | Your account may be missing from the organization user database — contact your administrator |
| App shows configuration error on launch (release build) | Production build misconfiguration — **Manual confirmation required:** contact your IT team or Be Electric deployment contact |
| Rate limiting / slow retry | The app enforces a short client-side cooldown between login attempts — wait a few seconds and try again |

---

## Maintenance request issues

- **Photos optional:** You can submit without a photo; attach one only if it helps describe the issue.
- **Supported manufacturers:** Requestor flows are built around **Siemens** and **Kostad** charger assets registered to your company.
- **Contact fields:** You may enter name, optional phone, and email on the request — use details your organization authorizes for maintenance follow-up.

---

## Photo upload issues

The app requests permission to use your **camera** and **photo library** only when you choose to attach an image.

| Issue | Suggestion |
|-------|------------|
| Permission denied | Open iOS Settings → Be Electric → enable Camera / Photos |
| Upload fails | Check network; try a smaller image; retry |
| Upload hangs | Close and reopen the app; ensure you remain signed in |

Default upload size configuration allows up to **10 MB** per file (`MAX_UPLOAD_SIZE_MB`); production config also references a **5 MB** image guideline. Very large images may fail on slow networks.

**Manual confirmation required:** exact server-side file size limits in Supabase Storage policies.

---

## Account deletion

To request deletion of your account and associated personal data:

**Profile → Request account deletion** (opens a pre-filled email), or email **support@be-maintain.com** directly.

See our dedicated page: **[Account Deletion](https://www.be-maintain.com/account-deletion)**

Your employer may also remove your account through their administrator.

---

## Privacy and legal

- [Privacy Policy](https://www.be-maintain.com/privacy)
- [Terms of Service](https://www.be-maintain.com/terms)
- [Terms of Service](https://www.be-maintain.com/terms)

---

## Expected response time

We aim to respond to support requests within **2 business days**.

Urgent **safety or operational emergencies** at a charging site should follow your organization’s **on-call or escalation procedures** first; the app is for maintenance workflow tracking, not emergency dispatch.

**Manual confirmation required:** official support hours, phone number, and SLA for your organization or region.

---

## Contact

**Email:** **support@be-maintain.com**  
**Web:** **https://www.be-maintain.com/support**

**Be Electric** — EV charger maintenance management
