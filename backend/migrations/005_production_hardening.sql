ALTER TABLE incidents
  ADD COLUMN IF NOT EXISTS client_report_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS idx_incidents_reporter_client_id
  ON incidents (reporter_id, client_report_id)
  WHERE client_report_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS lga_wards (
  id BIGSERIAL PRIMARY KEY,
  state VARCHAR(50) NOT NULL,
  lga VARCHAR(100) NOT NULL,
  ward VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (state, lga, ward)
);

INSERT INTO lga_wards (state, lga, ward) VALUES
  ('Lagos', 'Ikeja', 'Anifowoshe/Ikeja'),
  ('Lagos', 'Ikeja', 'Ojodu/Agidingbi/Omole'),
  ('Lagos', 'Ikeja', 'Alausa/Oregun/Olusosun'),
  ('Lagos', 'Ikeja', 'Airport/Onipetesi/Inilekere'),
  ('Lagos', 'Ikeja', 'Ipodo/Seriki Aro'),
  ('Lagos', 'Ikeja', 'Adekunle Village/Adeniyi Jones/Ogba'),
  ('Lagos', 'Ikeja', 'Oke-Ira/Aguda'),
  ('Lagos', 'Ikeja', 'Onigbongbo'),
  ('Lagos', 'Ikeja', 'GRA/Police Barracks'),
  ('Lagos', 'Ikeja', 'Wasimi/Opebi/Allen')
ON CONFLICT (state, lga, ward) DO NOTHING;

CREATE TABLE IF NOT EXISTS verifiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  state VARCHAR(50),
  lga VARCHAR(100) NOT NULL,
  ward VARCHAR(100),
  title VARCHAR(100),
  verified_by UUID NOT NULL REFERENCES users(id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_verifiers_area
  ON verifiers (state, lga, ward) WHERE is_active = true;

CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGSERIAL PRIMARY KEY,
  actor_id UUID REFERENCES users(id),
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  ip_address INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity
  ON audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor
  ON audit_logs (actor_id, created_at DESC);

CREATE TABLE IF NOT EXISTS trusted_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  relationship VARCHAR(50),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trusted_contacts_user
  ON trusted_contacts (user_id, created_at);

CREATE TABLE IF NOT EXISTS sos_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  client_alert_id UUID NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  incident_id UUID REFERENCES incidents(id),
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (
    status IN ('active', 'resolved', 'false_alarm')
  ),
  sms_sent_to TEXT[] NOT NULL DEFAULT '{}',
  triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES users(id),
  UNIQUE (user_id, client_alert_id)
);

CREATE INDEX IF NOT EXISTS idx_sos_alerts_user_time
  ON sos_alerts (user_id, triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_sos_alerts_active
  ON sos_alerts (triggered_at DESC) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS notification_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform VARCHAR(20) NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  push_token TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, push_token)
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  incident_id UUID REFERENCES incidents(id) ON DELETE CASCADE,
  title VARCHAR(160) NOT NULL,
  body TEXT NOT NULL,
  severity VARCHAR(10) NOT NULL DEFAULT 'medium',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_time
  ON notifications (user_id, created_at DESC);

-- The backend connects as the database owner. Authenticated mobile clients get
-- read-only Realtime access to visible incidents and their own profile data;
-- all mutations continue through the audited FastAPI service.
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE corroborations ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_advisories ENABLE ROW LEVEL SECURITY;
ALTER TABLE advisory_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE advisory_incident_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE verifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE trusted_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE lga_wards ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON users, incidents, corroborations, incident_flags,
      news_articles, security_advisories, advisory_sources,
      advisory_incident_links, verifiers, audit_logs, trusted_contacts,
      sos_alerts, notification_devices, notifications, lga_wards FROM anon;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON
      users, incidents, corroborations, incident_flags, news_articles,
      security_advisories, advisory_sources, advisory_incident_links,
      verifiers, audit_logs, trusted_contacts, sos_alerts,
      notification_devices, notifications, lga_wards FROM authenticated;

    GRANT SELECT ON users, incidents, security_advisories, lga_wards TO authenticated;

    DROP POLICY IF EXISTS authenticated_read_own_profile ON users;
    CREATE POLICY authenticated_read_own_profile ON users
      FOR SELECT TO authenticated
      USING (id = auth.uid());

    DROP POLICY IF EXISTS authenticated_read_visible_incidents ON incidents;
    CREATE POLICY authenticated_read_visible_incidents ON incidents
      FOR SELECT TO authenticated
      USING (
        is_hidden = false AND status <> 'false_report'
        AND EXISTS (
          SELECT 1 FROM users profile
          WHERE profile.id = auth.uid()
            AND profile.is_active = true
            AND profile.lga = incidents.lga
        )
      );

    DROP POLICY IF EXISTS authenticated_read_published_advisories
      ON security_advisories;
    CREATE POLICY authenticated_read_published_advisories
      ON security_advisories FOR SELECT TO authenticated
      USING (status = 'published' AND expires_at > NOW());

    DROP POLICY IF EXISTS authenticated_read_areas ON lga_wards;
    CREATE POLICY authenticated_read_areas ON lga_wards
      FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'incidents'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE incidents;
  END IF;
END $$;
