# Release Legal Checklist — Be Electric CMMS

Pre-release checklist for **Be Electric Requestor** (and **Be Electric Tech**) App Store / Play Store submission. Combines legal publishing, production configuration, website setup, and App Store compliance review.

**Last updated:** [INSERT DATE]

---

## Part A — Production configuration

### Required `--dart-define` values (release builds)

From `packages/cmms_core/lib/config/app_config.dart` and `scripts/defines.production.json.example`:

| Define | Required | Example placeholder | Used for |
|--------|----------|---------------------|----------|
| `SUPABASE_URL` | **Yes** | `https://YOUR_PROJECT_REF.supabase.co` | Backend |
| `SUPABASE_ANON_KEY` | **Yes** | *(from Supabase Dashboard)* | Backend auth |
| `PRIVACY_POLICY_URL` | **Yes** | `https://www.be-maintain.com/privacy` | Login, Profile, App Store Connect |
| `SUPPORT_URL` | **Yes** | `https://www.be-maintain.com/support` | Profile, App Store Connect |
| `SUPPORT_EMAIL` | **Yes** | `support@be-maintain.com` | Login footer, deletion mailto, App Store |
| `TERMS_OF_SERVICE_URL` | Recommended | `https://www.be-maintain.com/terms` | Login, Profile (optional for bootstrap validation) |

### Recommended published URLs (placeholders)

Replace `be-maintain.com` with your production domain before release:

```
PRIVACY_POLICY_URL=https://www.be-maintain.com/privacy
TERMS_OF_SERVICE_URL=https://www.be-maintain.com/terms
SUPPORT_URL=https://www.be-maintain.com/support
SUPPORT_EMAIL=support@be-maintain.com
ACCOUNT_DELETION_URL=https://www.be-maintain.com/account-deletion
```

**Manual confirmation required:** actual production domain, legal entity email, and whether `www` vs apex URL is canonical.

### Build validation

- [ ] Copy `scripts/defines.production.json.example` → `scripts/defines.production.json` (gitignored)
- [ ] Replace all placeholders with live URLs and Supabase credentials
- [ ] Run `node scripts/validate_production_defines.mjs` — must pass
- [ ] Run `./scripts/build_production.sh requestor ipa` (or `technician ipa`)
- [ ] Verify release IPA on physical device: login, legal links open, support mailto works

### App Store Connect URLs must match

App Store Connect **Privacy Policy URL**, **Support URL**, and marketing URLs must **exactly match** dart-define values baked into the IPA.

---

## Part B — Website structure (minimal)

Host static pages (or CMS) at your production domain:

```
/
├── /privacy              ← docs/privacy_policy.md
├── /terms                ← docs/terms_of_service.md
├── /support              ← docs/support.md
├── /account-deletion     ← docs/account_deletion.md
├── /about                ← optional: product overview for B2B
└── /contact              ← optional: redirect to mailto or contact form
```

### Minimum viable launch

| Page | Priority | Source file |
|------|----------|-------------|
| Privacy Policy | **Required** | `docs/privacy_policy.md` |
| Support | **Required** | `docs/support.md` |
| Account Deletion | **Required** (Apple 5.1.1(v)) | `docs/account_deletion.md` |
| Terms of Service | **Recommended** | `docs/terms_of_service.md` |

### Before publishing web pages

- [ ] Replace all `[INSERT DATE]`, `[SUPPORT_EMAIL]`, URL placeholders
- [ ] **Manual confirmation required:** legal entity name, registered address, governing law in Terms
- [ ] **Manual confirmation required:** privacy contact / DPO if required by jurisdiction
- [ ] Test all links from a mobile browser (same experience as in-app `launchLegalUrl`)
- [ ] Enable HTTPS with valid certificate

---

## Part C — Legal document deliverables

| File | Status | Action |
|------|--------|--------|
| `docs/privacy_policy.md` | Draft ready | Legal review → publish at `PRIVACY_POLICY_URL` |
| `docs/terms_of_service.md` | Draft ready | Legal review → publish at `TERMS_OF_SERVICE_URL` |
| `docs/support.md` | Draft ready | Publish at `SUPPORT_URL` |
| `docs/account_deletion.md` | Draft ready | Publish at account deletion URL |
| `docs/app_store_privacy_checklist.md` | Internal reference | Use when filling App Store Connect |
| `docs/release_legal_checklist.md` | This file | Complete before submission |

---

## Part D — App Store compliance review

### Verified from repository ✅

| Guideline area | Finding | Risk |
|----------------|---------|------|
| **5.1.1 Privacy — policy link** | `LegalFooter` + Profile link to `PRIVACY_POLICY_URL`; release throws if missing | Low **if URLs live** |
| **5.1.1(v) Account deletion** | Profile → `showAccountDeletionRequestDialog` → mailto support | Low **if deletion page + process documented** |
| **2.1 App completeness** | Auth + submit + status flows implemented | Low with valid reviewer account |
| **4.2 Minimum functionality** | B2B CMMS with real backend (Supabase) | Low |
| **5.1.1(i) Data collection disclosure** | Privacy manifest + policy docs align on email, name, phone, photos, user ID | Low if App Store Connect matches |
| **Tracking / ATT** | No tracking SDKs; `NSPrivacyTracking: false` | Low — declare **No tracking** |
| **Encryption export** | `ITSAppUsesNonExemptEncryption: false` | Low |
| **Push notifications** | Not enabled; do not claim push in listing | Low |
| **Login — no broken demo** | Release requires Supabase defines; demo mode debug-only | Medium — must ship working reviewer credentials |
| **Permission strings** | Camera + Photo Library purpose strings present | Low |
| **Wrong app / role** | Enforced by `app_role_policy.dart` | Low — document for reviewers |
| **B2B account creation** | Login states org-admin provisioning | Low — explain in App Review notes |
| **Password reset** | External email link (Supabase) | Medium — SMTP must work for reviewers |
| **User-generated content** | Maintenance descriptions + optional photos | Low — B2B operational context, not public social UGC |
| **Sign in with Apple** | Not required — custom B2B email/password only | Low for enterprise B2B |

### Requires manual confirmation ⚠️

| Item | Risk if not addressed | Action |
|------|----------------------|--------|
| **Legal URLs are placeholders** | **Rejection / build failure** | Publish pages; update `defines.production.json` |
| **Legal entity not named in policies** | Review questions | Add registered company name and address |
| **Supabase SMTP / password reset** | Reviewer cannot test account recovery | Configure Supabase Auth email |
| **Reviewer demo account** | Cannot login → rejection | Seed requestor + company + chargers (`scripts/sql/app_review_checklist.sql`) |
| **Server RLS misconfiguration** | Data leak or empty data | Audit Supabase policies (**UNVERIFIED in repo**) |
| **Account deletion process** | 5.1.1(v) challenge | Document SLA; train support to honor requests |
| **Privacy policy vs actual behavior** | Misrepresentation | Confirm retention, subprocessors, region with legal |
| **Age rating** | Misclassification | Set in App Store Connect (not in repo) |
| **Enterprise customer contracts** | Terms conflict | Align Terms with customer MSAs |
| **Technician app deletion dialog** | Minor inconsistency | Deletion email subject says “Requestor” even on Tech app — cosmetic |
| **SupportService local-only tickets** | Support gap if users expect in-app ticket sync | Document email-first support |
| **OneSignal docs in repo** | Review confusion | Do not enable push; ignore `docs/ONESIGNAL_SETUP.md` for v1 |
| **Session timeout config** | Policy accuracy | `SESSION_TIMEOUT` not enforced in code — do not promise auto-logout |

### Potential rejection flags 🚩

1. **Missing or placeholder Privacy Policy / Support URLs** at submission time  
2. **Release IPA built without Supabase credentials** — app shows bootstrap error  
3. **No working demo account** for App Review (requestor role + company + assets)  
4. **App Store Privacy answers inconsistent** with `PrivacyInfo.xcprivacy` or actual collection  
5. **Listing claims push notifications** — not implemented  
6. **Account deletion link dead-end** — mailto fails and no published deletion policy  

---

## Part E — Pre-submission checklist (copy/paste)

### Legal & web

- [ ] Privacy Policy published at `PRIVACY_POLICY_URL`
- [ ] Support page published at `SUPPORT_URL`
- [ ] Account deletion page published
- [ ] Terms published (recommended)
- [ ] Legal counsel reviewed placeholders
- [ ] Support mailbox `SUPPORT_EMAIL` monitored

### Production build

- [ ] `scripts/defines.production.json` complete (no `your-domain.com` placeholders)
- [ ] `validate_production_defines.mjs` passes
- [ ] Version/build number incremented in `apps/requestor_cmms/pubspec.yaml`
- [ ] Release IPA tested on physical iPhone
- [ ] Legal links open in Safari
- [ ] Account deletion opens Mail with prefilled body

### App Store Connect

- [ ] App Privacy questionnaire completed (`docs/app_store_privacy_checklist.md`)
- [ ] Tracking = **No**
- [ ] Privacy Policy URL entered
- [ ] Support URL entered
- [ ] Demo credentials in App Review Information (`docs/APP_STORE_REVIEW_NOTES.md`)
- [ ] B2B / no self-registration explained
- [ ] No push notification claims in description or screenshots
- [ ] Encryption = standard HTTPS only
- [ ] Screenshots and metadata accurate

### Backend / operations

- [ ] Supabase production project URL/key in defines match Dashboard
- [ ] Reviewer account seeded with `requestor` role + `companyId` + Siemens/Kostad assets
- [ ] Password reset email deliverability tested
- [ ] **Manual confirmation required:** RLS audit complete
- [ ] **Manual confirmation required:** account deletion runbook for support team

---

## Part F — Quick reference

| Resource | Path |
|----------|------|
| App Review paste-in notes | `docs/APP_STORE_REVIEW_NOTES.md` |
| Store release guide | `docs/STORE_RELEASE.md` |
| Production defines example | `scripts/defines.production.json.example` |
| Legal links implementation | `packages/cmms_core/lib/utils/legal_links.dart` |
| Bootstrap legal enforcement | `packages/cmms_core/lib/bootstrap/cmms_bootstrap_policy.dart` |
| iOS privacy manifest | `apps/requestor_cmms/ios/Runner/PrivacyInfo.xcprivacy` |

---

*Complete this checklist before Transporter upload and App Store Connect submission.*
