-- Be Electric Support Requests (Supabase CLI migration)
-- Canonical copy: scripts/sql/migrate_support_requests.sql

BEGIN;

DROP POLICY IF EXISTS "Admins manage support_requests" ON public.support_requests;
DROP POLICY IF EXISTS "Requestors read own support_requests" ON public.support_requests;
DROP POLICY IF EXISTS "Requestors insert own support_requests" ON public.support_requests;
DROP POLICY IF EXISTS "Requestors insert own support requests" ON public.support_requests;
DROP POLICY IF EXISTS "Requestors read own support requests" ON public.support_requests;
DROP POLICY IF EXISTS "Admins read all support requests" ON public.support_requests;
DROP POLICY IF EXISTS "Admins update support requests" ON public.support_requests;

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

CREATE INDEX IF NOT EXISTS support_requests_created_by_idx
  ON public.support_requests ("createdBy");

CREATE INDEX IF NOT EXISTS support_requests_company_id_idx
  ON public.support_requests ("companyId");

CREATE INDEX IF NOT EXISTS support_requests_type_idx
  ON public.support_requests (type);

CREATE INDEX IF NOT EXISTS support_requests_created_at_idx
  ON public.support_requests ("createdAt" DESC);

GRANT SELECT, INSERT ON public.support_requests TO authenticated;
GRANT ALL ON public.support_requests TO service_role;

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

DO $$
BEGIN
  IF to_regprocedure('public.get_my_role()') IS NULL THEN
    RAISE NOTICE
      'public.get_my_role() not found — skipping admin support_requests policies.';
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
