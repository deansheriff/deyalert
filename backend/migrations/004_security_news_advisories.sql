CREATE TABLE IF NOT EXISTS news_articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name VARCHAR(150) NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  url TEXT UNIQUE NOT NULL,
  image_url TEXT,
  author VARCHAR(255),
  published_at TIMESTAMPTZ NOT NULL,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  content_hash VARCHAR(64) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_news_articles_published
  ON news_articles (published_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_articles_content_hash
  ON news_articles (content_hash);

CREATE TABLE IF NOT EXISTS security_advisories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  summary TEXT,
  type VARCHAR(30) NOT NULL CHECK (
    type IN (
      'kidnapping', 'armed_robbery', 'roadblock', 'cult_clash',
      'banditry', 'fire_outbreak', 'suspicious_activity', 'other'
    )
  ),
  severity VARCHAR(10) NOT NULL DEFAULT 'medium' CHECK (
    severity IN ('low', 'medium', 'high', 'critical')
  ),
  location GEOGRAPHY(POINT, 4326),
  location_name VARCHAR(255),
  location_confidence VARCHAR(20) NOT NULL DEFAULT 'unknown' CHECK (
    location_confidence IN ('exact', 'city', 'state', 'unknown')
  ),
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'published', 'rejected', 'expired', 'retracted')
  ),
  source_count INT NOT NULL DEFAULT 1,
  article_count INT NOT NULL DEFAULT 1,
  first_published_at TIMESTAMPTZ NOT NULL,
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_advisories_location
  ON security_advisories USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_security_advisories_status_time
  ON security_advisories (status, last_updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_advisories_type_time
  ON security_advisories (type, first_published_at DESC);

CREATE TABLE IF NOT EXISTS advisory_sources (
  advisory_id UUID NOT NULL REFERENCES security_advisories(id) ON DELETE CASCADE,
  article_id UUID NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
  PRIMARY KEY (advisory_id, article_id)
);

CREATE TABLE IF NOT EXISTS advisory_incident_links (
  advisory_id UUID NOT NULL REFERENCES security_advisories(id) ON DELETE CASCADE,
  incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'suggested' CHECK (
    status IN ('suggested', 'approved', 'rejected')
  ),
  confidence DECIMAL(4,3) NOT NULL DEFAULT 0,
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (advisory_id, incident_id)
);
