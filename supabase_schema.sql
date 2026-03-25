-- ══════════════════════════════════════════════════════════════════
--  Teamply Marketing Dashboard – Supabase 전체 스키마
--  Project : waxjtcxdgulbdofycywr
--  실행방법 : Supabase Dashboard > SQL Editor > New query > 붙여넣기 > Run
-- ══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────
--  0. 기존 테이블 초기화 (재실행 시 충돌 방지)
-- ──────────────────────────────────────────────────────────────────
drop table if exists marketing_tasks    cascade;
drop table if exists marketing_members  cascade;
drop table if exists shared_projects    cascade;
drop table if exists user_meta          cascade;
drop table if exists user_data          cascade;

-- ──────────────────────────────────────────────────────────────────
--  1. user_data  –  팀/프로젝트/KPI/캠페인/지역/고객/멤버 저장
--     구조: uid + table_name + record_id → data(jsonb)
-- ──────────────────────────────────────────────────────────────────
create table user_data (
  id          uuid        default gen_random_uuid() primary key,
  uid         text        not null,
  table_name  text        not null,   -- 'teams' | 'projects' | 'kpis' | 'campaigns' | 'regions' | 'clients' | 'members'
  record_id   text        not null,
  data        jsonb       not null    default '{}',
  updated_at  timestamptz default now(),
  unique (uid, table_name, record_id)
);

-- 인덱스
create index idx_user_data_uid            on user_data (uid);
create index idx_user_data_uid_table      on user_data (uid, table_name);
create index idx_user_data_updated        on user_data (updated_at desc);

-- RLS 활성화
alter table user_data enable row level security;

-- 정책: 자신의 데이터만 읽기/쓰기/삭제
create policy "user_data_select" on user_data
  for select using (uid = auth.uid()::text);

create policy "user_data_insert" on user_data
  for insert with check (uid = auth.uid()::text);

create policy "user_data_update" on user_data
  for update using (uid = auth.uid()::text);

create policy "user_data_delete" on user_data
  for delete using (uid = auth.uid()::text);

-- ──────────────────────────────────────────────────────────────────
--  2. user_meta  –  유저 프로필 및 환경설정
-- ──────────────────────────────────────────────────────────────────
create table user_meta (
  uid          text        primary key,
  email        text,
  display_name text,
  last_seen    timestamptz default now(),
  prefs        jsonb       default '{}'
);

alter table user_meta enable row level security;

create policy "user_meta_select" on user_meta
  for select using (uid = auth.uid()::text);

create policy "user_meta_insert" on user_meta
  for insert with check (uid = auth.uid()::text);

create policy "user_meta_update" on user_meta
  for update using (uid = auth.uid()::text);

create policy "user_meta_delete" on user_meta
  for delete using (uid = auth.uid()::text);

-- ──────────────────────────────────────────────────────────────────
--  3. shared_projects  –  팀 공유 프로젝트 (팀원 전체 공유)
-- ──────────────────────────────────────────────────────────────────
create table shared_projects (
  id          uuid        default gen_random_uuid() primary key,
  team_id     text        not null,
  record_id   text        not null,
  data        jsonb       not null    default '{}',
  updated_at  timestamptz default now(),
  unique (team_id, record_id)
);

create index idx_shared_projects_team on shared_projects (team_id);

alter table shared_projects enable row level security;

-- 공유 프로젝트는 인증된 모든 유저가 읽기 가능 (팀 공유 목적)
create policy "shared_projects_select" on shared_projects
  for select using (auth.role() = 'authenticated');

create policy "shared_projects_insert" on shared_projects
  for insert with check (auth.role() = 'authenticated');

create policy "shared_projects_update" on shared_projects
  for update using (auth.role() = 'authenticated');

create policy "shared_projects_delete" on shared_projects
  for delete using (auth.role() = 'authenticated');

-- ──────────────────────────────────────────────────────────────────
--  4. marketing_members  –  마케팅 담당자
-- ──────────────────────────────────────────────────────────────────
create table marketing_members (
  id          text        primary key,          -- UUID from Flutter
  uid         text        not null,             -- auth.uid()
  team_id     text,
  data        jsonb       not null    default '{}',
  updated_at  timestamptz default now()
);

create index idx_mkt_members_uid     on marketing_members (uid);
create index idx_mkt_members_team    on marketing_members (team_id);

alter table marketing_members enable row level security;

create policy "mkt_members_select" on marketing_members
  for select using (uid = auth.uid()::text);

create policy "mkt_members_insert" on marketing_members
  for insert with check (uid = auth.uid()::text);

create policy "mkt_members_update" on marketing_members
  for update using (uid = auth.uid()::text);

create policy "mkt_members_delete" on marketing_members
  for delete using (uid = auth.uid()::text);

-- ──────────────────────────────────────────────────────────────────
--  5. marketing_tasks  –  마케팅 태스크
-- ──────────────────────────────────────────────────────────────────
create table marketing_tasks (
  id          text        primary key,
  uid         text        not null,
  team_id     text,
  data        jsonb       not null    default '{}',
  updated_at  timestamptz default now()
);

create index idx_mkt_tasks_uid     on marketing_tasks (uid);
create index idx_mkt_tasks_team    on marketing_tasks (team_id);
create index idx_mkt_tasks_updated on marketing_tasks (updated_at desc);

alter table marketing_tasks enable row level security;

create policy "mkt_tasks_select" on marketing_tasks
  for select using (uid = auth.uid()::text);

create policy "mkt_tasks_insert" on marketing_tasks
  for insert with check (uid = auth.uid()::text);

create policy "mkt_tasks_update" on marketing_tasks
  for update using (uid = auth.uid()::text);

create policy "mkt_tasks_delete" on marketing_tasks
  for delete using (uid = auth.uid()::text);

-- ──────────────────────────────────────────────────────────────────
--  6. Realtime 구독 활성화 (스트림 동기화용)
-- ──────────────────────────────────────────────────────────────────
alter publication supabase_realtime add table user_data;
alter publication supabase_realtime add table shared_projects;
alter publication supabase_realtime add table marketing_tasks;

-- ──────────────────────────────────────────────────────────────────
--  완료 확인
-- ──────────────────────────────────────────────────────────────────
select
  schemaname,
  tablename,
  rowsecurity as rls_enabled
from pg_tables
where schemaname = 'public'
  and tablename in (
    'user_data','user_meta','shared_projects',
    'marketing_members','marketing_tasks'
  )
order by tablename;
