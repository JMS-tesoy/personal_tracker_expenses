-- Phase 2: backfill user ownership and enable RLS.
-- Paste this manually in Supabase SQL Editor after creating/signing in your
-- first app user.
--
-- IMPORTANT:
-- Replace <YOUR_AUTH_USER_UUID> with the UUID from auth.users.id for the user
-- who should own your existing rows.

-- 1. Make sure the user_id columns exist.
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

-- 2. Add indexes for user-scoped queries.
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

-- 3. Backfill existing rows.
update public.people
set user_id = '<YOUR_AUTH_USER_UUID>'
where user_id is null;

update public.categories
set user_id = '<YOUR_AUTH_USER_UUID>'
where user_id is null;

update public.transactions
set user_id = '<YOUR_AUTH_USER_UUID>'
where user_id is null;

update public.bills
set user_id = '<YOUR_AUTH_USER_UUID>'
where user_id is null;

update public.loans
set user_id = '<YOUR_AUTH_USER_UUID>'
where user_id is null;

update public.attachments
set user_id = '<YOUR_AUTH_USER_UUID>'
where user_id is null;

-- 4. Enable RLS.
alter table public.people enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.bills enable row level security;
alter table public.loans enable row level security;
alter table public.attachments enable row level security;

-- 5. Owner-only policies.
drop policy if exists "people_owner_select" on public.people;
create policy "people_owner_select"
on public.people for select to authenticated
using (user_id = auth.uid());

drop policy if exists "people_owner_insert" on public.people;
create policy "people_owner_insert"
on public.people for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "people_owner_update" on public.people;
create policy "people_owner_update"
on public.people for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "people_owner_delete" on public.people;
create policy "people_owner_delete"
on public.people for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "categories_owner_select" on public.categories;
create policy "categories_owner_select"
on public.categories for select to authenticated
using (user_id = auth.uid());

drop policy if exists "categories_owner_insert" on public.categories;
create policy "categories_owner_insert"
on public.categories for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "categories_owner_update" on public.categories;
create policy "categories_owner_update"
on public.categories for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "categories_owner_delete" on public.categories;
create policy "categories_owner_delete"
on public.categories for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "transactions_owner_select" on public.transactions;
create policy "transactions_owner_select"
on public.transactions for select to authenticated
using (user_id = auth.uid());

drop policy if exists "transactions_owner_insert" on public.transactions;
create policy "transactions_owner_insert"
on public.transactions for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "transactions_owner_update" on public.transactions;
create policy "transactions_owner_update"
on public.transactions for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "transactions_owner_delete" on public.transactions;
create policy "transactions_owner_delete"
on public.transactions for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "bills_owner_select" on public.bills;
create policy "bills_owner_select"
on public.bills for select to authenticated
using (user_id = auth.uid());

drop policy if exists "bills_owner_insert" on public.bills;
create policy "bills_owner_insert"
on public.bills for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "bills_owner_update" on public.bills;
create policy "bills_owner_update"
on public.bills for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "bills_owner_delete" on public.bills;
create policy "bills_owner_delete"
on public.bills for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "loans_owner_select" on public.loans;
create policy "loans_owner_select"
on public.loans for select to authenticated
using (user_id = auth.uid());

drop policy if exists "loans_owner_insert" on public.loans;
create policy "loans_owner_insert"
on public.loans for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "loans_owner_update" on public.loans;
create policy "loans_owner_update"
on public.loans for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "loans_owner_delete" on public.loans;
create policy "loans_owner_delete"
on public.loans for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "attachments_owner_select" on public.attachments;
create policy "attachments_owner_select"
on public.attachments for select to authenticated
using (user_id = auth.uid());

drop policy if exists "attachments_owner_insert" on public.attachments;
create policy "attachments_owner_insert"
on public.attachments for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "attachments_owner_update" on public.attachments;
create policy "attachments_owner_update"
on public.attachments for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "attachments_owner_delete" on public.attachments;
create policy "attachments_owner_delete"
on public.attachments for delete to authenticated
using (user_id = auth.uid());

-- 6. Storage policies for payment proof uploads.
-- Public bucket URLs can still be read publicly while the bucket remains public.
-- These policies protect app uploads/listing through Supabase authenticated APIs.
drop policy if exists "payment_proofs_owner_insert" on storage.objects;
create policy "payment_proofs_owner_insert"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'payment-proofs'
  and (storage.foldername(name))[1] = 'bills'
  and exists (
    select 1
    from public.bills
    where public.bills.id::text = (storage.foldername(name))[2]
      and public.bills.user_id = auth.uid()
  )
);

drop policy if exists "payment_proofs_owner_select" on storage.objects;
create policy "payment_proofs_owner_select"
on storage.objects for select to authenticated
using (
  bucket_id = 'payment-proofs'
  and (storage.foldername(name))[1] = 'bills'
  and exists (
    select 1
    from public.bills
    where public.bills.id::text = (storage.foldername(name))[2]
      and public.bills.user_id = auth.uid()
  )
);

drop policy if exists "payment_proofs_owner_delete" on storage.objects;
create policy "payment_proofs_owner_delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'payment-proofs'
  and (storage.foldername(name))[1] = 'bills'
  and exists (
    select 1
    from public.bills
    where public.bills.id::text = (storage.foldername(name))[2]
      and public.bills.user_id = auth.uid()
  )
);
