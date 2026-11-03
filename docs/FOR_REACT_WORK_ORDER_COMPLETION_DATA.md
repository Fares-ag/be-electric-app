# For the Next.js (beelectric-react) project: Work order completion data from Flutter

**Context:** When a technician completes a work order in the Flutter app, the following data is collected and written to the shared `work_orders` table. Use this in the React admin to display completion details and keep schema/UI in sync.

---

## 1. Where completion happens in Flutter

- **Screen:** `WorkOrderCompletionScreen` (opened from work order detail via “Complete Work”).
- **API:** Flutter calls `UnifiedDataProvider.updateWorkOrder(updatedWorkOrder)`, which performs a direct **UPDATE** on `public.work_orders` (not the `upsert_work_order` RPC). RLS applies; the technician must be in `assignedTechnicianIds` to update.

---

## 2. Completion fields the Flutter app sets

When the technician submits the completion form, Flutter builds an updated work order with:

| Field | Type | Required in Flutter | Notes |
|-------|------|--------------------|--------|
| **status** | text | ✅ | Set to `"completed"`. |
| **completedAt** | timestamp with time zone | ✅ | `DateTime.now()` at submit. |
| **correctiveActions** | text | Optional | Free text from form. |
| **recommendations** | text | Optional | Free text from form. |
| **nextMaintenanceDate** | date/timestamp | Optional | Date picker; next suggested maintenance. |
| **requestorSignature** | text | Optional | Deferred; not collected on technician completion (T-004 Option A). |
| **technicianSignature** | text | ✅ | Base64 or data URL from signature pad; required to submit. |
| **laborCost** | numeric | Optional | From form (parsed as double). |
| **partsCost** | numeric | Optional | From form (parsed as double). |
| **totalCost** | numeric | Optional | `laborCost + partsCost` if either set. |
| **completionPhotoPath** | text | Optional | **First** completion photo URL after upload to Supabase Storage. |
| **completionPhotoPaths** | (see below) | Optional | **All** completion photo URLs. Flutter uploads each image to Storage, then sends the first URL in `completionPhotoPath`. |

**Completion photos:** The app allows multiple photos. Each is uploaded to Supabase Storage (e.g. `work_orders/{workOrderId}/completion/...`). The **first** URL is stored in the column `completionPhotoPath`. The **full list** of URLs is stored in the row’s **`metadata`** JSONB under the key **`completionPhotoPaths`** (array of strings), because the current schema has only a single `completionPhotoPath` column. When reading in the admin, prefer `metadata->'completionPhotoPaths'` for the full list; fall back to `completionPhotoPath` for a single image.

**Before/after photos:** The Flutter completion screen does **not** currently set `beforePhotoPath` or `afterPhotoPath` (they are explicitly set to `null` in the completion payload). The schema has these columns if you want to use them later (e.g. from the admin or a future app version).

---

## 3. `work_orders` columns relevant to completion (Postgres)

From the shared migration/schema. Use these in the React app for display and filters:

| Column | Type | Description |
|--------|------|-------------|
| **status** | text | `open`, `assigned`, `inProgress`, `completed`, `closed`, `cancelled`, `reopened`. |
| **completedAt** | timestamp with time zone | When the work order was marked completed. |
| **closedAt** | timestamp with time zone | Optional; may be set when requestor/admin closes the ticket. |
| **correctiveActions** | text | What was done to fix the issue. |
| **recommendations** | text | Recommendations (e.g. follow-up, parts to order). |
| **nextMaintenanceDate** | timestamp with time zone | Suggested next maintenance date. |
| **requestorSignature** | text | Requestor sign-off (often base64 or URL). |
| **technicianSignature** | text | Technician sign-off (often base64 or URL). |
| **laborCost** | numeric | Labor cost. |
| **partsCost** | numeric | Parts cost. |
| **totalCost** | numeric | Total cost. |
| **completionPhotoPath** | text | Single completion photo URL (first photo in Flutter). |
| **beforePhotoPath** | text | Not set by Flutter completion; available for admin/future use. |
| **afterPhotoPath** | text | Not set by Flutter completion; available for admin/future use. |
| **metadata** | jsonb | Flutter stores **`completionPhotoPaths`** here (array of strings) for all completion photo URLs. |
| **updatedAt** | timestamp with time zone | Set on every update. |

---

## 4. Flutter completion form (for reference)

The completion screen collects:

1. **Corrective actions** – text field  
2. **Recommendations** – text field  
3. **Next maintenance date** – date picker (optional)  
4. **Labor cost** – number (optional)  
5. **Parts cost** – number (optional)  
6. **Completion photos** – one or more images (camera or gallery); uploaded to Storage, then URLs stored as above  
7. **Technician signature** – required; signature widget → base64/data URL  
8. **Requestor signature** – not collected on technician completion (T-004 Option A); column may remain null until a future requestor/admin sign-off flow  

On submit, Flutter sets `status: 'completed'`, `completedAt: now`, and the fields in the table above, then calls `updateWorkOrder` so the row is updated in place. The `WorkOrder.toMap()` used for the update includes `nextMaintenanceDate`, `technicianSignature`, `laborCost`, and `partsCost`, so these are persisted to `work_orders`.

---

## 5. What the React admin should do

- **Display:** For completed work orders, show at least: `completedAt`, `correctiveActions`, `recommendations`, `nextMaintenanceDate`, `laborCost`, `partsCost`, `totalCost`, and completion photos. For photos, read **`metadata->'completionPhotoPaths'`** (array) first; if missing, use **`completionPhotoPath`** (single). Signatures can be shown as images if stored as data URLs/base64.
- **Schema:** Do not remove or rename the completion-related columns or `metadata`; Flutter and any future mobile flows depend on them.
- **Filters/reports:** Use `status = 'completed'`, `completedAt`, and optionally `nextMaintenanceDate` for reporting and dashboards.

This is the full set of work order completion data the Flutter technician app writes so you can align the Next.js admin with it.
