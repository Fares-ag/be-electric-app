-- Verify technicians can INSERT charger assets (field-added chargers).

SELECT
  pol.polname AS policy_name,
  pol.polcmd AS command
FROM pg_policy pol
JOIN pg_class rel ON rel.oid = pol.polrelid
JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE nsp.nspname = 'public'
  AND rel.relname = 'assets'
  AND pol.polname = 'Technicians add field chargers';
