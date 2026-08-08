-- ============================================================
-- Пауза/возобновление повторяющихся задач (pause/resume).
--
-- RPC `pause_task_template` / `resume_task_template` существовали в
-- initial_schema, но из UI не вызывались. Здесь они переписаны с
-- правильной семантикой:
--
-- * pause_task_template:
--     - is_active = false (новые экземпляры не генерируются);
--     - удаляются будущие pending-экземпляры серии (planned_for >= сегодня),
--       чтобы серия реально «ушла» из расписания; история (прошлые +
--       выполненные) сохраняется;
--     - сохраняется ОДИН «якорный» экземпляр (ближайший будущий pending,
--       а если такого нет — самый свежий из существующих) — точка входа,
--       через которую в UI можно возобновить серию (на нём бейдж
--       «Серия на паузе»).
-- * resume_task_template:
--     - is_active = true;
--     - догенерация экземпляров на 30 дней вперёд (как при создании).
-- ============================================================

CREATE OR REPLACE FUNCTION pause_task_template(p_task_template_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  target_household_id uuid;
  anchor_id uuid;
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

  -- Якорь: ближайший будущий pending-экземпляр; если его нет —
  -- самый свежий из существующих. Он останется точкой входа для resume.
  select id into anchor_id
  from public.task_occurrences
  where template_id = p_task_template_id
    and planned_for >= current_date
    and status = 'pending'
  order by planned_for
  limit 1;

  if anchor_id is null then
    select id into anchor_id
    from public.task_occurrences
    where template_id = p_task_template_id
    order by planned_for desc
    limit 1;
  end if;

  -- Пауза: новые экземпляры не генерируются.
  update public.task_templates
  set is_active = false
  where id = p_task_template_id;

  -- Убираем будущие pending-экземпляры, кроме якоря. История сохраняется.
  delete from public.task_occurrences
  where template_id = p_task_template_id
    and planned_for >= current_date
    and status = 'pending'
    and (anchor_id is null or id <> anchor_id);
end;
$$;

COMMENT ON FUNCTION pause_task_template IS
  'Ставит повторяющуюся задачу на паузу: is_active=false, будущие pending-экземпляры удаляются (кроме одного якорного), история сохраняется.';

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
  select public.generate_recurring_task_occurrences(current_date + 30) into generated_count;
  return generated_count;
end;
$$;

COMMENT ON FUNCTION resume_task_template IS
  'Возобновляет повторяющуюся задачу: is_active=true и догенерирует экземпляры на 30 дней вперёд.';
