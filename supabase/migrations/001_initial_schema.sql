-- AOT initial Supabase schema
-- Run this in Supabase SQL Editor for a NEW project.
-- Never put the Supabase service_role key in browser code.

create extension if not exists pgcrypto;

create type public.app_role as enum ('student', 'admin');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  role public.app_role not null default 'student',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text,
  phone text,
  service_interest text not null,
  message text,
  source text not null default 'website',
  status text not null default 'new'
    check (status in ('new', 'contacted', 'in_progress', 'closed')),
  created_at timestamptz not null default now()
);

create table public.school_enquiries (
  id uuid primary key default gen_random_uuid(),
  institution_name text not null,
  contact_name text not null,
  email text not null,
  interest text not null,
  message text,
  status text not null default 'new'
    check (status in ('new', 'contacted', 'in_progress', 'closed')),
  created_at timestamptz not null default now()
);

create table public.student_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  full_name text not null,
  email text not null,
  phone text,
  utme_score integer check (utme_score between 0 and 400),
  utme_year integer,
  olevel_summary text,
  preferred_institution text,
  preferred_course text,
  second_choice_institution text,
  application_status text not null default 'submitted'
    check (application_status in ('draft', 'submitted', 'under_review', 'completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.admission_records (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.student_applications(id) on delete cascade,
  stage text not null
    check (stage in ('CAPS Upload', 'Screening', 'Admission Letter', 'Campus Clearance')),
  status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'completed', 'needs_action')),
  note text,
  next_action text,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (application_id, stage)
);

create table public.tutoring_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  full_name text not null,
  email text,
  phone text,
  subjects text[] not null default '{}',
  exam_type text,
  preferred_format text,
  message text,
  status text not null default 'new'
    check (status in ('new', 'contacted', 'scheduled', 'completed', 'closed')),
  created_at timestamptz not null default now()
);

create table public.research_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  full_name text not null,
  email text,
  phone text,
  support_type text not null,
  project_summary text,
  status text not null default 'new'
    check (status in ('new', 'contacted', 'in_progress', 'completed', 'closed')),
  created_at timestamptz not null default now()
);

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  service_codes text[] not null default '{}',
  price_amount numeric(12,2),
  price_currency text not null default 'NGN',
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.testimonials (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  quote text not null,
  context text,
  is_approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.site_settings (
  setting_key text primary key,
  setting_value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute procedure public.set_updated_at();
create trigger applications_set_updated_at before update on public.student_applications
  for each row execute procedure public.set_updated_at();
create trigger packages_set_updated_at before update on public.packages
  for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.leads enable row level security;
alter table public.school_enquiries enable row level security;
alter table public.student_applications enable row level security;
alter table public.admission_records enable row level security;
alter table public.tutoring_requests enable row level security;
alter table public.research_requests enable row level security;
alter table public.packages enable row level security;
alter table public.testimonials enable row level security;
alter table public.site_settings enable row level security;

-- A signed-in user can read and update their own basic profile.
-- The role column is deliberately excluded from the user's update policy below.
create policy "Users read own profile or admins read all"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or public.is_admin());

create policy "Users update own basic profile"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()) and role = 'student');

create policy "Admins manage profiles"
on public.profiles for all to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Public forms may submit enquiries, but visitors cannot read them.
create policy "Public can submit leads"
on public.leads for insert to anon, authenticated
with check (status = 'new');

create policy "Admins manage leads"
on public.leads for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Public can submit school enquiries"
on public.school_enquiries for insert to anon, authenticated
with check (status = 'new');

create policy "Admins manage school enquiries"
on public.school_enquiries for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Students read own applications"
on public.student_applications for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy "Students create own applications"
on public.student_applications for insert to authenticated
with check (user_id = (select auth.uid()));

create policy "Students update own applications"
on public.student_applications for update to authenticated
using (user_id = (select auth.uid()) or public.is_admin())
with check (user_id = (select auth.uid()) or public.is_admin());

create policy "Admins delete applications"
on public.student_applications for delete to authenticated
using (public.is_admin());

create policy "Students read own admission records"
on public.admission_records for select to authenticated
using (
  public.is_admin() or exists (
    select 1 from public.student_applications a
    where a.id = application_id and a.user_id = (select auth.uid())
  )
);

create policy "Admins manage admission records"
on public.admission_records for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Users submit tutoring requests"
on public.tutoring_requests for insert to authenticated
with check (user_id = (select auth.uid()) or user_id is null);

create policy "Admins manage tutoring requests"
on public.tutoring_requests for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Users submit research requests"
on public.research_requests for insert to authenticated
with check (user_id = (select auth.uid()) or user_id is null);

create policy "Admins manage research requests"
on public.research_requests for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Public read published packages"
on public.packages for select to anon, authenticated
using (is_published = true or public.is_admin());

create policy "Admins manage packages"
on public.packages for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Public read approved testimonials"
on public.testimonials for select to anon, authenticated
using (is_approved = true or public.is_admin());

create policy "Admins manage testimonials"
on public.testimonials for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins manage site settings"
on public.site_settings for all to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Explicitly grant only the table operations used by the app.
grant usage on schema public to anon, authenticated;
grant select on public.packages, public.testimonials to anon, authenticated;
grant insert on public.leads, public.school_enquiries to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.student_applications to authenticated;
grant select, insert, update, delete on public.admission_records to authenticated;
grant insert on public.tutoring_requests, public.research_requests to authenticated;
grant select, insert, update, delete on public.leads, public.school_enquiries to authenticated;
grant select, insert, update, delete on public.tutoring_requests, public.research_requests to authenticated;
grant select, insert, update, delete on public.packages, public.testimonials, public.site_settings to authenticated;
