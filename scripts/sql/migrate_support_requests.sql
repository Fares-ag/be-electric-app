-- Be Electric Support Requests — idempotent Supabase migration
--
-- Creates support_requests table (Flutter requestor app schema), RLS, and storage
-- policies for Know How / Commissioning submit + My Support Requests list/detail.
--
-- Replaces an empty legacy support_requests table (requesterId/subject schema) if present.
--
-- Apply:
--   ./scripts/db.sh migrate-support
--
-- Verify:
--   ./scripts/db.sh verify-support

BEGIN;

-- ---------------------------------------------------------------------------
-- Drop legacy policies (React / older schema naming)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Admins manage support_requests" ON public.support_requests;
DROP POLICY IF EXISTS "Requestors read own support_requests" ON public.support_requests;
DROP POLICY IF EXISTS "Requestors insert own support_requests" ON public.support_requests;
DROP POLICY IF EXISTS "Requestors insert own support requests" ON public.support_requests;
DROP POLICY IF EXISTS "Requestors read own support requests" ON public.support_requests;
DROP POLICY IF EXISTS "Admins read all support requests" ON public.support_requests;
DROP POLICY IF EXISTS "Admins update support requests" ON public.support_requests;

-- ---------------------------------------------------------------------------
-- Replace legacy empty table with Flutter app schema
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'support_requests'
      AND column_name = 'createdBy'
  ) THEN
    RAISE NOTICE 'support_requests already has Flutter schema (createdBy); skipping table recreate';
  ELSE
    IF EXISTS (SELECT 1 FROM public.support_requests LIMIT 1) THEN
      RAISE EXCEPTION
        'support_requests uses legacy schema and contains rows; manual migration required';
    END IF;

    DROP TABLE IF EXISTS public.support_requests CASCADE;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.support_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL CHECK (type IN ('knowHow', 'commissioning')),
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'open', 'inProgress', 'resolved', 'closed')),
  summary text,
  topic text,
  question text,
  details text,
  "chargerModel" text,
  "chargerSerialNumber" text,
  address text,
  country text,
  "scheduledDate" timestamptz,
  attachments jsonb NOT NULL DEFAULT '[]'::jsonb,
  "createdBy" text NOT NULL REFERENCES public.users (id),
  "createdAt" timestamptz NOT NULL DEFAULT now(),
  "companyId" text REFERENCES public.companies (id),
  "staffReply" text
);

ALTER TABLE public.support_requests
  ADD COLUMN IF NOT EXISTS "staffReply" text;

COMMENT ON TABLE public.support_requests IS
  'Be Electric Know How and Commissioning support requests from the requestor app.';

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS support_requests_created_by_idx
  ON public.support_requests ("createdBy");

CREATE INDEX IF NOT EXISTS support_requests_company_id_idx
  ON public.support_requests ("companyId");

CREATE INDEX IF NOT EXISTS support_requests_type_idx
  ON public.support_requests (type);

CREATE INDEX IF NOT EXISTS support_requests_created_at_idx
  ON public.support_requests ("createdAt" DESC);

-- ---------------------------------------------------------------------------
-- Grants (RLS still applies)
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT ON public.support_requests TO authenticated;
GRANT ALL ON public.support_requests TO service_role;

-- ---------------------------------------------------------------------------
-- RLS — requestors (required for submit + My Support Requests)
-- ---------------------------------------------------------------------------

ALTER TABLE public.support_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Requestors insert own support requests"
  ON public.support_requests;
CREATE POLICY "Requestors insert own support requests"
  ON public.support_requests
  FOR INSERT
  TO authenticated
  WITH CHECK ("createdBy" = auth.uid()::text);

DROP POLICY IF EXISTS "Requestors read own support requests"
  ON public.support_requests;
CREATE POLICY "Requestors read own support requests"
  ON public.support_requests
  FOR SELECT
  TO authenticated
  USING ("createdBy" = auth.uid()::text);

-- ---------------------------------------------------------------------------
-- RLS — admin / manager (staff reply + back-office; requires get_my_role())
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF to_regprocedure('public.get_my_role()') IS NULL THEN
    RAISE NOTICE
      'public.get_my_role() not found — skipping admin support_requests policies. '
      'Run CMMS user-role migrations first, then re-apply this script.';
    RETURN;
  END IF;

  EXECUTE $policy$
    DROP POLICY IF EXISTS "Admins manage support_requests"
      ON public.support_requests
  $policy$;
  EXECUTE $policy$
    CREATE POLICY "Admins manage support_requests"
      ON public.support_requests
      FOR ALL
      TO authenticated
      USING (public.get_my_role() = ANY (ARRAY['admin', 'manager']))
      WITH CHECK (public.get_my_role() = ANY (ARRAY['admin', 'manager']))
  $policy$;

  GRANT SELECT, INSERT, UPDATE, DELETE ON public.support_requests TO authenticated;
END $$;

-- ---------------------------------------------------------------------------
-- Storage — files/support_requests/{supportRequestId}/{fileName}
-- Uses upsert:true in the Flutter client (INSERT + UPDATE).
-- Public read uses getPublicUrl on the existing `files` bucket.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Authenticated upload support request attachments"
  ON storage.objects;
CREATE POLICY "Authenticated upload support request attachments"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'files'
    AND (storage.foldername(name))[1] = 'support_requests'
  );

DROP POLICY IF EXISTS "Authenticated update support request attachments"
  ON storage.objects;
CREATE POLICY "Authenticated update support request attachments"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'files'
    AND (storage.foldername(name))[1] = 'support_requests'
  )
  WITH CHECK (
    bucket_id = 'files'
    AND (storage.foldername(name))[1] = 'support_requests'
  );

COMMIT;

-- Post-migration sanity output
SELECT
  to_regclass('public.support_requests') IS NOT NULL AS table_exists,
  (
    SELECT relrowsecurity
    FROM pg_class
    WHERE oid = 'public.support_requests'::regclass
  ) AS rls_enabled;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'support_requests'
ORDER BY ordinal_position;

SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'support_requests'
ORDER BY policyname;

SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname ILIKE '%support request%'
ORDER BY policyname;
