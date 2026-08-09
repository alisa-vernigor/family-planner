-- ============================================================
-- Security fixes: RLS hardening
--
-- NOTE: this file sorts BEFORE 20260727_initial_schema.sql in the
-- alphabetical (chronological) migration order, but references tables
-- that only exist after that snapshot. On a fresh `supabase db reset`
-- it therefore runs before the tables exist and must degrade to a
-- no-op (everything below is wrapped in a guarded DO block). The same
-- hardening is re-applied by the latest migration
-- 20260809_fix_recurring_overloads_and_duplicates.sql, which runs
-- last on every database.
-- ============================================================

DO $$
BEGIN
  IF to_regclass('public.profiles') IS NULL
     OR to_regclass('public.households') IS NULL
     OR to_regclass('public.household_invitations') IS NULL THEN
    RAISE NOTICE 'fix_rls_security: initial_schema not applied yet, skipping';
    RETURN;
  END IF;

  -- 1. Profiles: authenticated users can only see profiles of household members
  --    (было: ALL authenticated users can read ALL profiles — enumeration vector)
  EXECUTE 'DROP POLICY IF EXISTS "Profiles visible to authenticated users" ON profiles';
  EXECUTE $pol1$
    CREATE POLICY "Profiles visible to household members"
      ON profiles FOR SELECT TO authenticated
      USING (
        -- Пользователь видит свой профиль
        id = auth.uid()
        -- Или профили членов своих семей
        OR EXISTS (
          SELECT 1 FROM household_members hm1
          WHERE hm1.profile_id = auth.uid()
            AND EXISTS (
              SELECT 1 FROM household_members hm2
              WHERE hm2.household_id = hm1.household_id
                AND hm2.profile_id = profiles.id
            )
        )
      )
  $pol1$;

  -- 2. Household invitations: RLS для прямых SELECT-запросов
  --    (было: ENABLE ROW LEVEL SECURITY без политик → все запросы блокируются)
  --    Нужно: invited users видят свои приглашения; owners видят приглашения в свои семьи
  EXECUTE 'DROP POLICY IF EXISTS "Users view own invitations" ON household_invitations';
  EXECUTE $pol2$
    CREATE POLICY "Users view own invitations"
      ON household_invitations FOR SELECT TO authenticated
      USING (
        invited_profile_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM household_members
          WHERE household_members.household_id = household_invitations.household_id
            AND household_members.profile_id = auth.uid()
            AND household_members.role = 'owner'
        )
      )
  $pol2$;

  -- 3. get_household_name_for_invitation — добавить проверку auth.uid()
  --    (было: любой authenticated может получить имя любой семьи по UUID)
  EXECUTE $f3$
    CREATE OR REPLACE FUNCTION get_household_name_for_invitation(p_household_id UUID)
    RETURNS TEXT
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
    AS $body$
      -- Разрешено: самому приглашённому или владельцу семьи
      select name from public.households
      where id = p_household_id
        and (
          exists (
            select 1 from public.household_invitations
            where household_id = p_household_id
              and invited_profile_id = auth.uid()
              and status = 'pending'
          )
          or exists (
            select 1 from public.household_members
            where household_id = p_household_id
              and profile_id = auth.uid()
              and role = 'owner'
          )
        );
    $body$;
  $f3$;
END $$;
