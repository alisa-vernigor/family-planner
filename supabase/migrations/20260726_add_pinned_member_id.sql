-- ============================================================
-- Add pinned_member_id column to task_occurrences.
--
-- NOTE: this column is ALREADY present in the consolidated snapshot
-- 20260727_initial_schema.sql (created with the column). This file is
-- kept as a historical record for databases that were built before the
-- snapshot. It must stay idempotent: applying it after initial_schema
-- (which happens naturally in alphabetical order, and on any DB that
-- already has the column) must be a no-op.
-- ============================================================

DO $$
BEGIN
  -- Таблицы ещё не существует (эта миграция сортируется ДО initial_schema) —
  -- пропускаем: initial_schema уже создаст колонку.
  IF to_regclass('public.task_occurrences') IS NULL THEN
    RAISE NOTICE 'add_pinned_member_id: initial_schema not applied yet, skipping';
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'task_occurrences'
      AND column_name = 'pinned_member_id'
  ) THEN
    ALTER TABLE task_occurrences
    ADD COLUMN pinned_member_id UUID REFERENCES profiles(id);
  END IF;
END $$;
