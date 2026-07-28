-- ============================================================
-- Migration: Avatars storage, profile bio, and profile stats
-- Apply via Supabase SQL editor
-- ============================================================

-- 1. Bio column for profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bio TEXT NOT NULL DEFAULT '';

-- 2. Create storage bucket for avatars (public for easy serving)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880, -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- 3. RLS: anyone authenticated can read avatars
CREATE POLICY "Anyone can view avatars"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'avatars');

-- 4. RLS: users upload only to their own folder
CREATE POLICY "Users upload own avatar"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 5. RLS: users update only their own avatar
CREATE POLICY "Users update own avatar"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 6. RLS: users delete only their own avatar
CREATE POLICY "Users delete own avatar"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 7. Function: get profile task stats (only for household members)
CREATE OR REPLACE FUNCTION get_profile_stats(p_profile_id UUID)
RETURNS TABLE (
  total_assigned BIGINT,
  completed_tasks BIGINT,
  completed_this_month BIGINT,
  completed_this_week BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
begin
  -- Only return stats if the caller and the target share a household
  if not exists (
    select 1 from public.household_members hm1
    inner join public.household_members hm2
      on hm1.household_id = hm2.household_id
    where hm1.profile_id = auth.uid()
      and hm2.profile_id = p_profile_id
  ) then
    return;
  end if;

  return query
  select
    count(*)::bigint as total_assigned,
    count(*) filter (where status = 'completed')::bigint as completed_tasks,
    count(*) filter (
      where status = 'completed'
        and completed_at >= date_trunc('month', now())
    )::bigint as completed_this_month,
    count(*) filter (
      where status = 'completed'
        and completed_at >= date_trunc('week', now())
    )::bigint as completed_this_week
  from public.task_occurrences
  where assigned_member_id = p_profile_id;
end;
$$;

-- 8. Update profiles RLS: insert policy for handle_new_user trigger
--    (already exists via trigger, but ensure authenticated users can read profiles)
--    Current policy allows SELECT for authenticated users, which is fine.
