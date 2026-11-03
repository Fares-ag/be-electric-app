# Privacy Policy

**Effective date:** [INSERT DATE]  
**Last updated:** [INSERT DATE]

This Privacy Policy describes how **Be Electric** (“we,” “us,” or “our”) collects, uses, and protects information when you use our mobile applications **Be Electric Requestor** and **Be Electric Tech** (together, the “Apps”) and related services.

The Apps are **business-to-business (B2B)** tools for organizations that operate and maintain electric vehicle (EV) charging equipment. Accounts are created by your organization’s administrator; the Apps do not offer public self-registration.

If you have questions about this policy, contact us at **support@be-maintain.com** or visit **https://www.be-maintain.com/support**.

---

## 1. Who this policy applies to

This policy applies to users who access the Apps with credentials provided or authorized by their employer or service organization, including:

- **Requestors** — submit and track EV charger maintenance requests (Be Electric Requestor app)
- **Technicians, managers, and administrators** — manage work orders, assets, preventive maintenance, inventory, and related operations (Be Electric Tech app)

Your organization may have its own policies regarding your use of the Apps and workplace data. Where those policies apply, they govern your relationship with your employer; this policy governs how we handle information processed through the Apps.

---

## 2. Information we collect

We collect information necessary to authenticate you, operate the CMMS (Computerized Maintenance Management System), and fulfill maintenance workflows.

### 2.1 Account and profile information

When your organization provisions an account, we process:

- **Name**
- **Email address**
- **User ID** (internal identifier linked to your account)
- **Role** (for example: requestor, technician, manager, admin)
- **Department** (if provided by your organization)
- **Company affiliation** (`companyId` and company name)
- **Account status** (for example: active/inactive)
- **Dates** such as account creation and last sign-in

Authentication is handled through **Supabase Auth** using email and password. Passwords are managed by the authentication provider; we do not store your password in plain text in the Apps.

### 2.2 Maintenance request and work order information

Depending on your role and actions in the Apps, we process:

- **Problem descriptions** and maintenance categories
- **Asset/charger information** (for example: manufacturer, model, location text, serial identifiers associated with registered assets)
- **Ticket numbers** and work order status
- **Notes**, priority, and workflow-related fields
- **Contact details on requests** — name, optional phone number, and email submitted with a maintenance request
- **Technician assignment and completion data** (Be Electric Tech app), including completion notes, costs where entered, and timestamps
- **Drawn signatures** captured during work order or preventive maintenance completion (Be Electric Tech app)

Location fields in the Apps refer to **text descriptions** of charger or site location (for example, a site name or address entered manually). The Apps **do not collect GPS or precise device location** based on the current codebase.

### 2.3 Photos and attachments

You may optionally attach photos when creating or updating maintenance requests or work orders. Photos are:

- Selected using the device **camera** or **photo library**
- Uploaded to **Supabase Storage** (bucket: `files`) under paths such as `work_orders/photos/`, `work_orders/completion_photos/`, `work_orders/signatures/`, and `pm_tasks/completion_photos/`

Photos are associated with your account and the relevant work order or task. Do not upload images you are not authorized to share.

### 2.4 Device and app information (limited)

In certain support-related flows, the Apps may collect:

- **Device model and operating system version**
- **App name and version**
- On iOS, **identifier for vendor** (`identifierForVendor`) when support diagnostics are assembled

This information is used to help troubleshoot issues. **Manual confirmation required:** whether support tickets created in-app are transmitted to a remote server or stored only on-device (the client stores tickets locally in `SharedPreferences`; remote submission is not implemented in the current codebase).

The Apps also use **local device storage** (`SharedPreferences`) for items such as notification preferences, login rate-limit timestamps, and (in debug builds only) local session restoration data.

### 2.5 In-app notifications and operational analytics

The Apps maintain an **in-app notification list** backed by data stored in our database (`notifications` table). This version **does not send remote push notifications**, SMS alerts, or email alerts from the Apps.

The Apps compute **operational analytics** (for example: work order volumes, completion rates, asset performance) from CMMS data for authorized roles. These metrics are derived from your organization’s maintenance data and may be stored or updated in our database (including an `analytics` table). This is **not** third-party advertising or cross-app tracking analytics.

**We do not use Firebase Analytics, Google Analytics, or similar third-party advertising/analytics SDKs in the current production Apps.**

---

## 3. How we use information

We use collected information to:

- **Authenticate** you and enforce role-based access (for example, requestors may only use the Requestor app)
- **Create, assign, update, and track** maintenance requests and work orders
- **Store and display** photos and signatures attached to maintenance records
- **Sync data in near real time** between authorized users in your organization (via Supabase realtime subscriptions)
- **Display account and company information** on your profile screen
- **Send password reset emails** when you use “Forgot password?” (handled by Supabase Auth; completed outside the app via the email link)
- **Respond to support and account deletion requests**
- **Maintain security and integrity** of the service (for example, client-side login rate limiting)

We do **not** use your information for cross-app advertising or sell your personal information.

---

## 4. How we share information

### 4.1 Within your organization

Maintenance data you submit is visible to authorized users in your organization according to their role (for example, technicians and administrators handling your requests). Your employer controls account provisioning and may remove or modify accounts through administrative tools.

### 4.2 Service providers

We use third-party infrastructure providers to operate the Apps, including:

| Provider | Purpose |
|----------|---------|
| **Supabase** | Authentication, database, file storage, and realtime data sync |
| **Apple** | App distribution, platform services, and (when applicable) standard iOS system APIs |
| **Google** | App distribution on Google Play (Android), platform services |

Data processed by Supabase is subject to Supabase’s terms and security practices. **Manual confirmation required:** data processing agreements, subprocessors list, and primary data region for your Supabase project.

### 4.3 Legal and safety

We may disclose information if required by law, regulation, legal process, or to protect the rights, safety, and security of users, our organization, or others.

### 4.4 No sale of personal information

We do not sell personal information as defined by applicable privacy laws.

---

## 5. Data retention

We retain information for as long as your organization maintains your account and as needed to provide the CMMS, comply with legal obligations, resolve disputes, and enforce agreements.

**Manual confirmation required:** specific retention periods for work orders, photos, audit logs, and deleted user records on the server (server-side retention policies are not defined in the application repository).

When you request account deletion (see Section 8), we will process your request according to Section 8 and applicable law. Some information may be retained where required or permitted (see Section 8.2).

---

## 6. Security

We implement reasonable technical and organizational measures appropriate to a B2B operational application, including:

- **Encryption in transit** (HTTPS/TLS) for communication with backend services
- **Authenticated access** to storage uploads and database operations
- **Role-based access** in the Apps separating requestor and technician/admin experiences

No method of transmission or storage is completely secure. You are responsible for safeguarding your login credentials and reporting unauthorized access promptly.

**Manual confirmation required:** server-side Row Level Security (RLS) policies, backup schedules, and incident response procedures (not verifiable from the client repository alone).

---

## 7. Your rights and choices

Depending on your location, you may have rights to access, correct, delete, or restrict processing of your personal information, or to object to certain processing.

Because accounts are organization-managed:

- **Corrections** to role, department, or employment status may need to be handled by your organization’s administrator
- **Access or export requests** may be submitted to us at **support@be-maintain.com** or through your employer
- **Password changes** can be initiated via “Forgot password?” on the login screen (Supabase Auth email flow)

We will respond to verifiable requests in accordance with applicable law. **Manual confirmation required:** designated privacy contact and jurisdictional response timelines.

---

## 8. Account deletion

### 8.1 How to request deletion

You may request deletion of your account and associated personal data by:

1. Opening the App → **Profile** → **Request account deletion**, which opens a pre-filled email to **support@be-maintain.com**, or  
2. Emailing **support@be-maintain.com** with the subject “Account deletion request” and including your name and account email

Your employer may also remove your account through their **administrator** (supported in the Be Electric Tech app via administrative user management).

The Apps do **not** perform fully automated self-service account deletion in the client; deletion is initiated through support or your organization’s admin.

### 8.2 What may be retained

After deletion, we may retain certain information where required or permitted by law or legitimate business needs, such as:

- Maintenance records required for **warranty, safety, regulatory, or contractual** obligations
- **Audit trails** or operational logs tied to completed work orders
- **Backups** for a limited period before overwrite

**Manual confirmation required:** exact server-side deletion workflow, anonymization vs. hard delete, and retention schedule.

---

## 9. Children’s privacy

The Apps are intended for **authorized business users** and are **not directed to children under 13** (or the minimum age in your jurisdiction). We do not knowingly collect personal information from children. If you believe a child has provided us information, contact **support@be-maintain.com**.

---

## 10. International transfers

**Manual confirmation required:** whether personal data is stored or processed outside your country (depends on Supabase project region and organizational arrangements).

---

## 11. Third-party links

The Apps may open links in your device browser (for example, Privacy Policy, Terms of Service, Help & Support pages). Those sites may have separate privacy practices.

---

## 12. Tracking and advertising

- We **do not** use the App Tracking Transparency (ATT) framework for cross-app tracking.
- We **do not** collect **IDFA** or use advertising SDKs.
- Apple Privacy Nutrition labels in the Apps declare **NSPrivacyTracking: false**.

Operational CMMS analytics inside the Apps are not used for third-party advertising or cross-app tracking.

---

## 13. Changes to this policy

We may update this Privacy Policy from time to time. We will post the updated policy at **https://www.be-maintain.com/privacy** and update the “Last updated” date. Material changes may also be communicated through your organization or in-app notices where appropriate.

Continued use of the Apps after an update constitutes acceptance of the revised policy, subject to applicable law.

---

## 14. Contact us

**Be Electric**  
Email: **support@be-maintain.com**  
Support: **https://www.be-maintain.com/support**  
Privacy Policy: **https://www.be-maintain.com/privacy**

**Manual confirmation required:** legal entity name, registered address, and data protection officer (if applicable).

---

*This document reflects the Be Electric CMMS Flutter applications as implemented in the current codebase. Server-side policies and organizational contracts should be reviewed before publication.*
