# App Store Privacy Questionnaire — Be Electric CMMS

This document summarizes answers for **App Store Connect → App Privacy** based on the current Flutter codebase. Use it when submitting **Be Electric Requestor** (`com.beelectric.cmms.requestorCmms`) and **Be Electric Tech** (`com.beelectric.cmms.technicianCmms`).

**Scope:** Client repository only. Items marked **Manual confirmation required** cannot be verified from code alone.

---

## Summary answers

| Question | Answer |
|----------|--------|
| **Do you or your third-party partners collect data from this app?** | **Yes** |
| **Is data linked to the user’s identity?** | **Yes** (account, work orders, photos) |
| **Is data used for tracking?** | **No** |
| **App Tracking Transparency (ATT) required?** | **No** (no IDFA / no cross-app tracking SDKs) |

---

## 1. Data collected (by category)

### Contact Info

| Data type | Collected | Linked to user | Tracking | Purpose | Source in repo |
|-----------|-----------|----------------|----------|---------|----------------|
| **Email address** | Yes | Yes | No | App functionality, account | Login, user profile, Supabase Auth |
| **Name** | Yes | Yes | No | App functionality, account | User profile, maintenance request form |
| **Phone number** | Yes (optional) | Yes | No | App functionality | Optional field on maintenance request (`customerPhone`) |

### User Content

| Data type | Collected | Linked to user | Tracking | Purpose | Source in repo |
|-----------|-----------|----------------|----------|---------|----------------|
| **Photos or videos** | Yes (optional) | Yes | No | App functionality | `image_picker` → Supabase Storage bucket `files` |
| **Other user content** | Yes | Yes | No | App functionality | Problem descriptions, notes, signatures (Tech app) |

### Identifiers

| Data type | Collected | Linked to user | Tracking | Purpose | Source in repo |
|-----------|-----------|----------------|----------|---------|----------------|
| **User ID** | Yes | Yes | No | App functionality | Supabase Auth UUID, `users.id` |

### Data **not** collected (verified from repo)

- Precise **location / GPS**
- **Contacts**, **calendar**, **health**, **financial info** (beyond operational cost fields entered by technicians)
- **Browsing history**, **search history** (no web tracking SDK)
- **Device ID for advertising** / **IDFA**
- **Purchase history** (no IAP)
- **Remote push notification tokens** (push not enabled in current build)

### Data collected in Tech app only (not Requestor submission path)

| Data type | Notes |
|-----------|-------|
| **Signatures** | Drawn signatures on work order / PM completion |
| **Completion photos** | `work_orders/completion_photos/`, `pm_tasks/completion_photos/` |
| **Operational analytics aggregates** | Derived KPIs from work orders/assets/PM tasks |

---

## 2. Data linked to users

**Yes.** The following are associated with authenticated user accounts:

- Profile fields (`email`, `name`, `role`, `department`, `companyId`)
- Work orders where user is requestor, assignee, or creator
- Photos uploaded while authenticated
- In-app notifications tied to user records

Apple Privacy Manifest (`PrivacyInfo.xcprivacy`) declares linked collection for: Email, Name, Phone, Photos/Videos, User ID — all with `NSPrivacyTracking: false`.

---

## 3. Data used for tracking

**No.**

Verified findings:

- `NSPrivacyTracking` = **false** in `apps/*/ios/Runner/PrivacyInfo.xcprivacy`
- No advertising SDKs, no AppsFlyer, Adjust, Facebook SDK, etc. in `pubspec.yaml`
- No `NSUserTrackingUsageDescription` in `Info.plist`
- No Firebase Analytics SDK wired in bootstrap
- In-app `AnalyticsService` computes **operational CMMS metrics**, not cross-app advertising analytics

**App Store Connect:** Answer **No** to “Do you use data for tracking purposes?”

---

## 4. Required iOS permissions

Declared in `Info.plist` (both apps):

| Permission key | Purpose string (summary) |
|----------------|--------------------------|
| `NSCameraUsageDescription` | Attach photos to maintenance requests / work orders |
| `NSPhotoLibraryUsageDescription` | Attach images from photo library |

**Not declared (and not used in current codebase):**

- Location
- Microphone
- Contacts
- Bluetooth
- Push notifications / background modes
- App Tracking (`NSUserTrackingUsageDescription`)

---

## 5. Android permissions (Google Play Data Safety)

From `AndroidManifest.xml` (both apps):

- `INTERNET`
- `CAMERA`
- `READ_MEDIA_IMAGES`
- `READ_EXTERNAL_STORAGE` (maxSdkVersion 32)

No `POST_NOTIFICATIONS`, location, or microphone.

---

## 6. Third-party SDKs and data sharing

### Processors / SDKs that receive user data

| Third party | Data shared | Purpose | Verified |
|-------------|-------------|---------|----------|
| **Supabase** | Auth credentials, profile, work orders, photos, realtime events | Backend (Auth, Postgres, Storage, Realtime) | Yes — `supabase_flutter` |
| **Apple** | Standard platform processing for App Store distribution | Distribution, OS APIs | Yes — platform |
| **Syncfusion** (Tech app features) | Data processed **on-device** for PDF/Excel/chart generation | Reporting UI | Yes — local processing |

### **Not** present in production dependencies

- Firebase (Auth, Analytics, Crashlytics, FCM)
- OneSignal
- Sentry
- Google Analytics
- Ad networks

**Note:** Legacy Firebase URL strings exist in debug/test utilities (`app_config.dart` default `API_URL`); **not** a runtime SDK dependency.

**Note:** `supabase/functions/send-push-notification/` (OneSignal) exists in repo but is **not invoked** from Flutter client.

### Privacy Required Reason APIs (iOS)

Declared in `PrivacyInfo.xcprivacy`:

- File timestamp (0A2A.1, C617.1)
- System boot time (35F9.1)
- UserDefaults (CA92.1)
- Disk space (E174.1)

---

## 7. Data sharing with third parties (App Store questionnaire)

For App Store Connect “Data shared with third parties”:

| Recipient | Shared data | Purpose |
|-----------|-------------|---------|
| **Supabase** | Account info, user content, identifiers | App functionality — hosting |

Answer **No** for sharing with **data brokers** or for **third-party advertising**.

**Manual confirmation required:**

- Supabase subprocessors and DPA
- Whether Syncfusion transmits data off-device (reports appear generated locally)
- Any organizational admin web portal (React) sharing the same Supabase backend

---

## 8. Encryption

- `ITSAppUsesNonExemptEncryption` = **false** (standard HTTPS/TLS only)
- App Store Connect: typically **No** for exempt encryption documentation

---

## 9. Account deletion (Guideline 5.1.1(v))

| Requirement | Status |
|-------------|--------|
| In-app path to initiate deletion | **Yes** — Profile → Request account deletion → mailto support |
| Support contact published | **Required** — `SUPPORT_EMAIL`, `SUPPORT_URL` dart-defines |
| Deletion policy published | **Required** — host `account_deletion.md` content at public URL |

**Manual confirmation required:** Server-side deletion SLA and proof of process for App Review if challenged.

---

## 10. Requestor vs Tech — questionnaire differences

| Topic | Requestor app | Tech app |
|-------|---------------|----------|
| Primary user content | Maintenance request text + optional photo | Work orders, signatures, completion photos, PM data |
| Analytics dashboard | Requestor-scoped analytics screen | Full CMMS analytics |
| Admin user deletion | No | Yes (`delete_user_by_id` RPC) |
| Push notifications | No | No |

For **Be Electric Requestor** App Store submission, declare at minimum: Contact Info, User Content (photos + descriptions), Identifiers (User ID).

---

## 11. Items that cannot be verified from the repository

| Item | Why unverified |
|------|----------------|
| Server RLS / who can read work orders | Migration SQL exists under `supabase/migrations/`; production apply status must be verified manually |
| Data retention after deletion | Server policy not in repo |
| Supabase project region / cross-border transfer | Project configuration external |
| Custom SMTP for password reset emails | Supabase dashboard config |
| Crash reporting to third party in production | `ProductionConfig.enableCrashReporting = false`; callback logs locally only |
| `SupportService` remote ticket submission | Stores tickets locally only in current code |
| Session auto-logout after 30 min | Config exists; enforcing code not found |
| Enterprise customer DPA terms | Contractual, not in repo |
| Age rating in App Store Connect | Set manually (recommend **4+** or business-appropriate; no kids’ features in app) |

---

## 12. Recommended App Store Connect declarations (Requestor)

**Data types to declare:**

1. **Email Address** — Linked: Yes — Tracking: No — Purpose: App Functionality  
2. **Name** — Linked: Yes — Tracking: No — Purpose: App Functionality  
3. **Phone Number** — Linked: Yes — Tracking: No — Purpose: App Functionality *(optional field)*  
4. **Photos or Videos** — Linked: Yes — Tracking: No — Purpose: App Functionality  
5. **User ID** — Linked: Yes — Tracking: No — Purpose: App Functionality  

**Tracking:** No  
**Privacy Policy URL:** Must match `PRIVACY_POLICY_URL` production define  

Align App Store Connect entries with `PrivacyInfo.xcprivacy` — inconsistencies may trigger review questions.

---

*Generated from repository inspection. Review with legal counsel before submission.*
