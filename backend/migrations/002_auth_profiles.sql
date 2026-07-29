ALTER TABLE users
  ADD COLUMN IF NOT EXISTS state VARCHAR(50);

-- Supabase Auth user IDs are written directly into users.id by the API.
-- The phone remains server-derived from the verified JWT, never from the client body.
CREATE INDEX IF NOT EXISTS idx_users_area ON users (state, lga, ward)
  WHERE is_active = true;
