-- ============================================================
-- Not Programming — حماية محتوى الكورسات (فيديو / PDF / امتحان)
-- شغّله مرة واحدة: Supabase → SQL Editor → New query → Run
-- آمن لإعادة التشغيل. مبيمسحش أي بيانات.
-- ============================================================

-- 1) جدول المحتوى (نصوص وروابط فقط — مفيش ملفات، فمساحته شبه صفر)
create table if not exists course_items (
  id text primary key default gen_random_uuid()::text,
  cid uuid not null references courses(id) on delete cascade,
  type text not null,
  title text not null,
  url text,
  questions jsonb,
  "createdAt" bigint
);
create index if not exists course_items_cid_idx on course_items(cid);

-- 2) نقل المحتوى القديم من courses.items (بنفس الـ id عشان نتايج الامتحانات تفضل شغالة)
insert into course_items (id, cid, type, title, url, questions, "createdAt")
select i->>'id', c.id, coalesce(i->>'type','video'), coalesce(i->>'title',''),
       i->>'url', i->'questions', (extract(epoch from now())*1000)::bigint + n
from courses c, jsonb_array_elements(c.items) with ordinality as t(i, n)
where jsonb_typeof(c.items) = 'array' and (i->>'id') is not null
on conflict (id) do nothing;

-- 3) عدّاد المحتوى (عشان الطالب يشوف "5 عناصر" من غير ما يشوف الروابط)
alter table courses add column if not exists icount int default 0;
update courses c set icount = (select count(*) from course_items x where x.cid = c.id);
update courses set items = '[]'::jsonb;   -- الروابط القديمة المكشوفة اتمسحت من الجدول العام

create or replace function sync_icount() returns trigger as $$
begin
  update courses set icount = (select count(*) from course_items where cid = coalesce(new.cid, old.cid))
  where id = coalesce(new.cid, old.cid);
  return null;
end $$ language plpgsql security definer;
drop trigger if exists trg_icount on course_items;
create trigger trg_icount after insert or delete on course_items
  for each row execute function sync_icount();

-- 4) الحماية: المحتوى يظهر للمعلم، أو كورس مجاني، أو طالب دفعته اتقبلت
alter table course_items enable row level security;
drop policy if exists "ci_select" on course_items;
drop policy if exists "ci_insert" on course_items;
drop policy if exists "ci_update" on course_items;
drop policy if exists "ci_delete" on course_items;
create policy "ci_select" on course_items for select using (
  is_admin()
  or exists (select 1 from courses c where c.id = course_items.cid
             and coalesce(c.price,0) = 0 and auth.role() = 'authenticated')
  or exists (select 1 from payments p where p.cid = course_items.cid
             and p.email = (auth.jwt() ->> 'email') and p.s = 'a')
);
create policy "ci_insert" on course_items for insert with check (is_admin());
create policy "ci_update" on course_items for update using (is_admin());
create policy "ci_delete" on course_items for delete using (is_admin());

-- 5) ثغرة مهمة: كان ممكن الطالب يضيف دفعة بحالة "مقبولة" بنفسه. دلوقتي الطالب يقدر يضيف "قيد المراجعة" بس
drop policy if exists "payments_insert_own_or_admin" on payments;
create policy "payments_insert_own_or_admin" on payments for insert
  with check (is_admin() or ((auth.jwt() ->> 'email') = email and coalesce(s,'p') = 'p'));

-- 6) تحديث لحظي
do $$ begin
  alter publication supabase_realtime add table course_items;
exception when duplicate_object then null; end $$;
