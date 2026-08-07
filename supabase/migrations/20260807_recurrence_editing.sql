-- ============================================================
-- Recurrence editing: allow changing the schedule of recurring tasks
-- Google-Calendar style (this one / this and following / all).
--
-- A recurring task is a `task_templates` row + `task_occurrences` rows.
-- This migration adds an RPC that updates the template (and, depending on
-- the scope, the affected occurrences).
-- ============================================================

CREATE FUNCTION update_task_template(
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
  p_add_allowed_member_ids UUID[] DEFAULT '{}'
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
        pinned_member_id = p_pinned_member_id
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

  -- Начало области изменений:
  --   all                → от начала серии
  --   this_and_following → от даты редактируемого экземпляра
  from_date := case
    when p_scope = 'all' then target_template.recurrence_start_date
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
      priority = p_priority
  where id = target_template.id;

  -- 2. Метаданные (заголовок/длительность/приоритет/дедлайн) в зоне изменений
  update public.task_occurrences
  set title = trim(p_title),
      description = nullif(trim(p_description), ''),
      estimated_duration_minutes = p_estimated_duration_minutes,
      priority = p_priority,
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
  'Обновляет повторяющуюся задачу (шаблон + экземпляры) с учётом области применения: only_this, this_and_following, all.';
