-- ============================================================
-- Fix recurring-task bugs:
--   1. Remove accumulated overloads of create_task_occurrence /
--      create_recurring_task_template (risk of 42725 "function is
--      not unique" when calling RPC with a partial parameter set).
--   2. Restore RLS hardening that 20260727_fix_rls_security.sql
--      intended (it runs BEFORE initial_schema in alphabetical order,
--      so on fresh DBs it's skipped): drop the permissive profile
--      policy, keep auth.uid()/membership checks in
--      generate_recurring_task_occurrences and
--      get_household_name_for_invitation, and ensure the household
--      invitations SELECT policy exists.
--   3. generate_recurring_task_occurrences now accepts p_from_date:
--      generation starts at that date (or start_date when NULL).
--      Fixes update_task_template creating spurious future instances
--      in the past segment for scope 'this_and_following'.
--   4. update_task_template regenerates from reshape_from, not from
--      the series start.
--   5. Canonical hardened leave_household / remove_household_member
--      (cleanup of allowed_members/pinned when a member leaves).
-- ============================================================

-- ============================================================
-- 1. Drop stale overloads (keep only the current planned_time one).
-- ============================================================
DROP FUNCTION IF EXISTS public.create_task_occurrence(
  UUID, TEXT, TEXT, INTEGER, DATE, TIMESTAMPTZ
);
DROP FUNCTION IF EXISTS public.create_task_occurrence(
  UUID, TEXT, TEXT, INTEGER, DATE, TIMESTAMPTZ, INTEGER
);
DROP FUNCTION IF EXISTS public.create_task_occurrence(
  UUID, TEXT, TEXT, INTEGER, DATE, TIMESTAMPTZ, INTEGER, INTEGER, UUID
);
DROP FUNCTION IF EXISTS public.create_recurring_task_template(
  UUID, TEXT, TEXT, INTEGER, DATE, TIME, recurrence_type, INTEGER,
  SMALLINT[], DATE
);
DROP FUNCTION IF EXISTS public.create_recurring_task_template(
  UUID, TEXT, TEXT, INTEGER, DATE, recurrence_type, TIME, INTEGER,
  SMALLINT[], DATE, TIMESTAMPTZ, INTEGER
);
DROP FUNCTION IF EXISTS public.create_recurring_task_template(
  UUID, TEXT, TEXT, INTEGER, DATE, recurrence_type, TIME, INTEGER,
  SMALLINT[], DATE, TIMESTAMPTZ, INTEGER, INTEGER, UUID
);

-- ============================================================
-- 2. RLS hardening that 20260727_fix_rls_security.sql would have
--    applied but couldn't (it runs BEFORE initial_schema in the
--    alphabetical apply order, so it fails on fresh setups and is
--    skipped). initial_schema created the permissive profile policy;
--    replace it with the "household members only" policy.
-- ============================================================
DROP POLICY IF EXISTS "Profiles visible to authenticated users" ON profiles;
DROP POLICY IF EXISTS "Profiles visible to household members" ON profiles;
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

-- ============================================================
-- 3. generate_recurring_task_occurrences — add p_from_date
-- ============================================================
DROP FUNCTION IF EXISTS public.generate_recurring_task_occurrences(DATE);

CREATE OR REPLACE FUNCTION generate_recurring_task_occurrences(
  p_until_date DATE,
  p_from_date DATE DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  task_template public.task_templates;
  occurrence_date date;
  generated_count integer := 0;
  occurrence_deadline timestamptz;
  generate_from date;
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
      -- Только шаблоны семей, где пользователь состоит (защита от перебора всех семей)
      and exists (
        select 1 from public.household_members
        where household_id = task_templates.household_id
          and profile_id = auth.uid()
      )
  loop
    -- Начинаем генерацию либо с явно указанной даты (p_from_date),
    -- либо с начала серии. Пропускаем уже существующие даты (ON CONFLICT).
    generate_from := greatest(
      coalesce(p_from_date, task_template.recurrence_start_date),
      current_date
    );

    for occurrence_date in
      select generated_day::date
      from generate_series(
        generate_from,
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
          planned_for, deadline_at, priority, planned_time
        )
        values (
          task_template.household_id, task_template.id, task_template.category_id,
          task_template.created_by, task_template.title, task_template.description,
          task_template.estimated_duration_minutes, occurrence_date, occurrence_deadline,
          task_template.priority, task_template.planned_time
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

COMMENT ON FUNCTION generate_recurring_task_occurrences(DATE, DATE) IS
  'Генерирует экземпляры повторяющихся задач до p_until_date. p_from_date (необязательно) ограничивает генерацию снизу: по умолчанию — начало серии.';

-- ============================================================
-- 4. create_recurring_task_template — regenerate explicitly from
--    p_start_date (default behaviour preserved).
-- ============================================================
CREATE OR REPLACE FUNCTION create_recurring_task_template(
  p_household_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_estimated_duration_minutes INTEGER,
  p_start_date DATE,
  p_recurrence_type recurrence_type,
  p_deadline_time TIME DEFAULT NULL,
  p_interval_days INTEGER DEFAULT NULL,
  p_weekdays SMALLINT[] DEFAULT '{}',
  p_end_date DATE DEFAULT NULL,
  p_deadline_at TIMESTAMPTZ DEFAULT NULL,
  p_priority INT DEFAULT NULL,
  p_reminder_minutes_before INT DEFAULT NULL,
  p_category_id UUID DEFAULT NULL,
  p_planned_time TIME DEFAULT NULL
)
RETURNS task_occurrences
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  created_template public.task_templates;
  first_occurrence public.task_occurrences;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация.';
  end if;

  if not public.is_household_member(p_household_id) then
    raise exception 'Вы не состоите в этой семье.';
  end if;

  if char_length(trim(p_title)) = 0 then
    raise exception 'Название задачи не может быть пустым.';
  end if;

  if p_estimated_duration_minutes <= 0 then
    raise exception 'Длительность должна быть больше нуля.';
  end if;

  if p_recurrence_type = 'none' then
    raise exception 'Для повторяющейся задачи выберите тип повтора.';
  end if;

  if p_recurrence_type = 'interval_days' and (p_interval_days is null or p_interval_days <= 0) then
    raise exception 'Интервал повторения должен быть больше нуля.';
  end if;

  if p_recurrence_type = 'weekly' and cardinality(p_weekdays) = 0 then
    raise exception 'Выберите хотя бы один день недели.';
  end if;

  if p_end_date is not null and p_end_date < p_start_date then
    raise exception 'Дата окончания не может быть раньше даты начала.';
  end if;

  insert into public.task_templates (
    household_id, created_by, title, description,
    estimated_duration_minutes, deadline_time,
    recurrence_type, interval_days, weekdays,
    recurrence_start_date, recurrence_end_date, is_active, priority, category_id,
    planned_time
  )
  values (
    p_household_id, auth.uid(), trim(p_title),
    nullif(trim(p_description), ''),
    p_estimated_duration_minutes, p_deadline_time,
    p_recurrence_type,
    case when p_recurrence_type = 'interval_days' then p_interval_days else null end,
    case when p_recurrence_type = 'weekly' then p_weekdays else '{}' end,
    p_start_date, p_end_date, true, p_priority, p_category_id,
    p_planned_time
  )
  returning * into created_template;

  insert into public.task_template_allowed_members (task_template_id, profile_id)
  values (created_template.id, auth.uid());

  perform public.generate_recurring_task_occurrences(
    greatest(current_date, p_start_date) + 30,
    p_start_date
  );

  select * into first_occurrence
  from public.task_occurrences
  where template_id = created_template.id
  order by planned_for
  limit 1;

  if first_occurrence is null then
    raise exception 'Не удалось создать первый экземпляр повторяющейся задачи.';
  end if;

  -- Напоминание настраивается per-instance: применяем к первому экземпляру серии.
  if p_reminder_minutes_before is not null then
    update public.task_occurrences
    set reminder_minutes_before = p_reminder_minutes_before
    where id = first_occurrence.id;
  end if;

  return first_occurrence;
end;
$$;

COMMENT ON FUNCTION create_recurring_task_template IS
  'Создаёт повторяющуюся задачу (шаблон + первый экземпляр). Параметры повторения и напоминание применяются к первому экземпляру.';

-- ============================================================
-- 5. update_task_template — regenerate from reshape_from, not
--    from the series start (fixes spurious instances in the past
--    segment for scope 'this_and_following').
-- ============================================================
CREATE OR REPLACE FUNCTION update_task_template(
  p_task_occurrence_id UUID,
  p_scope TEXT,
  p_title TEXT,
  p_description TEXT,
  p_estimated_duration_minutes INTEGER,
  p_deadline_time TIME DEFAULT NULL,
  p_deadline_at TIMESTAMPTZ DEFAULT NULL,
  p_recurrence_type recurrence_type DEFAULT 'none',
  p_interval_days INTEGER DEFAULT NULL,
  p_weekdays SMALLINT[] DEFAULT '{}',
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_priority INT DEFAULT NULL,
  p_assigned_member_id UUID DEFAULT NULL,
  p_pinned_member_id UUID DEFAULT NULL,
  p_add_allowed_member_ids UUID[] DEFAULT '{}',
  p_new_start_date DATE DEFAULT NULL,
  p_category_id UUID DEFAULT NULL,
  p_planned_time TIME DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  target_template public.task_templates;
  target_occurrence public.task_occurrences;
  from_date date;
  reshape_from date;
  schedule_changed boolean;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация.';
  end if;

  select o.* into target_occurrence
  from public.task_occurrences o
  where o.id = p_task_occurrence_id;

  if target_occurrence is null then
    raise exception 'Задача не найдена.';
  end if;

  if not public.is_household_member(target_occurrence.household_id) then
    raise exception 'Вы не состоите в этой семье.';
  end if;

  select t.* into target_template
  from public.task_templates t
  where t.id = target_occurrence.template_id;

  if target_template is null then
    raise exception 'Это не повторяющаяся задача.';
  end if;

  if char_length(trim(p_title)) = 0 then
    raise exception 'Название задачи не может быть пустым.';
  end if;

  if p_estimated_duration_minutes <= 0 then
    raise exception 'Длительность должна быть больше нуля.';
  end if;

  -- ── only_this: update just the edited occurrence ─────────────
  if p_scope = 'only_this' then
    update public.task_occurrences
    set title = trim(p_title),
        description = nullif(trim(p_description), ''),
        estimated_duration_minutes = p_estimated_duration_minutes,
        deadline_at = p_deadline_at,
        priority = p_priority,
        assigned_member_id = p_assigned_member_id,
        pinned_member_id = p_pinned_member_id,
        category_id = p_category_id,
        planned_time = p_planned_time
    where id = p_task_occurrence_id;

    if cardinality(p_add_allowed_member_ids) > 0 then
      insert into public.task_occurrence_allowed_members (task_occurrence_id, profile_id)
      select p_task_occurrence_id, member_id
      from unnest(p_add_allowed_member_ids) as member_id
      on conflict (task_occurrence_id, profile_id) do nothing;
    end if;

    return;
  end if;

  if p_scope not in ('this_and_following', 'all') then
    raise exception 'Неизвестная область применения: %', p_scope;
  end if;

  if p_recurrence_type = 'none' then
    raise exception 'У повторяющейся задачи должен быть выбран тип повтора.';
  end if;

  if p_recurrence_type = 'interval_days' and (p_interval_days is null or p_interval_days <= 0) then
    raise exception 'Интервал повторения должен быть больше нуля.';
  end if;

  if p_recurrence_type = 'weekly' and cardinality(p_weekdays) = 0 then
    raise exception 'Выберите хотя бы один день недели.';
  end if;

  if p_start_date is null then
    raise exception 'Укажите дату начала повторения.';
  end if;

  if p_end_date is not null and p_end_date < p_start_date then
    raise exception 'Дата окончания не может быть раньше даты начала.';
  end if;

  -- Перенос серии целиком: сдвигаем начало повторения.
  if p_new_start_date is not null then
    if p_scope = 'this_and_following' then
      raise exception 'Перенос на новую дату доступен только для всей серии (все).';
    end if;

    if p_new_start_date < target_template.recurrence_start_date then
      raise exception 'Новая дата начала не может быть раньше текущей.';
    end if;

    -- Сдвигаем экземпляры серии на ту же дату.
    update public.task_occurrences
    set planned_for = planned_for + (p_new_start_date - target_template.recurrence_start_date),
        deadline_at = case
          when deadline_at is null then null
          else deadline_at + (p_new_start_date - target_template.recurrence_start_date) * interval '1 day'
        end
    where template_id = target_template.id
      and planned_for >= target_template.recurrence_start_date;

    p_start_date := p_new_start_date;
  end if;

  -- Начало области изменений:
  --   all                → от начала серии
  --   this_and_following → от даты редактируемого экземпляра
  from_date := case
    when p_scope = 'all' then p_start_date
    else target_occurrence.planned_for
  end;

  -- Перестраиваем расписание только с сегодняшнего дня (историю не трогаем).
  reshape_from := greatest(from_date, current_date);

  schedule_changed :=
    p_recurrence_type <> target_template.recurrence_type
    or p_interval_days is distinct from target_template.interval_days
    or p_weekdays is distinct from target_template.weekdays
    or p_start_date is distinct from target_template.recurrence_start_date
    or p_end_date is distinct from target_template.recurrence_end_date;

  -- 1. Обновляем шаблон
  update public.task_templates
  set title = trim(p_title),
      description = nullif(trim(p_description), ''),
      estimated_duration_minutes = p_estimated_duration_minutes,
      deadline_time = p_deadline_time,
      recurrence_type = p_recurrence_type,
      interval_days = case when p_recurrence_type = 'interval_days' then p_interval_days else null end,
      weekdays = case when p_recurrence_type = 'weekly' then p_weekdays else '{}' end,
      recurrence_start_date = p_start_date,
      recurrence_end_date = p_end_date,
      priority = p_priority,
      category_id = p_category_id,
      planned_time = p_planned_time
  where id = target_template.id;

  -- 2. Метаданные (заголовок/длительность/приоритет/дедлайн/время начала) в зоне изменений
  update public.task_occurrences
  set title = trim(p_title),
      description = nullif(trim(p_description), ''),
      estimated_duration_minutes = p_estimated_duration_minutes,
      priority = p_priority,
      category_id = p_category_id,
      deadline_at = case
        when p_deadline_time is null then null
        else (planned_for + p_deadline_time) at time zone 'Europe/Moscow'
      end,
      planned_time = p_planned_time
  where template_id = target_template.id
    and planned_for >= from_date;

  -- 3. Назначение ответственного применяем только к редактируемому экземпляру
  update public.task_occurrences
  set assigned_member_id = p_assigned_member_id,
      pinned_member_id = p_pinned_member_id
  where id = p_task_occurrence_id;

  if cardinality(p_add_allowed_member_ids) > 0 then
    insert into public.task_occurrence_allowed_members (task_occurrence_id, profile_id)
    select p_task_occurrence_id, member_id
    from unnest(p_add_allowed_member_ids) as member_id
    on conflict (task_occurrence_id, profile_id) do nothing;
  end if;

  -- 4. Расписание изменилось → перестраиваем будущие экземпляры
  if schedule_changed then
    -- Удаляем отложенные экземпляры, не подходящие под новый график.
    -- Редактируемый экземпляр не удаляем, выполненные — сохраняем (история).
    delete from public.task_occurrences
    where template_id = target_template.id
      and id <> p_task_occurrence_id
      and planned_for >= reshape_from
      and status = 'pending'
      and not (
        p_recurrence_type = 'daily'
        or (
          p_recurrence_type = 'weekly'
          and extract(isodow from planned_for)::smallint = any(p_weekdays)
        )
        or (
          p_recurrence_type = 'interval_days'
          and mod(planned_for - p_start_date, p_interval_days) = 0
        )
      );

    -- Догенерируем недостающие даты под новое расписание,
    -- начиная с зоны изменений (а не с начала серии).
    perform public.generate_recurring_task_occurrences(
      current_date + 30,
      reshape_from
    );
  end if;
end;
$$;

COMMENT ON FUNCTION update_task_template IS
  'Обновляет повторяющуюся задачу (шаблон + экземпляры) с учётом области применения: only_this, this_and_following, all. Поддерживает перенос серии (p_new_start_date) и время начала (p_planned_time).';

-- ============================================================
-- 6. pause_task_template / resume_task_template — update the
--    generate call to the new signature (adds p_from_date=NULL).
--    (resume regenerates from the series start, as before.)
-- ============================================================
CREATE OR REPLACE FUNCTION resume_task_template(p_task_template_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  target_household_id uuid;
  generated_count integer;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация.';
  end if;

  select household_id into target_household_id
  from public.task_templates where id = p_task_template_id;

  if target_household_id is null then
    raise exception 'Повторяющаяся задача не найдена.';
  end if;

  if not public.is_household_member(target_household_id) then
    raise exception 'Вы не состоите в этой семье.';
  end if;

  update public.task_templates set is_active = true where id = p_task_template_id;

  -- Догенерируем экземпляры на 30 дней вперёд (как при создании серии).
  select public.generate_recurring_task_occurrences(current_date + 30)
    into generated_count;
  return generated_count;
end;
$$;

COMMENT ON FUNCTION resume_task_template IS
  'Возобновляет повторяющуюся задачу: is_active=true и догенерирует экземпляры на 30 дней вперёд.';

-- ============================================================
-- 7. Canonical RLS hardening (restores what fix_rls_security intended,
--    which is skipped on fresh DBs due to alphabetical order) and the
--    hardened household functions. These run LAST, so the end state is
--    correct regardless of apply order.
-- ============================================================

-- get_household_name_for_invitation — только приглашённому или владельцу
-- (исправляет: любой authenticated мог получить имя любой семьи по UUID).
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

-- household_invitations: invited users видят свои приглашения,
-- owners видят приглашения в свои семьи.
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

-- leave_household / remove_household_member: очистка allowed members
-- и снятие назначений/закреплений при выходе из семьи.
CREATE OR REPLACE FUNCTION leave_household(p_household_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
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
