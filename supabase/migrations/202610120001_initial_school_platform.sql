create extension if not exists pgcrypto;

create type public.school_role as enum ('owner','administrator','teaching_staff','non_teaching_staff','student','parent');
create type public.membership_status as enum ('invited','active','suspended');
create type public.record_status as enum ('draft','submitted','returned','approved','published');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  owner_id uuid not null references auth.users(id),
  email text,
  phone text,
  address text,
  description text,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.school_memberships (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade, role public.school_role not null,
  status public.membership_status not null default 'active', created_at timestamptz not null default now(),
  unique (school_id,user_id)
);
create index memberships_user_idx on public.school_memberships(user_id, status);

create table public.academic_sessions (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  name text not null, starts_on date, ends_on date, is_current boolean not null default false,
  created_at timestamptz not null default now(), unique(school_id,name), unique(school_id,id)
);
create table public.school_classes (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  name text not null, level text, created_at timestamptz not null default now(), unique(school_id,name), unique(school_id,id)
);
create table public.class_arms (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null, name text not null, created_at timestamptz not null default now(),
  foreign key(school_id,class_id) references public.school_classes(school_id,id) on delete cascade,
  unique(class_id,name), unique(school_id,id)
);
create table public.students (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null, class_id uuid, class_arm_id uuid,
  admission_number text not null, first_name text not null, last_name text not null,
  date_of_birth date, status text not null default 'active' check(status in ('active','inactive','graduated')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(school_id,class_id) references public.school_classes(school_id,id),
  foreign key(school_id,class_arm_id) references public.class_arms(school_id,id),
  unique(school_id,admission_number), unique(school_id,id)
);
create index students_class_idx on public.students(school_id,class_id,class_arm_id);
create table public.guardian_links (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null, guardian_user_id uuid not null references auth.users(id) on delete cascade,
  relationship text, verified_at timestamptz, created_at timestamptz not null default now(),
  foreign key(school_id,student_id) references public.students(school_id,id) on delete cascade,
  unique(student_id,guardian_user_id)
);
create table public.staff (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null, staff_number text not null,
  first_name text not null, last_name text not null, staff_type text not null check(staff_type in ('teaching','non_teaching')),
  department text, payroll_enabled boolean not null default false, created_at timestamptz not null default now(),
  unique(school_id,staff_number), unique(school_id,id)
);
create table public.subjects (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  name text not null, code text, created_at timestamptz not null default now(), unique(school_id,name), unique(school_id,id)
);
create table public.teacher_assignments (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  staff_id uuid not null, class_id uuid not null, subject_id uuid not null,
  foreign key(school_id,staff_id) references public.staff(school_id,id) on delete cascade,
  foreign key(school_id,class_id) references public.school_classes(school_id,id) on delete cascade,
  foreign key(school_id,subject_id) references public.subjects(school_id,id) on delete cascade,
  unique(staff_id,class_id,subject_id)
);
create table public.attendance (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null, session_id uuid not null, attendance_date date not null,
  state text not null check(state in ('present','absent','late','excused')), recorded_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key(school_id,student_id) references public.students(school_id,id) on delete cascade,
  foreign key(school_id,session_id) references public.academic_sessions(school_id,id) on delete cascade,
  unique(student_id,attendance_date)
);
create table public.lesson_notes (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null, subject_id uuid not null, author_id uuid not null references auth.users(id),
  title text not null, body text not null, status public.record_status not null default 'draft',
  published_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(school_id,class_id) references public.school_classes(school_id,id),
  foreign key(school_id,subject_id) references public.subjects(school_id,id)
);
create table public.assignments (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null, subject_id uuid not null, author_id uuid not null references auth.users(id),
  title text not null, instructions text not null, due_at timestamptz, status public.record_status not null default 'draft',
  created_at timestamptz not null default now(),
  foreign key(school_id,class_id) references public.school_classes(school_id,id),
  foreign key(school_id,subject_id) references public.subjects(school_id,id)
);
create table public.assignment_submissions (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null, body text, file_path text, submitted_at timestamptz not null default now(),
  score numeric(7,2), feedback text, graded_by uuid references auth.users(id), graded_at timestamptz,
  foreign key(school_id,student_id) references public.students(school_id,id) on delete cascade,
  unique(assignment_id,student_id)
);
create table public.assessments (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null, subject_id uuid not null, author_id uuid not null references auth.users(id),
  title text not null, instructions text, starts_at timestamptz, ends_at timestamptz, duration_minutes integer check(duration_minutes > 0),
  max_attempts integer not null default 1 check(max_attempts > 0), max_score numeric(7,2) not null check(max_score > 0),
  status public.record_status not null default 'draft', created_at timestamptz not null default now(),
  foreign key(school_id,class_id) references public.school_classes(school_id,id),
  foreign key(school_id,subject_id) references public.subjects(school_id,id)
);
create table public.assessment_questions (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  question jsonb not null, answer_key jsonb not null, points numeric(7,2) not null check(points > 0), position integer not null
);
create table public.assessment_attempts (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  student_id uuid not null, started_at timestamptz not null default now(), submitted_at timestamptz, state text not null default 'in_progress', score numeric(7,2),
  foreign key(school_id,student_id) references public.students(school_id,id) on delete cascade
);
create table public.results (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null, subject_id uuid not null, session_id uuid not null, term text not null,
  score numeric(7,2) not null check(score >= 0), max_score numeric(7,2) not null check(max_score > 0 and score <= max_score),
  category text not null, teacher_id uuid not null references auth.users(id), status public.record_status not null default 'draft',
  submitted_at timestamptz, approved_by uuid references auth.users(id), approved_at timestamptz, published_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(school_id,student_id) references public.students(school_id,id) on delete cascade,
  foreign key(school_id,subject_id) references public.subjects(school_id,id) on delete cascade,
  foreign key(school_id,session_id) references public.academic_sessions(school_id,id) on delete cascade
);
create index results_review_idx on public.results(school_id,status,session_id,term);
create table public.result_revisions (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  result_id uuid not null references public.results(id) on delete cascade, version integer not null,
  changed_by uuid not null references auth.users(id), reason text not null, before_record jsonb not null, after_record jsonb not null,
  created_at timestamptz not null default now(), unique(result_id,version)
);
create table public.grading_scales (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  label text not null, minimum_percent numeric(5,2) not null check(minimum_percent between 0 and 100),
  maximum_percent numeric(5,2) not null check(maximum_percent between minimum_percent and 100), remark text,
  unique(school_id,label)
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade, kind text not null, title text not null, body text not null,
  read_at timestamptz, created_at timestamptz not null default now(), dedupe_key text,
  unique(user_id,dedupe_key)
);
create table public.complaints (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  opened_by uuid not null references auth.users(id), subject text not null, message text not null,
  status text not null default 'open' check(status in ('open','in_review','resolved','closed')),
  assigned_to uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.timetable_entries (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null, subject_id uuid not null, teacher_id uuid references auth.users(id),
  weekday smallint not null check(weekday between 1 and 7), starts_at time not null, ends_at time not null check(ends_at > starts_at), room text,
  foreign key(school_id,class_id) references public.school_classes(school_id,id),
  foreign key(school_id,subject_id) references public.subjects(school_id,id)
);
create table public.payroll_records (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  staff_id uuid not null, period_start date not null, period_end date not null, gross_kobo bigint not null check(gross_kobo >= 0),
  deductions_kobo bigint not null default 0 check(deductions_kobo >= 0), status text not null default 'draft',
  approved_by uuid references auth.users(id), created_at timestamptz not null default now(),
  foreign key(school_id,staff_id) references public.staff(school_id,id) on delete cascade
);
create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(), code text not null unique, name text not null,
  monthly_kobo bigint check(monthly_kobo >= 0), annual_kobo bigint check(annual_kobo >= 0),
  trial_days integer not null default 30 check(trial_days >= 0), entitlements jsonb not null default '{}'::jsonb, enabled boolean not null default true
);
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id), status text not null check(status in ('trialing','active','past_due','cancelled','expired')),
  billing_period text not null check(billing_period in ('monthly','annual')), starts_at timestamptz not null, ends_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.payment_records (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  subscription_id uuid references public.subscriptions(id), provider text not null check(provider in ('paystack','flutterwave')),
  provider_reference text not null, amount_kobo bigint not null check(amount_kobo > 0), currency text not null default 'NGN',
  status text not null default 'pending', verified_at timestamptz, created_at timestamptz not null default now(), unique(provider,provider_reference)
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(), school_id uuid references public.schools(id) on delete cascade,
  actor_id uuid references auth.users(id), action text not null, entity_type text not null, entity_id uuid,
  reason text, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create or replace function public.has_school_role(target_school uuid, allowed public.school_role[])
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.school_memberships m where m.school_id=target_school and m.user_id=auth.uid() and m.status='active' and m.role=any(allowed));
$$;
revoke all on function public.has_school_role(uuid,public.school_role[]) from public;
grant execute on function public.has_school_role(uuid,public.school_role[]) to authenticated;

create or replace function public.register_school_for_owner(p_owner_id uuid,p_school_name text,p_owner_name text,p_owner_email text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare new_school_id uuid; new_slug text; base_slug text; attempt integer := 0; starter_plan uuid; trial_length integer;
begin
  if auth.role() <> 'service_role' then raise exception 'service role required'; end if;
  if length(trim(p_school_name)) < 2 or length(trim(p_school_name)) > 120 then raise exception 'invalid school name'; end if;
  select id into new_school_id from public.schools where owner_id=p_owner_id and lower(name)=lower(trim(p_school_name)) limit 1;
  if new_school_id is not null then return new_school_id; end if;
  base_slug := trim(both '-' from regexp_replace(lower(p_school_name), '[^a-z0-9]+', '-', 'g'));
  if base_slug = '' then base_slug := 'school'; end if;
  new_slug := left(base_slug,48);
  while exists(select 1 from public.schools where slug=new_slug) loop
    attempt := attempt + 1; new_slug := left(base_slug,43) || '-' || substr(encode(gen_random_bytes(4),'hex'),1,6);
    if attempt > 5 then raise exception 'could not allocate school slug'; end if;
  end loop;
  insert into public.profiles(id,full_name) values(p_owner_id,trim(p_owner_name)) on conflict(id) do update set full_name=excluded.full_name;
  insert into public.schools(name,slug,owner_id,email) values(trim(p_school_name),new_slug,p_owner_id,lower(trim(p_owner_email))) returning id into new_school_id;
  insert into public.school_memberships(school_id,user_id,role,status) values(new_school_id,p_owner_id,'owner','active');
  select id,trial_days into starter_plan,trial_length from public.subscription_plans where code='starter' and enabled=true;
  if starter_plan is not null then
    insert into public.subscriptions(school_id,plan_id,status,billing_period,starts_at,ends_at)
    values(new_school_id,starter_plan,'trialing','monthly',now(),now()+make_interval(days => trial_length));
  end if;
  insert into public.audit_logs(school_id,actor_id,action,entity_type,entity_id) values(new_school_id,p_owner_id,'school.created','school',new_school_id);
  return new_school_id;
end $$;
revoke all on function public.register_school_for_owner(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.register_school_for_owner(uuid,text,text,text) to service_role;

alter table public.profiles enable row level security;
alter table public.schools enable row level security;
alter table public.school_memberships enable row level security;
alter table public.academic_sessions enable row level security;
alter table public.school_classes enable row level security;
alter table public.class_arms enable row level security;
alter table public.students enable row level security;
alter table public.guardian_links enable row level security;
alter table public.staff enable row level security;
alter table public.subjects enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.attendance enable row level security;
alter table public.lesson_notes enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_submissions enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_questions enable row level security;
alter table public.assessment_attempts enable row level security;
alter table public.results enable row level security;
alter table public.result_revisions enable row level security;
alter table public.grading_scales enable row level security;
alter table public.notifications enable row level security;
alter table public.complaints enable row level security;
alter table public.timetable_entries enable row level security;
alter table public.payroll_records enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payment_records enable row level security;
alter table public.audit_logs enable row level security;

create policy "profile self read" on public.profiles for select to authenticated using(id=auth.uid());
create policy "profile self update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "member read school" on public.schools for select to authenticated using(public.has_school_role(id,enum_range(null::public.school_role)));
create policy "owner edit school" on public.schools for update to authenticated using(public.has_school_role(id,array['owner','administrator']::public.school_role[])) with check(public.has_school_role(id,array['owner','administrator']::public.school_role[]));
create policy "members read memberships" on public.school_memberships for select to authenticated using(public.has_school_role(school_id,enum_range(null::public.school_role)));
create policy "admins manage memberships" on public.school_memberships for all to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));

do $$ declare tbl text; begin
  foreach tbl in array array['academic_sessions','school_classes','class_arms','subjects','teacher_assignments','timetable_entries'] loop
    execute format('create policy %I on public.%I for select to authenticated using(public.has_school_role(school_id,enum_range(null::public.school_role)))',tbl||'_member_read',tbl);
    execute format('create policy %I on public.%I for all to authenticated using(public.has_school_role(school_id,array[''owner'',''administrator'']::public.school_role[])) with check(public.has_school_role(school_id,array[''owner'',''administrator'']::public.school_role[]))',tbl||'_admin_write',tbl);
  end loop;
  foreach tbl in array array['students','staff','attendance','lesson_notes','assignments','assignment_submissions','assessments','assessment_attempts','grading_scales','notifications','complaints'] loop
    execute format('create policy %I on public.%I for select to authenticated using(public.has_school_role(school_id,enum_range(null::public.school_role)))',tbl||'_member_read',tbl);
    execute format('create policy %I on public.%I for all to authenticated using(public.has_school_role(school_id,array[''owner'',''administrator'',''teaching_staff'']::public.school_role[])) with check(public.has_school_role(school_id,array[''owner'',''administrator'',''teaching_staff'']::public.school_role[]))',tbl||'_staff_write',tbl);
  end loop;
end $$;
create policy "school staff read questions" on public.assessment_questions for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "admins teachers manage questions" on public.assessment_questions for all to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "staff manage results" on public.results for all to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "families read published results" on public.results for select to authenticated using(status='published' and (exists(select 1 from public.students s where s.id=student_id and s.user_id=auth.uid()) or exists(select 1 from public.guardian_links g where g.student_id=results.student_id and g.guardian_user_id=auth.uid() and g.verified_at is not null)));
create policy "staff read revisions" on public.result_revisions for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "system insert revisions" on public.result_revisions for insert to authenticated with check(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]) and changed_by=auth.uid());
create policy "private payroll access" on public.payroll_records for select to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]) or exists(select 1 from public.staff s where s.id=staff_id and s.user_id=auth.uid()));
create policy "admins manage payroll" on public.payroll_records for all to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
create policy "staff private audits" on public.audit_logs for select to authenticated using(school_id is not null and public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
create policy "admins read subscriptions" on public.subscriptions for select to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
create policy "admins read payments" on public.payment_records for select to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
create policy "enabled plans public" on public.subscription_plans for select to anon,authenticated using(enabled=true);

-- Replace broad school-member reads on person- and communication-specific records.
drop policy students_member_read on public.students;
drop policy students_staff_write on public.students;
create policy "staff read student roster" on public.students for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "student read own record" on public.students for select to authenticated using(user_id=auth.uid());
create policy "guardian read linked students" on public.students for select to authenticated using(exists(select 1 from public.guardian_links g where g.school_id=students.school_id and g.student_id=students.id and g.guardian_user_id=auth.uid() and g.verified_at is not null));
create policy "admins manage students" on public.students for all to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
drop policy staff_member_read on public.staff;
drop policy staff_staff_write on public.staff;
create policy "school leaders read staff" on public.staff for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff','non_teaching_staff']::public.school_role[]));
create policy "staff read own record" on public.staff for select to authenticated using(user_id=auth.uid());
create policy "school leaders manage staff" on public.staff for all to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
drop policy attendance_member_read on public.attendance;
drop policy attendance_staff_write on public.attendance;
create policy "staff read attendance" on public.attendance for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "student read own attendance" on public.attendance for select to authenticated using(exists(select 1 from public.students s where s.id=student_id and s.school_id=attendance.school_id and s.user_id=auth.uid()));
create policy "guardian read linked attendance" on public.attendance for select to authenticated using(exists(select 1 from public.guardian_links g where g.school_id=attendance.school_id and g.student_id=attendance.student_id and g.guardian_user_id=auth.uid() and g.verified_at is not null));
create policy "staff record attendance" on public.attendance for insert to authenticated with check(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]) and recorded_by=auth.uid());
drop policy assignments_member_read on public.assignments;
drop policy assignments_staff_write on public.assignments;
create policy "staff read assignments" on public.assignments for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "students read published assignments" on public.assignments for select to authenticated using(status='published' and exists(select 1 from public.students s where s.school_id=assignments.school_id and s.class_id=assignments.class_id and s.user_id=auth.uid()));
create policy "staff manage assignments" on public.assignments for all to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
drop policy assessment_attempts_member_read on public.assessment_attempts;
drop policy assessment_attempts_staff_write on public.assessment_attempts;
create policy "staff read assessment attempts" on public.assessment_attempts for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "students read own attempts" on public.assessment_attempts for select to authenticated using(exists(select 1 from public.students s where s.school_id=assessment_attempts.school_id and s.id=assessment_attempts.student_id and s.user_id=auth.uid()));
drop policy notifications_member_read on public.notifications;
drop policy notifications_staff_write on public.notifications;
create policy "users read own notifications" on public.notifications for select to authenticated using(user_id=auth.uid());
create policy "users mark own notifications" on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "school staff create notifications" on public.notifications for insert to authenticated with check(public.has_school_role(school_id,array['owner','administrator','teaching_staff','non_teaching_staff']::public.school_role[]));
drop policy complaints_member_read on public.complaints;
drop policy complaints_staff_write on public.complaints;
create policy "complainant reads own complaints" on public.complaints for select to authenticated using(opened_by=auth.uid());
create policy "authorized staff read complaints" on public.complaints for select to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
create policy "user opens complaint" on public.complaints for insert to authenticated with check(opened_by=auth.uid() and public.has_school_role(school_id,enum_range(null::public.school_role)));
create policy "school admins update complaints" on public.complaints for update to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));

drop policy lesson_notes_member_read on public.lesson_notes;
drop policy lesson_notes_staff_write on public.lesson_notes;
create policy "staff read lesson notes" on public.lesson_notes for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "students read published lesson notes" on public.lesson_notes for select to authenticated using(status='published' and exists(select 1 from public.students s where s.school_id=lesson_notes.school_id and s.class_id=lesson_notes.class_id and s.user_id=auth.uid()));
create policy "staff author lesson notes" on public.lesson_notes for insert to authenticated with check(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]) and author_id=auth.uid());
create policy "admins or author edit notes" on public.lesson_notes for update to authenticated using(author_id=auth.uid() or public.has_school_role(school_id,array['owner','administrator']::public.school_role[])) with check(author_id=auth.uid() or public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
drop policy assignment_submissions_member_read on public.assignment_submissions;
drop policy assignment_submissions_staff_write on public.assignment_submissions;
create policy "students read own submissions" on public.assignment_submissions for select to authenticated using(exists(select 1 from public.students s where s.school_id=assignment_submissions.school_id and s.id=assignment_submissions.student_id and s.user_id=auth.uid()));
create policy "staff read submissions" on public.assignment_submissions for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "student submit own work" on public.assignment_submissions for insert to authenticated with check(exists(select 1 from public.students s where s.school_id=assignment_submissions.school_id and s.id=assignment_submissions.student_id and s.user_id=auth.uid()));
create policy "staff grade submissions" on public.assignment_submissions for update to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
drop policy assessments_member_read on public.assessments;
drop policy assessments_staff_write on public.assessments;
create policy "staff read assessments" on public.assessments for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "students read published assessments" on public.assessments for select to authenticated using(status='published' and exists(select 1 from public.students s where s.school_id=assessments.school_id and s.class_id=assessments.class_id and s.user_id=auth.uid()));
create policy "staff create assessments" on public.assessments for insert to authenticated with check(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]) and author_id=auth.uid());
create policy "staff update assessments" on public.assessments for update to authenticated using(author_id=auth.uid() or public.has_school_role(school_id,array['owner','administrator']::public.school_role[])) with check(author_id=auth.uid() or public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));
drop policy "staff manage results" on public.results;
create policy "school staff read results" on public.results for select to authenticated using(public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "teachers submit their own drafts" on public.results for insert to authenticated with check(teacher_id=auth.uid() and status in ('draft','submitted') and public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "teachers revise own unapproved results" on public.results for update to authenticated using(teacher_id=auth.uid() and status in ('draft','returned')) with check(teacher_id=auth.uid() and status in ('draft','submitted') and public.has_school_role(school_id,array['owner','administrator','teaching_staff']::public.school_role[]));
create policy "admins review and publish results" on public.results for update to authenticated using(public.has_school_role(school_id,array['owner','administrator']::public.school_role[])) with check(public.has_school_role(school_id,array['owner','administrator']::public.school_role[]));

insert into public.subscription_plans(code,name,monthly_kobo,trial_days,entitlements) values
 ('starter','Starter',2000000,30,'{"landing_page":true}'::jsonb),
 ('premium','Premium',5000000,30,'{"landing_page":true}'::jsonb),
 ('custom','Custom',null,30,'{"landing_page":true}'::jsonb)
on conflict(code) do nothing;
