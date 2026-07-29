-- Добавляем приоритет задачи по матрице Эйзенхауэра

-- 1. Колонка в task_occurrences
ALTER TABLE task_occurrences ADD COLUMN priority INT;

COMMENT ON COLUMN task_occurrences.priority IS 'Приоритет по матрице Эйзенхауэра: 1 — срочно и важно, 2 — не срочно, но важно, 3 — срочно, но не важно, 4 — не срочно и не важно';

-- 2. Колонка в task_templates (для повторяющихся задач)
ALTER TABLE task_templates ADD COLUMN priority INT;

-- 3. Обновляем RPC create_task_occurrence — добавляем p_priority
CREATE OR REPLACE FUNCTION create_task_occurrence(
  p_household_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_estimated_duration_minutes INTEGER,
  p_planned_for DATE,
  p_deadline_at TIMESTAMPTZ DEFAULT NULL,
  p_priority INT DEFAULT NULL
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
    estimated_duration_minutes, planned_for, deadline_at, priority
  )
  values (
    p_household_id, auth.uid(), trim(p_title),
    nullif(trim(p_description), ''),
    p_estimated_duration_minutes, p_planned_for, p_deadline_at, p_priority
  )
  returning * into created_task;

  insert into public.task_occurrence_allowed_members (task_occurrence_id, profile_id)
  values (created_task.id, auth.uid());

  return created_task;
end;
$$;

-- 4. Обновляем RPC create_recurring_task_template — добавляем p_priority
--    Все обязательные параметры до опциональных (правило PG: после первого DEFAULT всё должно иметь DEFAULT)
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
  p_priority INT DEFAULT NULL
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
    recurrence_start_date, recurrence_end_date, is_active, priority
  )
  values (
    p_household_id, auth.uid(), trim(p_title),
    nullif(trim(p_description), ''),
    p_estimated_duration_minutes, p_deadline_time,
    p_recurrence_type,
    case when p_recurrence_type = 'interval_days' then p_interval_days else null end,
    case when p_recurrence_type = 'weekly' then p_weekdays else '{}' end,
    p_start_date, p_end_date, true, p_priority
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

  return first_occurrence;
end;
$$;

-- 5. Обновляем generate_recurring_task_occurrences — копирует priority из template
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

  for task_template in
    select * from public.task_templates
    where is_active = true
      and recurrence_type <> 'none'
      and recurrence_start_date is not null
      and (recurrence_end_date is null or recurrence_end_date >= current_date)
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
          planned_for, deadline_at, priority
        )
        values (
          task_template.household_id, task_template.id, task_template.category_id,
          task_template.created_by, task_template.title, task_template.description,
          task_template.estimated_duration_minutes, occurrence_date, occurrence_deadline,
          task_template.priority
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
