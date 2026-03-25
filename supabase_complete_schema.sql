-- ════════════════════════════════════════════════════════════════
--  Teamply – Supabase 완전 스키마 (Option B)
--  실행: https://supabase.com/dashboard/project/waxjtcxdgulbdofycywr/sql/new
-- ════════════════════════════════════════════════════════════════

-- ─── 1. user_data 보강 ──────────────────────────────────────────
-- unique constraint (uid, table_name, record_id) 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name='user_data'
      AND constraint_name='user_data_uid_table_record_key'
  ) THEN
    ALTER TABLE user_data
      ADD CONSTRAINT user_data_uid_table_record_key
      UNIQUE (uid, table_name, record_id);
  END IF;
END $$;

-- RLS: 자신의 uid만 접근
ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_data_select_own" ON user_data;
DROP POLICY IF EXISTS "user_data_insert_own" ON user_data;
DROP POLICY IF EXISTS "user_data_update_own" ON user_data;
DROP POLICY IF EXISTS "user_data_delete_own" ON user_data;
CREATE POLICY "user_data_select_own" ON user_data FOR SELECT USING (uid = auth.uid()::text);
CREATE POLICY "user_data_insert_own" ON user_data FOR INSERT WITH CHECK (uid = auth.uid()::text);
CREATE POLICY "user_data_update_own" ON user_data FOR UPDATE USING (uid = auth.uid()::text);
CREATE POLICY "user_data_delete_own" ON user_data FOR DELETE USING (uid = auth.uid()::text);

-- ─── 2. user_meta 보강 ──────────────────────────────────────────
ALTER TABLE user_meta ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_meta_own" ON user_meta;
CREATE POLICY "user_meta_own" ON user_meta
  USING (uid = auth.uid()::text)
  WITH CHECK (uid = auth.uid()::text);

-- ─── 3. shared_projects 보강 ────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name='shared_projects'
      AND constraint_name='shared_projects_team_record_key'
  ) THEN
    ALTER TABLE shared_projects
      ADD CONSTRAINT shared_projects_team_record_key
      UNIQUE (team_id, record_id);
  END IF;
END $$;

ALTER TABLE shared_projects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "shared_projects_all" ON shared_projects;
CREATE POLICY "shared_projects_all" ON shared_projects
  USING (true) WITH CHECK (true);

-- ─── 4. marketing_members 테이블 ───────────────────────────────
CREATE TABLE IF NOT EXISTS marketing_members (
  id         text PRIMARY KEY,
  uid        text NOT NULL,
  team_id    text,
  data       jsonb NOT NULL DEFAULT '{}',
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE marketing_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "marketing_members_own" ON marketing_members;
CREATE POLICY "marketing_members_own" ON marketing_members
  USING (uid = auth.uid()::text)
  WITH CHECK (uid = auth.uid()::text);

CREATE INDEX IF NOT EXISTS idx_mkt_members_uid  ON marketing_members(uid);
CREATE INDEX IF NOT EXISTS idx_mkt_members_team ON marketing_members(team_id);

-- ─── 5. marketing_tasks 테이블 ─────────────────────────────────
CREATE TABLE IF NOT EXISTS marketing_tasks (
  id         text PRIMARY KEY,
  uid        text NOT NULL,
  team_id    text,
  data       jsonb NOT NULL DEFAULT '{}',
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE marketing_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "marketing_tasks_own" ON marketing_tasks;
CREATE POLICY "marketing_tasks_own" ON marketing_tasks
  USING (uid = auth.uid()::text)
  WITH CHECK (uid = auth.uid()::text);

CREATE INDEX IF NOT EXISTS idx_mkt_tasks_uid  ON marketing_tasks(uid);
CREATE INDEX IF NOT EXISTS idx_mkt_tasks_team ON marketing_tasks(team_id);

-- ─── 6. Realtime 활성화 ─────────────────────────────────────────
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE user_data;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE marketing_members;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE marketing_tasks;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- ─── 확인 쿼리 ──────────────────────────────────────────────────
SELECT
  t.table_name,
  COUNT(c.column_name) AS col_count,
  COALESCE(
    (SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
     FROM information_schema.columns c2
     WHERE c2.table_name = t.table_name AND c2.table_schema = 'public'),
    ''
  ) AS columns
FROM information_schema.tables t
LEFT JOIN information_schema.columns c
  ON c.table_name = t.table_name AND c.table_schema = 'public'
WHERE t.table_schema = 'public'
  AND t.table_name IN (
    'user_data','user_meta','shared_projects',
    'marketing_members','marketing_tasks'
  )
GROUP BY t.table_name
ORDER BY t.table_name;
