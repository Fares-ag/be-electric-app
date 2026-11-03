# Account Deletion — Be Electric CMMS Apps

This page explains how to request deletion of your **Be Electric Requestor** or **Be Electric Tech** account and what happens to your data.

**Last updated:** [INSERT DATE]

---

## Overview

Be Electric CMMS apps are **B2B tools**. Accounts are created by your **organization’s administrator**. If you no longer need access, you may:

1. Ask your **employer / administrator** to deactivate or delete your account, or  
2. **Contact Be Electric support** to request deletion of your account and associated personal data

The apps provide an in-app path to start a deletion request; **deletion is not fully automated inside the app** — it is processed by support and/or your organization’s admin workflows.

---

## How to request deletion

### Option A — In the app (recommended)

1. Sign in to the app
2. Open **Profile**
3. Tap **Request account deletion**
4. Read the confirmation dialog
5. Tap **Email support** — this opens your email app with a pre-filled message to **support@be-maintain.com**

The pre-filled email includes your **name** and **account email** to help us locate your account.

### Option B — Email support directly

Send an email to **support@be-maintain.com** with:

- **Subject:** Account deletion request — Be Electric [Requestor / Tech]
- **Body:** Your full name, account email, organization name, and confirmation that you want your account and associated personal data deleted

### Option C — Through your organization

Your employer may remove your account using **administrative user management** in the Be Electric Tech app (admin role). Contact your internal administrator if you prefer this route.

---

## What data is deleted

When your deletion request is approved and processed, we aim to delete or deactivate data associated with your **user account**, including:

| Data type | Typical action |
|-----------|----------------|
| **User profile** (name, email, role, department, company link) | Deleted or deactivated |
| **Authentication record** (Supabase Auth user) | Deleted or disabled |
| **Account identifiers** linking you to the CMMS | Removed |

**Manual confirmation required:** exact server-side deletion steps (`delete_user_by_id` RPC and related Auth cleanup), timing, and whether records are hard-deleted or anonymized.

---

## What data may be retained

Even after account deletion, certain information may be **retained** where required or permitted by law or legitimate business needs, including:

### Maintenance and operational records

- **Work orders and maintenance requests** you created or participated in may remain in your organization’s CMMS history
- **Photos, signatures, notes, and timestamps** attached to completed or in-progress maintenance work may be retained for **operational, warranty, safety, regulatory, or contractual** reasons
- Such records may be **disassociated from your personal account** (for example, anonymized requestor reference) rather than deleted entirely

### Legal and security

- **Audit logs**, security events, or compliance records
- **Backup copies** until backup rotation overwrites them
- Information necessary to resolve **disputes**, enforce terms, or comply with **legal obligations**

Your organization, as the data controller for much of this operational data, may have separate retention policies.

**Manual confirmation required:** data retention schedule, backup retention period, and anonymization practices on the server.

---

## Processing time

| Step | Expected timeframe |
|------|-------------------|
| Acknowledgment of your request | Within **2 business days** |
| Identity / authorization verification | **1–3 business days** (we may confirm with your organization) |
| Completion of deletion/deactivation | Within **30 days** of verified request, unless a longer period is required by law or complex record review |

We will email you at the address associated with your account when processing is complete, or if we need additional information.

**Manual confirmation required:** official SLA and escalation contact.

---

## Before you delete your account

- **Export needs:** If you require copies of maintenance records, request them from your **organization** or email **support@be-maintain.com** before deletion
- **Active work:** Inform your team if you have **open maintenance requests or assigned work orders**
- **Alternative:** Your administrator can **deactivate** your account instead of deletion if you may return to the organization

---

## Children’s accounts

These apps are not intended for children. If you believe a minor’s account was created in error, contact **support@be-maintain.com** immediately.

---

## Questions

**Email:** **support@be-maintain.com**  
**Support:** **https://www.be-maintain.com/support**  
**Privacy Policy:** **https://www.be-maintain.com/privacy**

---

*This page describes account deletion as implemented in the Be Electric CMMS client applications. Server-side retention and organizational data-controller obligations require manual confirmation before legal publication.*
