# QAuto CMMS (Be Electric) — Full Documentation

Complete documentation for building the **React Web App** (Admin + Requestor) and **Flutter Mobile App** (Technician + Requestor). Both apps share the same Supabase backend.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Design System](#2-design-system)
3. [User Roles & Permissions](#3-user-roles--permissions)
4. [User Flows](#4-user-flows)
5. [Backend (Supabase)](#5-backend-supabase)
6. [Data Models & Schema](#6-data-models--schema)
7. [Authentication](#7-authentication)
8. [Storage & File Uploads](#8-storage--file-uploads)
9. [React App — Admin & Requestor](#9-react-app--admin--requestor)
10. [Flutter App — Technician & Requestor](#10-flutter-app--technician--requestor)
11. [API Reference](#11-api-reference)
12. [Notifications](#12-notifications)

---

## 1. System Overview

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SUPABASE BACKEND                                 │
│  PostgreSQL • Auth • Storage • Realtime • RLS                             │
└─────────────────────────────────────────────────────────────────────────┘
         │                                    │
         ▼                                    ▼
┌─────────────────────┐            ┌─────────────────────────────────────┐
│   REACT WEB APP     │            │      FLUTTER MOBILE APP              │
│   (New Project)     │            │      (This Repo)                     │
├─────────────────────┤            ├─────────────────────────────────────┤
│ • Admin             │            │ • Technician                          │
│ • Requestor         │            │ • Requestor                          │
└─────────────────────┘            └─────────────────────────────────────┘
```

### Tech Stack

| Layer | React App | Flutter App |
|-------|-----------|-------------|
| Framework | React 18+ | Flutter 3.x |
| State | React Query / Zustand | Provider |
| Auth | @supabase/supabase-js | supabase_flutter |
| Backend | Supabase | Supabase |

### Supabase Project

- **URL:** `https://sdhqjyjeczrbnvukrmny.supabase.co`
- **Anon Key:** `sb_publishable_jymzllhRW_CVJH6pY3qleA_7GRd1ETA`

---

## 2. Design System

### Brand: Be Electric

| Token | Value | Usage |
|-------|-------|--------|
| `primaryColor` | `#000000` (Black) | Primary text, icons |
| `accentGreen` | `#002911` | **Main brand color** — buttons, focus, links |
| `accentRed` | `#D32F2F` | Errors, urgent, destructive |
| `accentBlue` | `#1976D2` | Info, secondary actions |
| `accentOrange` | `#F57C00` | Warnings |
| `backgroundColor` | `#F5F5F5` | Page background |
| `surfaceColor` | `#FFFFFF` | Cards, modals |
| `borderColor` | `#E0E0E0` | Borders |
| `secondaryTextColor` | `#757575` | Secondary text |
| `darkTextColor` | `#424242` | Body text |

### Typography

- **Font:** `Suisse Int'l` (or fallback: system sans-serif)
- **Heading 1:** 24px, bold
- **Heading 2:** 20px, w600
- **Body:** 16px, normal
- **Secondary:** 14px
- **Small:** 12px

### Components

| Element | Spec |
|---------|------|
| Card radius | 16px |
| Button radius | 8px |
| Input radius | 8px |
| Card elevation | 2 |
| Button padding | 24px horizontal, 12px vertical |
| Spacing XS/S/M/L/XL/XXL | 4, 8, 16, 20, 24, 32 |

### Status Colors (Work Orders)

| Status | Color |
|--------|-------|
| Open | `#BDBDBD` |
| Assigned | `#BDBDBD` |
| In Progress | `#9E9E9E` |
| Completed | `#9E9E9E` |
| Closed | `#757575` |
| Cancelled | `#757575` |
| Reopened | `#BDBDBD` |

### Priority Colors

| Priority | Color |
|----------|-------|
| Low | `#E0E0E0` |
| Medium | `#BDBDBD` |
| High | `#9E9E9E` |
| Urgent | `#FF7043` |
| Critical | `#757575` |

---

## 3. User Roles & Permissions

| Role | React App | Flutter App | Permissions |
|------|-----------|-------------|-------------|
| **Admin** | ✅ | ❌ | Full system access |
| **Manager** | ✅ | ❌ | Same as Admin |
| **Requestor** | ✅ | ✅ | Create requests, view own requests, analytics |
| **Technician** | ❌ | ✅ | Assigned work orders/PM tasks, complete, parts requests |

### Permission Matrix

| Action | Admin | Manager | Requestor | Technician |
|--------|-------|---------|-----------|------------|
| Create maintenance request | ✅ | ✅ | ✅ | ✅ |
| View own requests | ✅ | ✅ | ✅ | — |
| View all work orders | ✅ | ✅ | ❌ | ❌ |
| Assign technicians | ✅ | ✅ | ❌ | ❌ |
| Complete work orders | — | — | ❌ | ✅ (assigned only) |
| Manage assets | ✅ | ✅ | ❌ | ❌ |
| Manage users | ✅ | ✅ | ❌ | ❌ |
| Manage inventory | ✅ | ✅ | ❌ | ❌ |
| Approve parts requests | ✅ | ✅ | ❌ | ❌ |
| Request parts | — | — | ❌ | ✅ |
| QR scan assets | — | — | — | ✅ |
| Analytics (all) | ✅ | ✅ | ❌ | ❌ |
| Analytics (own) | — | — | ✅ | ✅ |

---

## 4. User Flows

### 4.1 Requestor Flow (Create Maintenance Request)

```
1. Login
2. Choose asset type (Siemens / Kostad charger or scan QR)
3. Fill form:
   - Problem description (required)
   - Priority (low/medium/high/urgent/critical)
   - Category (mechanical, electrical, etc.)
   - Photos (optional)
   - Notes (optional)
4. Submit → Work order created with status "open"
5. View "My Requests" for status updates
```

### 4.2 Admin Flow (Manage Work Order)

```
1. Login
2. Dashboard → Work Orders
3. Filter by status, priority, technician
4. Open work order → Assign technician(s)
5. Work order status: open → assigned → in_progress → completed → closed
6. Reopen if needed
```

### 4.3 Technician Flow (Complete Work Order)

```
1. Login
2. Dashboard shows assigned work orders & PM tasks
3. Option A: Scan QR → View asset → Create/view tasks
4. Option B: Work Orders tab → Select task
5. Start work → Update status (in_progress)
6. Add completion details:
   - Corrective actions
   - Recommendations
   - Completion photos
   - Technician signature
7. Complete → Requestor can sign off
8. Request parts if needed (from assigned work order)
```

### 4.4 Admin Flow (Inventory & Parts)

```
1. Inventory list → Add/edit items, set min/max stock
2. Low stock alerts → Review items below minimum
3. Parts request queue → Approve/reject technician requests
4. Purchase orders → Create, approve, track
```

---

## 5. Backend (Supabase)

### Tables

| Table | Purpose |
|-------|---------|
| `work_orders` | Maintenance requests |
| `assets` | Equipment (EV chargers, etc.) |
| `pm_tasks` | Preventive maintenance tasks |
| `users` | App users (linked to auth.users) |
| `companies` | Multi-tenant organizations |
| `support_requests` | Be Electric Know How / Commissioning (requestor app) |
| `support_request_messages` | Admin support message threads (optional; FK may need restore) |
| `inventory_items` | Parts and supplies |
| `parts_requests` | Technician parts requests |
| `purchase_orders` | Purchase orders |
| `workflows` | Approval workflows |
| `audit_events` | Audit log |
| `escalation_events` | Escalations |
| `notifications` | User notifications (server; requestor UI uses local prefs today) |
| `vendors` | Vendor data |

**Requestor app database map:** see [REQUESTOR_DATABASE.md](REQUESTOR_DATABASE.md).

### RLS (Row Level Security)

- **Requestor:** Can read/write own work orders (`requestorId = auth.uid()::text`); can INSERT/SELECT own `support_requests` (`createdBy = auth.uid()::text`)
- **Technician:** Can read work orders where assignedTechnicianIds contains auth.uid
- **Admin/Manager:** Can read/write all rows (company-scoped where applicable)
- **Users table:** Lookup by email; RLS policies must avoid recursion (see `fix_users_rls_no_recursion.sql`)

### Realtime

- Subscribe to `work_orders`, `pm_tasks`, `notifications` for live updates.

---

## 6. Data Models & Schema

### 6.1 Work Order

| Field | Type | Description |
|-------|------|-------------|
| id | string (UUID) | Primary key |
| ticketNumber | string | Human-readable ID (e.g. WO-001) |
| problemDescription | string | Required |
| requestorId | string | FK → users |
| assetId | string? | FK → assets (optional) |
| location | string? | For general maintenance |
| companyId | string? | FK → companies |
| status | enum | open, assigned, inProgress, completed, closed, cancelled, reopened |
| priority | enum | low, medium, high, urgent, critical |
| category | enum? | mechanicalHvac, electrical, structural, plumbing, etc. |
| assignedTechnicianIds | string[] | Array of user IDs |
| primaryTechnicianId | string? | First assigned tech |
| photoPaths | string[] | Request photos (Supabase Storage URLs) |
| completionPhotoPaths | string[] | Completion photos |
| correctiveActions | string? | |
| recommendations | string? | |
| requestorSignature | string? | Base64 or URL |
| technicianSignature | string? | |
| notes | string? | |
| createdAt | datetime | |
| updatedAt | datetime | |
| assignedAt | datetime? | |
| startedAt | datetime? | |
| completedAt | datetime? | |
| closedAt | datetime? | |
| idempotencyKey | string? | Duplicate prevention |

**RepairCategory enum:** mechanicalHvac, electrical, structural, plumbing, interior, exterior, itLowVoltage, specializedEquipment, safetyCompliance, emergency, preventive, reactive

### 6.2 Asset

| Field | Type | Description |
|-------|------|-------------|
| id | string | Primary key |
| name | string | |
| location | string | |
| description | string? | |
| category | string? | |
| manufacturer | string? | |
| model | string? | |
| serialNumber | string? | |
| status | string | active, inactive, maintenance |
| qrCodeId | string? | For QR scanning |
| companyId | string? | |
| createdAt | datetime | |
| updatedAt | datetime | |

### 6.3 User

| Field | Type | Description |
|-------|------|-------------|
| id | string | Matches auth.users.id |
| email | string | |
| name | string | |
| role | string | requestor, technician, manager, admin |
| department | string? | |
| companyId | string? | |
| isActive | boolean | Default true |
| createdAt | datetime | |
| updatedAt | datetime? | |

### 6.4 PM Task

| Field | Type | Description |
|-------|------|-------------|
| id | string | Primary key |
| taskName | string | |
| assetId | string | FK → assets |
| description | string | |
| frequency | enum | daily, weekly, monthly, quarterly, semiAnnually, annually, asNeeded |
| intervalDays | int | |
| status | enum | pending, inProgress, completed, overdue, cancelled |
| assignedTechnicianIds | string[] | |
| nextDueDate | datetime? | |
| lastCompletedAt | datetime? | |
| createdAt | datetime | |
| completedAt | datetime? | |
| completionNotes | string? | |

### 6.5 Parts Request

| Field | Type | Description |
|-------|------|-------------|
| id | string | |
| workOrderId | string | FK → work_orders |
| technicianId | string | FK → users |
| inventoryItemId | string | FK → inventory_items |
| quantity | int | |
| reason | string | |
| priority | enum | low, medium, high, urgent |
| status | enum | pending, approved, rejected, fulfilled, cancelled |
| requestedAt | datetime | |
| approvedAt | datetime? | |
| fulfilledAt | datetime? | |
| approvedBy | string? | |

### 6.6 Inventory Item

| Field | Type | Description |
|-------|------|-------------|
| id | string | |
| name | string | |
| category | string | |
| quantity | double | |
| unit | string | |
| sku | string? | |
| minimumStock | double? | |
| maximumStock | double? | |
| cost | double? | |
| status | string | active, inactive |

### 6.7 Company

| Field | Type | Description |
|-------|------|-------------|
| id | string | |
| name | string | |
| contactEmail | string? | |
| contactPhone | string? | |
| address | string? | |
| isActive | boolean | |

### 6.8 Notification

| Field | Type | Description |
|-------|------|-------------|
| id | string | |
| userId | string | FK → users |
| title | string | |
| body | string? | |
| type | string | work_order, pm_task, parts_request, etc. |
| relatedEntityId | string? | |
| read | boolean | Default false |
| createdAt | datetime | |

---

## 7. Authentication

### Flow

1. **Sign In:** `supabase.auth.signInWithPassword({ email, password })`
2. **User Lookup:** Query `users` table by `auth.users.id` (or email)
3. **Auto-create:** If user not in `users` and `AUTO_CREATE_USERS_ON_LOGIN` is enabled, create user with role from metadata
4. **Session:** Store `current_user_id` in local storage / SharedPreferences
5. **Role:** Read from `users.role`

### Demo Credentials (if enabled)

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@qauto.com | demo123 |
| Manager | manager@qauto.com | demo123 |
| Technician | technician@qauto.com | demo123 |
| Requestor | requestor@qauto.com | demo123 |

### Password Reset

- Use `supabase.auth.resetPasswordForEmail(email)` for forgot-password flow.

---

## 8. Storage & File Uploads

### Buckets

- **Photos:** `work-order-photos` or similar
- Path pattern: `{workOrderId}/{timestamp}_{filename}` or `{userId}/{type}/{filename}`

### Upload Flow

1. User selects image
2. Upload to Supabase Storage: `supabase.storage.from('bucket').upload(path, file)`
3. Get public URL: `supabase.storage.from('bucket').getPublicUrl(path)`
4. Store URL in `work_orders.photoPaths` or `completionPhotoPaths`

### File Types

- Images: JPEG, PNG (recommend max 2MB per image)

---

## 9. React App — Admin & Requestor

### Project Setup

```bash
npx create-react-app qauto-cmms-web
# or: npx create-next-app qauto-cmms-web
npm install @supabase/supabase-js
```

### Route Structure

```
/                    → Login (redirect if authenticated)
/login               → Login
/dashboard           → Admin/Requestor dashboard (role-based)
/work-orders         → Work order list (Admin)
/work-orders/:id      → Work order detail (Admin)
/pm-tasks            → PM task list (Admin)
/assets              → Asset list (Admin)
/users               → User management (Admin)
/companies           → Company management (Admin)
/inventory           → Inventory list (Admin)
/parts-requests      → Parts request queue (Admin)
/purchase-orders     → Purchase orders (Admin)
/analytics           → Analytics dashboard
/reports             → Reporting (Admin)
/settings            → Settings (Admin)

# Requestor-specific
/request             → Create maintenance request (hero + asset selection)
/my-requests         → Requestor status (own work orders)
/requestor-analytics → Requestor analytics
/notifications       → Notification list
/notification-settings → Requestor notification preferences
```

### Admin Screens (React)

| Screen | Description |
|--------|-------------|
| Dashboard | Summary cards: open WOs, overdue PM, low stock, recent activity |
| Work Order List | Table with filters (status, priority, technician), assign, reopen |
| Work Order Detail | Full WO view, assign technicians, update status, add notes |
| PM Task List | Table with filters, assign, create PM task |
| Asset List | CRUD assets, QR codes |
| User Management | CRUD users, set role, company |
| Company Management | CRUD companies |
| Inventory List | CRUD inventory items |
| Low Stock Alerts | Items below minimumStock |
| Parts Request Queue | Approve/reject technician parts requests |
| Purchase Order Screen | Create, approve, track POs |
| Analytics Dashboard | Charts: WO by status, PM completion, MTTR, etc. |
| Reporting | Export reports |
| Settings | App settings |
| Notifications | Notification list |

### Requestor Screens (React)

| Screen | Description |
|--------|-------------|
| Request Maintenance | Hero with asset type selection (Siemens/Kostad or scan), then form |
| Create Request Form | Problem description, priority, category, photos, notes |
| My Requests | List of own work orders with status |
| Requestor Analytics | Own request stats |
| Notification Settings | Toggle notification preferences |
| Notifications | Notification list |

### Key React Components

- **RoleBasedLayout:** Wraps content, shows nav based on role
- **WorkOrderTable:** Filterable, sortable table
- **AssetSelector:** Search/select asset for request
- **PhotoUploader:** Multi-image upload with preview
- **StatusBadge:** Work order status chip
- **PriorityBadge:** Priority chip with color

---

## 10. Flutter App — Technician & Requestor

### Current Structure (This Repo)

```
lib/
├── config/           # Supabase config, service locator
├── models/           # WorkOrder, Asset, User, PMTask, etc.
├── providers/        # AuthProvider, UnifiedDataProvider, InventoryProvider
├── screens/
│   ├── admin/        # AdminMainScreen, UserManagementScreen, etc.
│   ├── requestor/    # RequestorMainScreen, CreateMaintenanceRequestScreen, RequestorStatusScreen
│   ├── technician/   # TechnicianMainScreen
│   ├── work_orders/  # WorkOrderListScreen, detail, completion
│   ├── pm_tasks/     # PMTaskListScreen, CreatePMTaskScreen
│   ├── inventory/    # InventoryListScreen, PartsRequestScreen
│   └── ...
├── services/         # SupabaseDatabaseService, AuthService, StorageService
├── utils/            # app_theme.dart, validators
└── widgets/          # RoleBasedNavigation, MobileQRScannerWidget
```

### Flutter: Technician + Requestor Only

**Modify `RoleBasedNavigation`** to only allow `requestor` and `technician`:

```dart
switch (user.role.toLowerCase()) {
  case 'requestor':
    return const RequestorMainScreen();
  case 'technician':
    return const TechnicianMainScreen();
  case 'manager':
  case 'admin':
    // Redirect to web or show "Use web app" message
    return const WebAppRedirectScreen();
  default:
    return const RequestorMainScreen(); // or login
}
```

### Technician Screens (Flutter)

| Screen | Description |
|--------|-------------|
| Technician Dashboard | Welcome, QR scan button, stat cards, recent tasks |
| Work Order List | Assigned work orders only |
| Work Order Detail | View, start, complete, add photos, signature |
| PM Task List | Assigned PM tasks only |
| PM Task Detail | Start, complete, checklist |
| Parts Request | Select WO, select item, quantity, reason |
| QR Scanner | Scan asset QR, show asset info + related tasks |
| Analytics | Technician-specific metrics |

### Requestor Screens (Flutter)

| Screen | Description |
|--------|-------------|
| Requestor Main | Hero with Siemens/Kostad cards → Create request |
| Create Maintenance Request | Form with asset, description, priority, photos |
| My Requests | RequestorStatusScreen — own work orders |
| Requestor Analytics | RequestorAnalyticsScreen |
| Notification Settings | RequestorNotificationSettingsScreen |
| Notifications | NotificationListScreen |

### Flutter Routes to Keep

- `/create_maintenance_request` — with args: `asset`, `qrCode`, `chargerType`
- `/analytics_dashboard` — ConsolidatedAnalyticsDashboard

---

## 11. API Reference

### Supabase Client Usage

```javascript
// React
import { createClient } from '@supabase/supabase-js'
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
```

```dart
// Flutter
Supabase.instance.client
```

### Work Orders

| Operation | Method | Table | Notes |
|-----------|--------|-------|-------|
| Create | INSERT | work_orders | Generate ticketNumber (e.g. WO-{timestamp}) |
| Read (all) | SELECT | work_orders | Admin: all; Requestor: requestorId = uid; Tech: assignedTechnicianIds @> uid |
| Read (one) | SELECT | work_orders | By id |
| Update | UPDATE | work_orders | Status, assign technicians, completion fields |
| Delete | — | — | Prefer soft delete (status = cancelled) |

### Assets

| Operation | Method | Table |
|-----------|--------|-------|
| List | SELECT | assets |
| Get by ID | SELECT | assets |
| Get by QR | SELECT | assets WHERE qrCodeId = ? |
| Create | INSERT | assets |
| Update | UPDATE | assets |

### Users

| Operation | Method | Table |
|-----------|--------|-------|
| Get by ID | SELECT | users |
| Get by email | SELECT | users |
| List (technicians) | SELECT | users WHERE role = 'technician' |
| Create | INSERT | users |
| Update | UPDATE | users |

### PM Tasks

| Operation | Method | Table |
|-----------|--------|-------|
| List | SELECT | pm_tasks |
| Create | INSERT | pm_tasks |
| Update | UPDATE | pm_tasks |
| Assign | UPDATE | pm_tasks SET assignedTechnicianIds |

### Parts Requests

| Operation | Method | Table |
|-----------|--------|-------|
| Create | INSERT | parts_requests |
| List (queue) | SELECT | parts_requests WHERE status = 'pending' |
| Approve/Reject | UPDATE | parts_requests |

### Notifications

| Operation | Method | Table |
|-----------|--------|-------|
| List | SELECT | notifications WHERE userId = ? |
| Mark read | UPDATE | notifications SET read = true |

---

## 12. Notifications

### Types

- `work_order_assigned` — Technician assigned to WO
- `work_order_completed` — WO completed (for requestor)
- `work_order_status_change` — Status updated
- `pm_task_assigned` — PM task assigned
- `pm_task_overdue` — PM task overdue
- `parts_request_approved` — Parts request approved
- `parts_request_rejected` — Parts request rejected

### Implementation

- Insert into `notifications` table on events
- Realtime subscription: `supabase.channel('notifications').on('INSERT', ...)`
- Badge count: `SELECT COUNT(*) FROM notifications WHERE userId = ? AND read = false`

---

## Appendix A: Environment Variables

### React

```env
VITE_SUPABASE_URL=https://sdhqjyjeczrbnvukrmny.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_jymzllhRW_CVJH6pY3qleA_7GRd1ETA
```

### Flutter

- Stored in `lib/config/supabase_config.dart` (consider moving to env for production)

---

## Appendix B: Asset Images

- `assets/images/beElectricLogo.png` — Logo
- `assets/images/MaintenanceRequestBg.png` — Requestor hero background
- `assets/images/SiemensCharger.png` — Siemens charger card
- `assets/images/KostadCharger.png` — Kostad charger card

---

## Appendix C: Ticket Number Format

- Pattern: `WO-{YYYYMMDD}-{sequence}` or `WO-{timestamp}`
- Generated server-side or client-side with idempotency key to prevent duplicates

---

*Document generated from qauto-cmms Flutter codebase. Last updated: March 2025.*
