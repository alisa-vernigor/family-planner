-- ============================================================
-- Initial schema: tables, enums, triggers, RLS, functions, indexes
-- ============================================================

-- 1. ENUM TYPES
-- ============================================================

CREATE TYPE household_role AS ENUM ('owner', 'member');
CREATE TYPE household_invitation_status AS ENUM ('pending', 'accepted', 'declined', 'cancelled', 'expired');
CREATE TYPE task_status AS ENUM ('pending', 'completed', 'skipped');
CREATE TYPE recurrence_type AS ENUM ('none', 'daily', 'weekly', 'interval_days');

-- 2. TABLES
-- ============================================================

CREATE TABLE profiles (
  id UUID PRIMARY KEY,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  timezone TEXT NOT NULL DEFAULT 'Europe/Moscow',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE households (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE household_members (
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role household_role NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (household_id, profile_id)
);

CREATE TABLE household_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  invited_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  invited_by_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  status household_invitation_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '7 days'
);

CREATE TABLE task_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color_hex TEXT,
  icon_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (household_id, name)
);

CREATE TABLE task_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  category_id UUID REFERENCES task_categories(id) ON DELETE SET NULL,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  description TEXT,
  estimated_duration_minutes INTEGER NOT NULL,
  deadline_time TIME,
  is_active BOOLEAN NOT NULL DEFAULT true,
  recurrence_type recurrence_type NOT NULL DEFAULT 'none',
  interval_days INTEGER,
  weekdays SMALLINT[] NOT NULL DEFAULT '{}',
  recurrence_start_date DATE,
  recurrence_end_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE task_template_allowed_members (
  task_template_id UUID NOT NULL REFERENCES task_templates(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (task_template_id, profile_id)
);

CREATE TABLE task_occurrences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  template_id UUID REFERENCES task_templates(id) ON DELETE SET NULL,
  category_id UUID REFERENCES task_categories(id) ON DELETE SET NULL,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  title TEXT NOT NULL,
  description TEXT,
  estimated_duration_minutes INTEGER NOT NULL,
  planned_for DATE NOT NULL,
  deadline_at TIMESTAMPTZ,
  status task_status NOT NULL DEFAULT 'pending',
  assigned_member_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  pinned_member_id UUID REFERENCES profiles(id) ON DELETE NO ACTION,
  completed_by_member_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  completed_at TIMESTAMPTZ,
  carried_from_occurrence_id UUID REFERENCES task_occurrences(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE task_occurrence_allowed_members (
  task_occurrence_id UUID NOT NULL REFERENCES task_occurrences(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (task_occurrence_id, profile_id)
);

CREATE TABLE task_subtasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_occurrence_id UUID NOT NULL REFERENCES task_occurrences(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. INDEXES
-- ============================================================

CREATE INDEX household_members_profile_id_index ON household_members(profile_id);
CREATE INDEX household_invitations_invited_profile_status_index ON household_invitations(invited_profile_id, status, created_at DESC);
CREATE UNIQUE INDEX household_invitations_unique_pending_invitation ON household_invitations(household_id, invited_profile_id) WHERE status = 'pending';

CREATE INDEX task_categories_household_id_index ON task_categories(household_id);
CREATE INDEX task_templates_household_id_index ON task_templates(household_id);
CREATE INDEX task_occurrences_household_day_index ON task_occurrences(household_id, planned_for);
CREATE INDEX task_occurrences_assigned_member_day_index ON task_occurrences(assigned_member_id, planned_for);
CREATE UNIQUE INDEX task_occurrences_unique_template_planned_for ON task_occurrences(template_id, planned_for) WHERE template_id IS NOT NULL;
CREATE INDEX task_occurrence_allowed_members_profile_id_index ON task_occurrence_allowed_members(profile_id);
CREATE INDEX task_subtasks_occurrence_position_index ON task_subtasks(task_occurrence_id, "position");

-- 4. TRIGGER FUNCTION
-- ============================================================

CREATE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 5. TRIGGERS
-- ============================================================

CREATE TRIGGER households_set_updated_at BEFORE UPDATE ON households FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER household_invitations_set_updated_at BEFORE UPDATE ON household_invitations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER profiles_set_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER task_occurrences_set_updated_at BEFORE UPDATE ON task_occurrences FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER task_templates_set_updated_at BEFORE UPDATE ON task_templates FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 6. RLS POLICIES
-- ============================================================

-- Helper: is the current user a member of the household?
CREATE FUNCTION is_household_member(target_household_id UUID)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  select exists (
    select 1
    from public.household_members
    where household_id = target_household_id
      and profile_id = (select auth.uid())
  );
$$;

-- Helper: is the current user the owner of the household?
CREATE FUNCTION is_household_owner(target_household_id UUID)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  select exists (
    select 1
    from public.household_members
    where household_id = target_household_id
      and profile_id = (select auth.uid())
      and role = 'owner'
  );
$$;

-- Profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles visible to authenticated users"
  ON profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users update own profile"
  ON profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- Households
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users create households"
  ON households FOR INSERT TO authenticated WITH CHECK (created_by = auth.uid());
CREATE POLICY "Members view their households"
  ON households FOR SELECT TO authenticated USING (is_household_member(id));
CREATE POLICY "Owners update households"
  ON households FOR UPDATE TO authenticated USING (is_household_owner(id)) WITH CHECK (is_household_owner(id));
CREATE POLICY "Owners delete households"
  ON households FOR DELETE TO authenticated USING (is_household_owner(id));

-- Household members
ALTER TABLE household_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Creator adds self as household owner"
  ON household_members FOR INSERT TO authenticated
  WITH CHECK (
    profile_id = auth.uid()
    AND role = 'owner'
    AND EXISTS (
      SELECT 1 FROM households
      WHERE households.id = household_members.household_id
        AND households.created_by = auth.uid()
    )
  );
CREATE POLICY "Members view household members"
  ON household_members FOR SELECT TO authenticated USING (is_household_member(household_id));
CREATE POLICY "Owners add household members"
  ON household_members FOR INSERT TO authenticated WITH CHECK (is_household_owner(household_id));
CREATE POLICY "Owners update household members"
  ON household_members FOR UPDATE TO authenticated USING (is_household_owner(household_id)) WITH CHECK (is_household_owner(household_id));
CREATE POLICY "Owners remove household members"
  ON household_members FOR DELETE TO authenticated USING (is_household_owner(household_id));

-- Invitations
ALTER TABLE household_invitations ENABLE ROW LEVEL SECURITY;
  -- (handled by RPC functions: create_household_invitation, accept/decline)

-- Task categories
ALTER TABLE task_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members view categories"
  ON task_categories FOR SELECT TO authenticated USING (is_household_member(household_id));
CREATE POLICY "Members manage categories"
  ON task_categories FOR ALL TO authenticated USING (is_household_member(household_id)) WITH CHECK (is_household_member(household_id));

-- Task templates
ALTER TABLE task_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members view task templates"
  ON task_templates FOR SELECT TO authenticated USING (is_household_member(household_id));
CREATE POLICY "Members manage task templates"
  ON task_templates FOR ALL TO authenticated USING (is_household_member(household_id)) WITH CHECK (is_household_member(household_id));

-- Task template allowed members
ALTER TABLE task_template_allowed_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members view template allowed members"
  ON task_template_allowed_members FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM task_templates
    WHERE task_templates.id = task_template_allowed_members.task_template_id
      AND is_household_member(task_templates.household_id)
  ));
CREATE POLICY "Members manage template allowed members"
  ON task_template_allowed_members FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM task_templates
    WHERE task_templates.id = task_template_allowed_members.task_template_id
      AND is_household_member(task_templates.household_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM task_templates
    WHERE task_templates.id = task_template_allowed_members.task_template_id
      AND is_household_member(task_templates.household_id)
  ));

-- Task occurrences
ALTER TABLE task_occurrences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members view task occurrences"
  ON task_occurrences FOR SELECT TO authenticated USING (is_household_member(household_id));
CREATE POLICY "Members manage task occurrences"
  ON task_occurrences FOR ALL TO authenticated USING (is_household_member(household_id)) WITH CHECK (is_household_member(household_id));

-- Task occurrence allowed members
ALTER TABLE task_occurrence_allowed_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members view occurrence allowed members"
  ON task_occurrence_allowed_members FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM task_occurrences
    WHERE task_occurrences.id = task_occurrence_allowed_members.task_occurrence_id
      AND is_household_member(task_occurrences.household_id)
  ));
CREATE POLICY "Members manage occurrence allowed members"
  ON task_occurrence_allowed_members FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM task_occurrences
    WHERE task_occurrences.id = task_occurrence_allowed_members.task_occurrence_id
      AND is_household_member(task_occurrences.household_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM task_occurrences
    WHERE task_occurrences.id = task_occurrence_allowed_members.task_occurrence_id
      AND is_household_member(task_occurrences.household_id)
  ));

-- Subtasks
ALTER TABLE task_subtasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members view subtasks"
  ON task_subtasks FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM task_occurrences
    WHERE task_occurrences.id = task_subtasks.task_occurrence_id
      AND is_household_member(task_occurrences.household_id)
  ));
CREATE POLICY "Members manage subtasks"
  ON task_subtasks FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM task_occurrences
    WHERE task_occurrences.id = task_subtasks.task_occurrence_id
      AND is_household_member(task_occurrences.household_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM task_occurrences
    WHERE task_occurrences.id = task_subtasks.task_occurrence_id
      AND is_household_member(task_occurrences.household_id)
  ));

-- 7. RPC FUNCTIONS
-- ============================================================

-- Create a profile when a new user signs up
CREATE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  );
  return new;
end;
$$;

-- Auto-create profile on signup (trigger on auth.users)
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE FUNCTION create_household(household_name TEXT)
RETURNS households
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  created_household public.households;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация.';
  end if;

  if char_length(trim(household_name)) = 0 then
    raise exception 'Название семьи не может быть пустым.';
  end if;

  insert into public.households (name, created_by)
  values (trim(household_name), auth.uid())
  returning * into created_household;

  insert into public.household_members (household_id, profile_id, role)
  values (created_household.id, auth.uid(), 'owner');

  return created_household;
end;
$$;

CREATE FUNCTION delete_household(p_household_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
begin
  if not public.is_household_owner(p_household_id) then
    raise exception 'Only owner can delete household';
  end if;
  delete from public.households where id = p_household_id;
end;
$$;

CREATE FUNCTION update_household_name(p_household_id UUID, p_name TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
begin
  if not public.is_household_owner(p_household_id) then
    raise exception 'Only owner can rename household';
  end if;
  update public.households set name = p_name where id = p_household_id;
end;
$$;

CREATE FUNCTION create_household_invitation(p_household_id UUID, p_email TEXT)
RETURNS household_invitations
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  target_profile_id uuid;
  created_invitation public.household_invitations;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация.';
  end if;

  if not public.is_household_owner(p_household_id) then
    raise exception 'Только владелец семьи может приглашать участников.';
  end if;

  select p.id into target_profile_id
  from auth.users u
  inner join public.profiles p on p.id = u.id
  where lower(u.email) = lower(trim(p_email));

  if target_profile_id is null then
    raise exception 'Пользователь с таким email ещё не зарегистрирован.';
  end if;

  if target_profile_id = auth.uid() then
    raise exception 'Нельзя пригласить самого себя.';
  end if;

  if exists (
    select 1 from public.household_members
    where household_id = p_household_id and profile_id = target_profile_id
  ) then
    raise exception 'Пользователь уже состоит в этой семье.';
  end if;

  update public.household_invitations
  set status = 'expired', responded_at = now()
  where household_id = p_household_id
    and invited_profile_id = target_profile_id
    and status = 'pending'
    and expires_at <= now();

  insert into public.household_invitations (household_id, invited_profile_id, invited_by_profile_id)
  values (p_household_id, target_profile_id, auth.uid())
  returning * into created_invitation;

  return created_invitation;
end;
$$;

CREATE FUNCTION accept_household_invitation(p_invitation_id UUID)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  invitation public.household_invitations;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация.';
  end if;

  select * into invitation
  from public.household_invitations
  where id = p_invitation_id
  for update;

  if invitation is null then
    raise exception 'Приглашение не найдено.';
  end if;

  if invitation.invited_profile_id <> auth.uid() then
    raise exception 'Вы не можете принять чужое приглашение.';
  end if;

  if invitation.status <> 'pending' then
    raise exception 'Это приглашение уже обработано.';
  end if;

  if invitation.expires_at <= now() then
    update public.household_invitations
    set status = 'expired', responded_at = now()
    where id = invitation.id;
    raise exception 'Срок действия приглашения истёк.';
  end if;

  insert into public.household_members (household_id, profile_id, role)
  values (invitation.household_id, auth.uid(), 'member')
  on conflict (household_id, profile_id) do nothing;

  update public.household_invitations
  set status = 'accepted', responded_at = now()
  where id = invitation.id;

  return invitation.household_id;
end;
$$;

CREATE FUNCTION decline_household_invitation(p_invitation_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  invitation public.household_invitations;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация.';
  end if;

  select * into invitation
  from public.household_invitations
  where id = p_invitation_id
  for update;

  if invitation is null then
    raise exception 'Приглашение не найдено.';
  end if;

  if invitation.invited_profile_id <> auth.uid() then
    raise exception 'Вы не можете отклонить чужое приглашение.';
  end if;

  if invitation.status <> 'pending' then
    raise exception 'Это приглашение уже обработано.';
  end if;

  update public.household_invitations
  set status = 'declined', responded_at = now()
  where id = invitation.id;
end;
$$;

CREATE FUNCTION get_household_name_for_invitation(p_household_id UUID)
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  select name from public.households where id = p_household_id;
$$;

CREATE FUNCTION leave_household(p_household_id UUID)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$
  delete from public.household_members
  where household_id = p_household_id and profile_id = auth.uid();
$$;

CREATE FUNCTION remove_household_member(p_household_id UUID, p_profile_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
begin
  if not public.is_household_owner(p_household_id) then
    raise exception 'Only owner can remove members';
  end if;
  delete from public.household_members
  where household_id = p_household_id and profile_id = p_profile_id;
end;
$$;

CREATE FUNCTION create_task_occurrence(
  p_household_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_estimated_duration_minutes INTEGER,
  p_planned_for DATE,
  p_deadline_at TIMESTAMPTZ DEFAULT NULL
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
    estimated_duration_minutes, planned_for, deadline_at
  )
  values (
    p_household_id, auth.uid(), trim(p_title),
    nullif(trim(p_description), ''),
    p_estimated_duration_minutes, p_planned_for, p_deadline_at
  )
  returning * into created_task;

  insert into public.task_occurrence_allowed_members (task_occurrence_id, profile_id)
  values (created_task.id, auth.uid());

  return created_task;
end;
$$;

CREATE FUNCTION create_recurring_task_template(
  p_household_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_estimated_duration_minutes INTEGER,
  p_start_date DATE,
  p_deadline_time TIME DEFAULT NULL,
  p_recurrence_type recurrence_type,
  p_interval_days INTEGER DEFAULT NULL,
  p_weekdays SMALLINT[] DEFAULT '{}',
  p_end_date DATE DEFAULT NULL
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
    recurrence_start_date, recurrence_end_date, is_active
  )
  values (
    p_household_id, auth.uid(), trim(p_title),
    nullif(trim(p_description), ''),
    p_estimated_duration_minutes, p_deadline_time,
    p_recurrence_type,
    case when p_recurrence_type = 'interval_days' then p_interval_days else null end,
    case when p_recurrence_type = 'weekly' then p_weekdays else '{}' end,
    p_start_date, p_end_date, true
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

CREATE FUNCTION generate_recurring_task_occurrences(p_until_date DATE)
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

CREATE FUNCTION pause_task_template(p_task_template_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
declare
  target_household_id uuid;
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

  update public.task_templates set is_active = false where id = p_task_template_id;
end;
$$;

CREATE FUNCTION resume_task_template(p_task_template_id UUID)
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

  select public.generate_recurring_task_occurrences(current_date + 30) into generated_count;
  return generated_count;
end;
$$;
