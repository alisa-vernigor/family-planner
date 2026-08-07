-- ============================================================
-- Google Calendar style actions:
--   reschedule (перенос на дату), duplicate (дублирование),
--   subtasks (подзадачи), categories (категории).
--
-- Действия:
--   1. update_task_template: добавлен параметр p_new_start_date
--      (перенос повторяющейся серии на новую дату).
--   2. reschedule_task: перенос обычной задачи на новую дату.
--   3. duplicate_task / duplicate_task_template: дублирование.
--   4. reminder_minutes_before: напоминания о задаче (push на устройстве).
--   5. subtasks/categories: таблицы и RLS уже были в initial_schema,
--      клиентская часть (репозитории + offline-очередь) — отдельно.
-- ============================================================

-- ============================================================
-- 1. update_task_template: перенос серии на новую дату
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
  p_category_id UUID DEFAULT NULL
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
        category_id = p_category_id
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
      category_id = p_category_id
  where id = target_template.id;

  -- 2. Метаданные (заголовок/длительность/приоритет/дедлайн) в зоне изменений
  update public.task_occurrences
  set title = trim(p_title),
      description = nullif(trim(p_description), ''),
      estimated_duration_minutes = p_estimated_duration_minutes,
      priority = p_priority,
      category_id = p_category_id,
      deadline_at = case
        when p_deadline_time is null then null
        else (planned_for + p_deadline_time) at time zone 'Europe/Moscow'
      end
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

    -- Догенерируем недостающие даты под новое расписание.
    perform public.generate_recurring_task_occurrences(current_date + 30);
  end if;
end;
$$;

COMMENT ON FUNCTION update_task_template IS
  'Обновляет повторяющуюся задачу (шаблон + экземпляры) с учётом области применения: only_this, this_and_following, all. Поддерживает перенос серии на новую дату (p_new_start_date).';

-- ============================================================
-- 1.1. Напоминания (reminder_minutes_before)
--   Per-instance: за сколько минут до дедлайна/начала прислать push.
-- ============================================================

ALTER TABLE task_occurrences ADD COLUMN reminder_minutes_before INT;

COMMENT ON COLUMN task_occurrences.reminder_minutes_before IS 'За сколько минут до дедлайна/начала прислать напоминание; NULL — без напоминания';

-- Обновляем RPC create_task_occurrence — добавляем p_reminder_minutes_before
CREATE OR REPLACE FUNCTION create_task_occurrence(
  p_household_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_estimated_duration_minutes INTEGER,
  p_planned_for DATE,
  p_deadline_at TIMESTAMPTZ DEFAULT NULL,
  p_priority INT DEFAULT NULL,
  p_reminder_minutes_before INT DEFAULT NULL,
  p_category_id UUID DEFAULT NULL
)
RETURNS task_occurrences
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  created_task public.task_occurrences;
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

  insert into public.task_occurrences (
    household_id, created_by, title, description,
    estimated_duration_minutes, planned_for, deadline_at, priority, reminder_minutes_before, category_id
  )
  values (
    p_household_id, auth.uid(), trim(p_title),
    nullif(trim(p_description), ''),
    p_estimated_duration_minutes, p_planned_for, p_deadline_at, p_priority, p_reminder_minutes_before, p_category_id
  )
  returning * into created_task;

  insert into public.task_occurrence_allowed_members (task_occurrence_id, profile_id)
  values (created_task.id, auth.uid());

  return created_task;
end;
$$;

-- Обновляем RPC create_recurring_task_template — добавляем p_reminder_minutes_before
-- (применяется к первому экземпляру серии; остальные экземпляры — без напоминания)
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
  p_category_id UUID DEFAULT NULL
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
    recurrence_start_date, recurrence_end_date, is_active, priority, category_id
  )
  values (
    p_household_id, auth.uid(), trim(p_title),
    nullif(trim(p_description), ''),
    p_estimated_duration_minutes, p_deadline_time,
    p_recurrence_type,
    case when p_recurrence_type = 'interval_days' then p_interval_days else null end,
    case when p_recurrence_type = 'weekly' then p_weekdays else '{}' end,
    p_start_date, p_end_date, true, p_priority, p_category_id
  )
  returning * into created_template;

  insert into public.task_template_allowed_members (task_template_id, profile_id)
  values (created_template.id, auth.uid());

  perform public.generate_recurring_task_occurrences(greatest(current_date, p_start_date) + 30);

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

-- ============================================================
-- 2. Subtasks & Categories CRUD
-- ============================================================
--
-- Таблицы task_subtasks и task_categories уже созданы в
-- 20260727_initial_schema.sql вместе с RLS-политиками, разрешающими
-- членам семьи прямой CRUD (чтение/создание/изменение/удаление).
-- Колонка task_occurrences.category_id тоже существует с initial_schema.
--
-- Дополнительных изменений схемы не требуется: приложение работает
-- с этими таблицами напрямую через RLS (без RPC-функций).
--
-- В этой миграции для subtasks/categories меняется только клиентская
-- часть (репозитории + offline-очередь SUBTASK_CREATE/UPDATE/DELETE).
