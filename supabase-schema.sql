-- ============================================================
-- Not Programming — Supabase schema (بديل Firebase)
-- شغّل هذا الملف بالكامل من: Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================

-- امسح أي جداول قديمة لو بتعيد التشغيل (آمن لو أول مرة)
drop table if exists exam_results cascade;
drop table if exists messages cascade;
drop table if exists edit_requests cascade;
drop table if exists payments cascade;
drop table if exists courses cascade;
drop table if exists settings cascade;
drop table if exists teacher_profile cascade;
drop table if exists profiles cascade;

-- ------------------------------------------------------------
-- profiles  (بديل users/{uid} في Firestore — نفس الـ id بتاع auth.users)
-- ------------------------------------------------------------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  email text,
  age text,
  g int default 0,
  phone text,
  parent text,
  photo text default '',
  date text,
  "createdAt" bigint,
  "lastActive" bigint
);

-- ------------------------------------------------------------
-- courses
-- ------------------------------------------------------------
create table courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  "desc" text default '',
  g int default 0,
  tr text,
  price numeric default 0,
  items jsonb default '[]'::jsonb,
  img text,
  "createdAt" bigint
);

-- ------------------------------------------------------------
-- settings (صف واحد فقط id='main')
-- ------------------------------------------------------------
create table settings (
  id text primary key default 'main',
  wallet text default '01027944588',
  insta text default 'mohammed577y@instapay',
  ai text default ''
);
insert into settings (id) values ('main');

-- ------------------------------------------------------------
-- teacher_profile (صف واحد فقط id='main')
-- ------------------------------------------------------------
create table teacher_profile (
  id text primary key default 'main',
  name text default 'Mohammed Yasser',
  photo text default '',
  bio text default ''
);
insert into teacher_profile (id) values ('main');

-- ------------------------------------------------------------
-- payments
-- ------------------------------------------------------------
create table payments (
  id uuid primary key default gen_random_uuid(),
  uid uuid,
  email text,
  name text,
  phone text default '',
  cid uuid,
  title text,
  amount numeric,
  m text,
  img text,
  ts bigint,
  s text default 'p'
);

-- ------------------------------------------------------------
-- edit_requests
-- ------------------------------------------------------------
create table edit_requests (
  id uuid primary key default gen_random_uuid(),
  uid uuid,
  email text,
  name text,
  ch jsonb,
  ts bigint,
  s text default 'p'
);

-- ------------------------------------------------------------
-- messages
-- ------------------------------------------------------------
create table messages (
  id uuid primary key default gen_random_uuid(),
  uid uuid,
  email text,
  name text,
  "from" text,
  text text,
  ts bigint
);

-- ------------------------------------------------------------
-- exam_results
-- ------------------------------------------------------------
create table exam_results (
  id uuid primary key default gen_random_uuid(),
  uid uuid,
  email text,
  name text,
  "courseId" uuid,
  "courseTitle" text,
  "itemId" text,
  "examTitle" text,
  answers jsonb,
  score int,
  max int,
  ts bigint
);

-- ============================================================
-- Row Level Security — نفس منطق firestore.rules بالضبط
-- ============================================================
alter table profiles enable row level security;
alter table courses enable row level security;
alter table settings enable row level security;
alter table teacher_profile enable row level security;
alter table payments enable row level security;
alter table edit_requests enable row level security;
alter table messages enable row level security;
alter table exam_results enable row level security;

-- دالة مساعدة: هل المستخدم الحالي هو المعلم؟
create or replace function is_admin() returns boolean as $$
  select (auth.jwt() ->> 'email') = 'ghhbvvbnt@gmail.com';
$$ language sql stable;

-- امسح أي سياسات قديمة (لو الملف اتشغّل قبل كده جزئيًا) عشان نقدر نعيد التشغيل بأمان
drop policy if exists "profiles_select_own_or_admin" on profiles;
drop policy if exists "profiles_insert_own" on profiles;
drop policy if exists "profiles_update_own_or_admin" on profiles;
drop policy if exists "courses_select_authed" on courses;
drop policy if exists "courses_write_admin" on courses;
drop policy if exists "courses_update_admin" on courses;
drop policy if exists "courses_delete_admin" on courses;
drop policy if exists "settings_select_authed" on settings;
drop policy if exists "settings_write_admin" on settings;
drop policy if exists "teacher_profile_select_authed" on teacher_profile;
drop policy if exists "teacher_profile_write_admin" on teacher_profile;
drop policy if exists "payments_select_own_or_admin" on payments;
drop policy if exists "payments_insert_own_or_admin" on payments;
drop policy if exists "payments_update_admin" on payments;
drop policy if exists "edit_requests_select_own_or_admin" on edit_requests;
drop policy if exists "edit_requests_insert_own" on edit_requests;
drop policy if exists "edit_requests_update_admin" on edit_requests;
drop policy if exists "messages_select_own_or_admin" on messages;
drop policy if exists "messages_insert_own_or_admin" on messages;
drop policy if exists "exam_results_select_own_or_admin" on exam_results;
drop policy if exists "exam_results_insert_own" on exam_results;
drop policy if exists "students_read" on storage.objects;
drop policy if exists "students_write_own" on storage.objects;
drop policy if exists "students_update_own" on storage.objects;
drop policy if exists "teacher_read" on storage.objects;
drop policy if exists "teacher_write_admin" on storage.objects;
drop policy if exists "teacher_update_admin" on storage.objects;
drop policy if exists "courses_bucket_read" on storage.objects;
drop policy if exists "courses_bucket_write_admin" on storage.objects;
drop policy if exists "payments_bucket_read" on storage.objects;
drop policy if exists "payments_bucket_write_own" on storage.objects;

-- profiles
create policy "profiles_select_own_or_admin" on profiles for select
  using (auth.uid() = id or is_admin());
create policy "profiles_insert_own" on profiles for insert
  with check (auth.uid() = id);
create policy "profiles_update_own_or_admin" on profiles for update
  using (auth.uid() = id or is_admin());

-- courses
create policy "courses_select_authed" on courses for select
  using (auth.role() = 'authenticated');
create policy "courses_write_admin" on courses for insert
  with check (is_admin());
create policy "courses_update_admin" on courses for update
  using (is_admin());
create policy "courses_delete_admin" on courses for delete
  using (is_admin());

-- settings
create policy "settings_select_authed" on settings for select
  using (auth.role() = 'authenticated');
create policy "settings_write_admin" on settings for update
  using (is_admin());

-- teacher_profile
create policy "teacher_profile_select_authed" on teacher_profile for select
  using (auth.role() = 'authenticated');
create policy "teacher_profile_write_admin" on teacher_profile for update
  using (is_admin());

-- payments
create policy "payments_select_own_or_admin" on payments for select
  using (is_admin() or (auth.jwt() ->> 'email') = email);
create policy "payments_insert_own_or_admin" on payments for insert
  with check (is_admin() or (auth.jwt() ->> 'email') = email);
create policy "payments_update_admin" on payments for update
  using (is_admin());

-- edit_requests
create policy "edit_requests_select_own_or_admin" on edit_requests for select
  using (is_admin() or (auth.jwt() ->> 'email') = email);
create policy "edit_requests_insert_own" on edit_requests for insert
  with check ((auth.jwt() ->> 'email') = email);
create policy "edit_requests_update_admin" on edit_requests for update
  using (is_admin());

-- messages
create policy "messages_select_own_or_admin" on messages for select
  using (is_admin() or (auth.jwt() ->> 'email') = email);
create policy "messages_insert_own_or_admin" on messages for insert
  with check (is_admin() or (auth.jwt() ->> 'email') = email);

-- exam_results
create policy "exam_results_select_own_or_admin" on exam_results for select
  using (is_admin() or (auth.jwt() ->> 'email') = email);
create policy "exam_results_insert_own" on exam_results for insert
  with check ((auth.jwt() ->> 'email') = email);

-- ============================================================
-- Realtime — فعّل التحديث اللحظي (بديل onSnapshot)
-- ============================================================
alter publication supabase_realtime add table profiles;
alter publication supabase_realtime add table courses;
alter publication supabase_realtime add table settings;
alter publication supabase_realtime add table teacher_profile;
alter publication supabase_realtime add table payments;
alter publication supabase_realtime add table edit_requests;
alter publication supabase_realtime add table messages;
alter publication supabase_realtime add table exam_results;

-- ============================================================
-- Storage buckets — بديل storage.rules
-- ============================================================
insert into storage.buckets (id, name, public)
values ('students', 'students', true),
       ('teacher', 'teacher', true),
       ('courses', 'courses', true),
       ('payments', 'payments', true)
on conflict (id) do nothing;

-- students: أي مستخدم مسجّل يقرأ، وكل طالب يرفع صورته فقط (uid.jpg)
create policy "students_read" on storage.objects for select
  using (bucket_id = 'students' and auth.role() = 'authenticated');
create policy "students_write_own" on storage.objects for insert
  with check (bucket_id = 'students' and name = auth.uid()::text || '.jpg');
create policy "students_update_own" on storage.objects for update
  using (bucket_id = 'students' and name = auth.uid()::text || '.jpg');

-- teacher: أي مستخدم مسجّل يقرأ، المعلم فقط يرفع
create policy "teacher_read" on storage.objects for select
  using (bucket_id = 'teacher' and auth.role() = 'authenticated');
create policy "teacher_write_admin" on storage.objects for insert
  with check (bucket_id = 'teacher' and is_admin());
create policy "teacher_update_admin" on storage.objects for update
  using (bucket_id = 'teacher' and is_admin());

-- courses: أي مستخدم مسجّل يقرأ، المعلم فقط يرفع
create policy "courses_bucket_read" on storage.objects for select
  using (bucket_id = 'courses' and auth.role() = 'authenticated');
create policy "courses_bucket_write_admin" on storage.objects for insert
  with check (bucket_id = 'courses' and is_admin());

-- payments: أي مستخدم مسجّل يقرأ، وكل طالب يرفع إيصالاته فقط (uid_*.jpg)
create policy "payments_bucket_read" on storage.objects for select
  using (bucket_id = 'payments' and auth.role() = 'authenticated');
create policy "payments_bucket_write_own" on storage.objects for insert
  with check (bucket_id = 'payments' and name like auth.uid()::text || '_%');

-- ============================================================
-- تم! ارجع لملف SUPABASE_SETUP.md للخطوات المتبقية
-- ============================================================
