CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), phone VARCHAR(20) UNIQUE NOT NULL,
  name VARCHAR(100), role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('member', 'verifier', 'admin')),
  lga VARCHAR(100), ward VARCHAR(100), alert_radius_km DECIMAL(5,2) DEFAULT 5.0,
  location_precision VARCHAR(10) DEFAULT 'exact' CHECK (location_precision IN ('exact', 'ward', 'lga')),
  device_id VARCHAR(255), push_token TEXT, is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), reporter_id UUID REFERENCES users(id),
  type VARCHAR(30) NOT NULL CHECK (type IN ('kidnapping','armed_robbery','roadblock','cult_clash','banditry','fire_outbreak','suspicious_activity','other')),
  description TEXT, location GEOGRAPHY(POINT, 4326) NOT NULL, location_name VARCHAR(255),
  lga VARCHAR(100), ward VARCHAR(100), status VARCHAR(20) DEFAULT 'unconfirmed' CHECK (status IN ('unconfirmed','corroborated','confirmed','resolved','false_report')),
  severity VARCHAR(10) DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  is_anonymous BOOLEAN DEFAULT false, media_urls TEXT[] DEFAULT '{}', corroboration_count INT DEFAULT 0,
  confirmed_by UUID REFERENCES users(id), confirmed_at TIMESTAMPTZ, resolved_at TIMESTAMPTZ,
  flag_count INT DEFAULT 0, is_hidden BOOLEAN DEFAULT false, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_incidents_location ON incidents USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents (status) WHERE is_hidden = false;
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON incidents (created_at DESC);

CREATE TABLE IF NOT EXISTS corroborations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), incident_id UUID REFERENCES incidents(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id), location GEOGRAPHY(POINT, 4326), created_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(incident_id, user_id)
);
CREATE TABLE IF NOT EXISTS incident_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), incident_id UUID REFERENCES incidents(id) ON DELETE CASCADE,
  flagged_by UUID REFERENCES users(id), reason VARCHAR(50) CHECK (reason IN ('false_report','duplicate','spam','inappropriate')),
  notes TEXT, created_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(incident_id, flagged_by)
);
