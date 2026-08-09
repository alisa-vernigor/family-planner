-- ============================================================
-- Fix: cleanup allowed_members when member leaves household
--
-- NOTE: this file sorts BEFORE 20260727_initial_schema.sql in the
-- alphabetical (chronological) migration order. On a fresh
-- `supabase db reset` the tables don't exist yet, so everything is
-- wrapped in a guarded DO block that becomes a no-op until the
-- schema exists. The final hardened definitions also live in
-- 20260809_fix_recurring_overloads_and_duplicates.sql, so the end
-- state is correct regardless of apply order.
-- ============================================================

DO $$
BEGIN
  -- Guard: need tables from initial_schema before we can define these.
  IF to_regclass('public.task_occurrences') IS NULL
     OR to_regclass('public.household_members') IS NULL THEN
    RAISE NOTICE 'fix_leave_household: initial_schema not applied yet, skipping';
    RETURN;
  END IF;

  EXECUTE $f1$
    CREATE OR REPLACE FUNCTION leave_household(p_household_id UUID)
    RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
    AS $body$
    declare
      current_user_id uuid;
    begin
      current_user_id := auth.uid();

      if current_user_id is null then
        raise exception 'Требуется авторизация.';
      end if;

      -- Очищаем allowed members
      delete from public.task_occurrence_allowed_members
      where profile_id = current_user_id
        and task_occurrence_id in (
          select id from public.task_occurrences
          where household_id = p_household_id
        );

      -- Снимаем назначения и закрепления с задач в этой семье
      update public.task_occurrences
      set
        assigned_member_id = case when assigned_member_id = current_user_id then null else assigned_member_id end,
        pinned_member_id = case when pinned_member_id = current_user_id then null else pinned_member_id end
      where household_id = p_household_id
        and (assigned_member_id = current_user_id or pinned_member_id = current_user_id);

      -- Выход из семьи
      delete from public.household_members
      where household_id = p_household_id and profile_id = current_user_id;
    end;
    $body$;
  $f1$;

  EXECUTE $f2$
    CREATE OR REPLACE FUNCTION remove_household_member(p_household_id UUID, p_profile_id UUID)
    RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
    AS $body$
    begin
      if not public.is_household_owner(p_household_id) then
        raise exception 'Only owner can remove members';
      end if;

      -- Очищаем allowed members
      delete from public.task_occurrence_allowed_members
      where profile_id = p_profile_id
        and task_occurrence_id in (
          select id from public.task_occurrences
          where household_id = p_household_id
        );

      -- Снимаем назначения
      update public.task_occurrences
      set
        assigned_member_id = case when assigned_member_id = p_profile_id then null else assigned_member_id end,
        pinned_member_id = case when pinned_member_id = p_profile_id then null else pinned_member_id end
      where household_id = p_household_id
        and (assigned_member_id = p_profile_id or pinned_member_id = p_profile_id);

      delete from public.household_members
      where household_id = p_household_id and profile_id = p_profile_id;
    end;
    $body$;
  $f2$;
END $$;
