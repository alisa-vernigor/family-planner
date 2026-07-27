-- ============================================================
-- Fix: cleanup allowed_members when member leaves household
-- ============================================================

CREATE OR REPLACE FUNCTION leave_household(p_household_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  current_user_id uuid;
  is_owner boolean;
begin
  current_user_id := auth.uid();

  if current_user_id is null then
    raise exception 'Требуется авторизация.';
  end if;

  -- Проверяем, является ли пользователь владельцем
  select role = 'owner' into is_owner
  from public.household_members
  where household_id = p_household_id and profile_id = current_user_id;

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
$$;

-- Аналогично для remove_household_member
CREATE OR REPLACE FUNCTION remove_household_member(p_household_id UUID, p_profile_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
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
$$;
