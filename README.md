# Personal Tracker Expenses

Personal Tracker Expenses is a Flutter and Supabase app for tracking daily transactions, bills, loans, people, reminders, and payment proof.

The app is split into these main tabs:

- Home
- Transactions
- Bills
- Loans
- People
- Reminders

---

# User Guide

## 1. Sign In Or Create Account

When the app opens, it checks your Supabase login session.

- If you are not signed in, the app shows the login screen.
- You can sign in with an existing account.
- You can switch to sign up if you need a new account.
- After login, the app opens the main navigation.

Each user only sees their own data. This is controlled by `user_id` in Supabase.

## 2. Home

The Home tab is the dashboard.

Use it to quickly review:

- Monthly income
- Monthly expenses
- Balance
- Active loans
- Payday planning
- Recent transactions

Pull down to refresh dashboard data.

## 3. Transactions

The Transactions tab is split into:

- Transaction
- History

Use Transaction for current active items.

Use History for older or archived items.

Typical flow:

1. Tap the add button.
2. Choose income or expense.
3. Select a category.
4. Enter amount, payment method, note, and date.
5. Save the transaction.

Each new transaction stores:

- transaction date
- created date and time
- archive status
- user owner

Sorting options:

- Ascending
- Descending

You can move a transaction to History by choosing `Move to Archive`.

## 4. Bills

The Bills tab tracks monthly bills.

Bills use these statuses:

- `active`
- `overdue`
- `paid`

Typical flow:

1. Tap the add button.
2. Add the bill name, amount, due day, payment method, and assigned person.
3. Save the bill.
4. The bill appears in the Active tab unless it is overdue.
5. Mark the bill as paid when it is paid.
6. Mark it active again if you need to undo paid status.

Bill details can show:

- amount
- due day
- payment method
- status
- assigned person
- paid by
- paid date
- notes
- remarks
- payment proof

You can also add a reminder from Bill Details.

## 5. Loans

The Loans tab is split into:

- Active
- Paid

Typical flow:

1. Tap the add button.
2. Enter loan name, lender, amount, monthly installment, due day, and schedule details.
3. Save the loan.
4. The loan appears in Active.
5. Open Loan Details.
6. Tap the payment button when a payday payment is made.
7. Choose which person paid.
8. Confirm the payment.

The app tracks loan progress by payday payments.

When the final payment is confirmed:

- the loan status becomes `paid`
- remaining balance becomes zero
- the loan moves from Active to Paid

Loan Details can also show payment contributors. This helps you see which person paid the most.

You can add a reminder from Loan Details.

## 6. People

The People tab stores people used in bills, loans, reminders, and shared payments.

People are organized by group tabs.

Default groups:

- Family
- Friend
- Coworker

You can:

- create a group
- rename a group
- delete a group
- add people to the selected group

When you add a person while a group tab is selected, the group field is prefilled.

If a group is deleted, people from that group move to `Ungrouped`.

`Ungrouped` cannot be renamed or deleted.

## 7. Reminders

The Reminders tab shows active reminders.

Reminders can be created from:

- Reminders tab
- Bill Details
- Loan Details
- Person card

Local notifications are initialized when the app starts. If you are already signed in, pending local notifications are synced after Supabase initialization.

## 8. Important Data Terms

`id`

The unique row ID. Supabase uses this to know exactly which bill, loan, person, transaction, or reminder is being updated.

`user_id`

The owner of the row. This connects each row to the logged-in user.

`uuid`

The long unique ID format used by Supabase, for example:

```text
8b39ef2a-ce34-4952-a328-4f4f6968b8da
```

You normally do not edit UUID values manually.

---

# Developer Guide

## 1. Project Stack

- Flutter
- Dart
- Supabase Auth
- Supabase Database
- Supabase Storage for bill payment proof
- `flutter_local_notifications` for reminders

## 2. App Entry Flow

The app starts in:

```text
lib/main.dart
```

Startup flow:

1. Flutter binding is initialized.
2. Supabase is initialized.
3. Local notifications are initialized.
4. Notification permission is requested.
5. Pending reminders are synced if a user session already exists.
6. `App` starts.
7. `AuthGate` decides between login and main navigation.

Main navigation is in:

```text
lib/app/main_navigation.dart
```

Navigation tabs:

- `DashboardScreen`
- `TransactionsScreen`
- `BillsScreen`
- `LoansScreen`
- `PeopleScreen`
- `RemindersScreen`

## 3. Feature Folders

Main feature folders:

```text
lib/features/auth/
lib/features/dashboard/
lib/features/transactions/
lib/features/bills/
lib/features/loans/
lib/features/people/
lib/features/reminders/
lib/features/attachments/
lib/features/categories/
```

Shared helpers live under:

```text
lib/core/
lib/shared/
```

## 4. Supabase Tables Used By The App

The current app expects these main tables:

- `people`
- `people_groups`
- `categories`
- `transactions`
- `bills`
- `loans`
- `loan_payment_contributions`
- `reminders`
- `attachments`

Most user-owned tables should have:

```text
user_id uuid references auth.users(id)
```

RLS policies should restrict rows with:

```sql
user_id = auth.uid()
```

## 5. People Groups SQL

Run this once in Supabase SQL Editor:

```sql
create table if not exists public.people_groups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists people_groups_user_name_idx
  on public.people_groups(user_id, lower(name));

create index if not exists people_groups_user_id_idx
  on public.people_groups(user_id);

alter table public.people_groups enable row level security;

drop policy if exists "people_groups_owner_select" on public.people_groups;
create policy "people_groups_owner_select"
on public.people_groups for select to authenticated
using (user_id = auth.uid());

drop policy if exists "people_groups_owner_insert" on public.people_groups;
create policy "people_groups_owner_insert"
on public.people_groups for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "people_groups_owner_update" on public.people_groups;
create policy "people_groups_owner_update"
on public.people_groups for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "people_groups_owner_delete" on public.people_groups;
create policy "people_groups_owner_delete"
on public.people_groups for delete to authenticated
using (user_id = auth.uid());
```

## 6. Bills Status Cleanup SQL

Older bills may still use `unpaid`.

The app now uses `active`.

Run this once if needed:

```sql
update public.bills
set status = 'active'
where status = 'unpaid';
```

Verify:

```sql
select id, name, status
from public.bills
order by created_at desc;
```

## 7. Transactions Archive SQL

Transactions use `is_archived` and `created_at`.

Run this if your database does not have those fields yet:

```sql
alter table public.transactions
  add column if not exists is_archived boolean not null default false;

update public.transactions
set is_archived = false
where is_archived is null;

update public.transactions
set created_at = now()
where created_at is null;

alter table public.transactions
  alter column created_at set default now();

create index if not exists transactions_user_id_archived_date_idx
  on public.transactions(user_id, is_archived, transaction_date desc);
```

Verify archived transactions:

```sql
select id, amount, type, is_archived, transaction_date, created_at
from public.transactions
where is_archived = true
order by transaction_date desc;
```

## 8. Loan Contribution SQL

Loan payment contributors are stored in `loan_payment_contributions`.

Run this once if the table does not exist:

```sql
create table if not exists public.loan_payment_contributions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  loan_id uuid not null references public.loans(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete restrict,
  amount numeric(12, 2) not null check (amount > 0),
  paid_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists loan_payment_contributions_loan_id_idx
  on public.loan_payment_contributions(loan_id);

create index if not exists loan_payment_contributions_user_loan_idx
  on public.loan_payment_contributions(user_id, loan_id);

alter table public.loan_payment_contributions enable row level security;

drop policy if exists "loan_payment_contributions_owner_select"
on public.loan_payment_contributions;
create policy "loan_payment_contributions_owner_select"
on public.loan_payment_contributions for select to authenticated
using (user_id = auth.uid());

drop policy if exists "loan_payment_contributions_owner_insert"
on public.loan_payment_contributions;
create policy "loan_payment_contributions_owner_insert"
on public.loan_payment_contributions for insert to authenticated
with check (user_id = auth.uid());
```

## 9. Android Notification Requirements

The app uses local notifications for reminders.

Android manifest permissions include:

- `RECEIVE_BOOT_COMPLETED`
- `VIBRATE`
- `USE_EXACT_ALARM`
- `POST_NOTIFICATIONS`

The app also registers notification receivers for scheduled notifications and boot recovery.

Core library desugaring must stay enabled because `flutter_local_notifications` requires it.

## 10. Developer Commands

Install dependencies:

```powershell
flutter pub get
```

Analyze manually:

```powershell
flutter analyze
```

Run manually:

```powershell
flutter run
```

Do not run heavy commands automatically on slow machines. Run them manually and review the terminal output.

## 11. Safe Development Rules

- Keep changes small and focused.
- Do not rewrite unrelated screens.
- Keep existing UI and behavior unless the task asks for a change.
- Run Supabase SQL manually in the Supabase SQL Editor.
- After database changes, verify with a small `select` query.
- After code changes, run `flutter analyze` manually.
