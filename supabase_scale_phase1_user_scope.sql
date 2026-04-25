-- Phase 1: prepare tenant-scoped data for future 10,000-user scale.
-- Paste this manually in Supabase SQL Editor.
--
-- This is intentionally safe for the current app:
-- - Adds nullable user_id columns.
-- - Adds indexes for user-scoped queries.
-- - Does NOT enable RLS yet, because the Flutter app does not have login/auth
--   screens and does not filter by auth.uid() yet.

alter table public.people
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.categories
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.transactions
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.bills
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.loans
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.attachments
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

create index if not exists people_user_id_idx
  on public.people(user_id);

create index if not exists categories_user_id_type_idx
  on public.categories(user_id, type);

create index if not exists transactions_user_id_date_idx
  on public.transactions(user_id, transaction_date desc);

create index if not exists bills_user_id_due_day_idx
  on public.bills(user_id, due_day);

create index if not exists bills_user_id_status_idx
  on public.bills(user_id, status);

create index if not exists loans_user_id_next_due_date_idx
  on public.loans(user_id, next_due_date);

create index if not exists attachments_user_id_related_idx
  on public.attachments(user_id, related_type, related_id);

-- Later, after the app has authentication:
-- 1. Backfill existing rows to the correct owner user:
--    update public.bills set user_id = '<USER_UUID>' where user_id is null;
--    update public.people set user_id = '<USER_UUID>' where user_id is null;
--    update public.categories set user_id = '<USER_UUID>' where user_id is null;
--    update public.transactions set user_id = '<USER_UUID>' where user_id is null;
--    update public.loans set user_id = '<USER_UUID>' where user_id is null;
--    update public.attachments set user_id = '<USER_UUID>' where user_id is null;
--
-- 2. Update Flutter inserts to include:
--    user_id = Supabase.instance.client.auth.currentUser!.id
--
-- 3. Update Flutter reads/updates/deletes to filter:
--    .eq('user_id', currentUserId)
--
-- 4. Only then enable RLS and policies.
