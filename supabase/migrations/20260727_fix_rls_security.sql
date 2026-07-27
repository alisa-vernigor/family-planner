-- ============================================================
-- Security fixes: RLS hardening
-- ============================================================

-- 1. Profiles: authenticated users can only see profiles of household members
--    (было: ALL authenticated users can read ALL profiles — enumeration vector)
DROP POLICY IF EXISTS "Profiles visible to authenticated users" ON profiles;
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
  );

-- 2. Household invitations: RLS для прямых SELECT-запросов
--    (было: ENABLE ROW LEVEL SECURITY без политик → все запросы блокируются)
--    Нужно: invited users видят свои приглашения; owners видят приглашения в свои семьи
DROP POLICY IF EXISTS "Users view own invitations" ON household_invitations;
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
  );

-- 3. get_household_name_for_invitation — добавить проверку auth.uid()
--    (было: любой authenticated может получить имя любой семьи по UUID)
CREATE OR REPLACE FUNCTION get_household_name_for_invitation(p_household_id UUID)
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
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
$$;

-- 4. generate_recurring_task_occurrences — добавить проверку auth.uid()
--    (было: любой authenticated может запустить генерацию для ВСЕХ семей)
CREATE OR REPLACE FUNCTION generate_recurring_task_occurrences(p_until_date DATE)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  task_template public.task_templates;
  occurrence_date date;
  generated_count integer := 0;
  occurrence_deadline timestamptz;
begin
  if p_until_date < current_date then
    raise exception 'Дата генерации не может быть раньше сегодняшнего дня.';
  end if;

  if auth.uid() is null then
    raise exception 'Требуется авторизация.';
  end if;

  for task_template in
    select * from public.task_templates
    where is_active = true
      and recurrence_type <> 'none'
      and recurrence_start_date is not null
      and (recurrence_end_date is null or recurrence_end_date >= current_date)
      -- Только шаблоны семей, где пользователь состоит
      and exists (
        select 1 from public.household_members
        where household_id = task_templates.household_id
          and profile_id = auth.uid()
      )
  loop
    for occurrence_date in
      select generated_day::date
      from generate_series(
        greatest(task_template.recurrence_start_date, current_date),
        least(p_until_date, coalesce(task_template.recurrence_end_date, p_until_date)),
        interval '1 day'
      ) as generated_day
    loop
      if (
        task_template.recurrence_type = 'daily'
        or (
          task_template.recurrence_type = 'weekly'
          and extract(isodow from occurrence_date)::smallint = any(task_template.weekdays)
        )
        or (
          task_template.recurrence_type = 'interval_days'
          and mod(occurrence_date - task_template.recurrence_start_date, task_template.interval_days) = 0
        )
      ) then
        occurrence_deadline := case
          when task_template.deadline_time is null then null
          else (occurrence_date + task_template.deadline_time) at time zone 'Europe/Moscow'
        end;

        insert into public.task_occurrences (
          household_id, template_id, category_id, created_by,
          title, description, estimated_duration_minutes,
          planned_for, deadline_at
        )
        values (
          task_template.household_id, task_template.id, task_template.category_id,
          task_template.created_by, task_template.title, task_template.description,
          task_template.estimated_duration_minutes, occurrence_date, occurrence_deadline
        )
        on conflict (template_id, planned_for) where template_id is not null
        do nothing;

        if found then
          insert into public.task_occurrence_allowed_members (task_occurrence_id, profile_id)
          select occurrence.id, allowed_member.profile_id
          from public.task_occurrences as occurrence
          inner join public.task_template_allowed_members as allowed_member
            on allowed_member.task_template_id = task_template.id
          where occurrence.template_id = task_template.id
            and occurrence.planned_for = occurrence_date
          on conflict do nothing;

          generated_count := generated_count + 1;
        end if;
      end if;
    end loop;
  end loop;

  return generated_count;
end;
$$;
