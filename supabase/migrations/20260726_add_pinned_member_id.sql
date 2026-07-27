-- Add pinned_member_id column to task_occurrences table
-- This column marks tasks that are "pinned" to a specific family member
-- and should not be redistributed when auto-distributing tasks.

ALTER TABLE task_occurrences
ADD COLUMN pinned_member_id UUID REFERENCES profiles(id);
