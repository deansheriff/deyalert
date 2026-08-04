# Dey Alert

Dey Alert is a mobile-first, hyper-local security alert app for Nigerian communities. It supports invite-only incident reporting, reviewed security advisories, geographic verification, moderation, notifications, and an SMS-gated SOS workflow.

## Phase 1 included

- Dark Nigerian-night design system: `#101815`, Nigerian green `#008751`, amber corroboration, red danger/SOS.
- Flutter onboarding, map view, nearby feed, report form, incident detail, SOS surface, and profile settings.
- Incident type selection, anonymous reporting, GPS-backed location, real photo/video uploads, corroboration/flag actions, and offline sync.
- FastAPI endpoints for incident create/list/detail, corroboration, and false-report flagging.
- PostGIS migration with spatial index, corroboration and flag tables, and the core user/incident schema.
- Docker Compose for the API and PostGIS.

## Integrated core loop

The app now supports the first real end-to-end slice:

- Supabase email/password authentication with invite-only registration by
  default and a debug-only local demo login.
- State/LGA/ward profile setup with optional phone, alert radius, and privacy
  precision.
- Authenticated FastAPI requests; user identity comes from the verified JWT.
- PostGIS persistence and `ST_DWithin` proximity queries.
- Report submission with GPS and an SQLite offline queue.
- Automatic retry when connectivity returns.
- Live feed data from the API with truthful empty and offline error states.
- Google Maps incident markers when a Maps key is supplied.
- Database-backed corroboration and false-report flagging.
- Reviewed Nigerian security-news advisories, with source attribution, trending
  ranking, and a separate blue marker layer on Google Maps.
- Idempotent offline reports, RLS-protected Realtime reads, audited moderation,
  scoped community verifiers, real media uploads, notification history, and an
  SMS-gated SOS workflow with trusted contacts.

## Run the Flutter app

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
  --dart-define=AUTH_ALLOW_SIGN_UP=false \
  --dart-define=GOOGLE_MAPS_API_KEY=your-maps-key
```

For Android, also set the Gradle property `GOOGLE_MAPS_API_KEY`. For iOS, set
the `GOOGLE_MAPS_API_KEY` build setting. Release builds require Maps and
Supabase Dart defines and will stop at startup if either integration is absent.

Demo auth uses `demo@deyalert.local` with password `password123`. Production
builds default to invite-only sign-in. Set `AUTH_ALLOW_SIGN_UP=true` only after
enabling public email registration and production SMTP in Supabase.

For a local web build:

```bash
flutter build web
```

## Run the backend

The plan uses `uv`:

```bash
cd backend
uv sync
uv run uvicorn app.main:app --reload
uv run pytest
```

Or use Docker Compose from the project root:

```bash
docker compose up --build
```

The API exposes `/health`, interactive docs at `/docs`, and an optional
token-protected Prometheus endpoint at `/metrics`.
`/ready` additionally verifies the database connection and is the production
container health check.

Copy `.env.example` to `.env` and configure Supabase before disabling
`ALLOW_UNAUTHENTICATED_DEV`. The API applies the ordered SQL files in
`backend/migrations` automatically before it starts.

To ingest configured publisher feeds once:

```bash
cd backend
python scripts/ingest_news.py
```

Feeds are configured with `NEWS_FEEDS_JSON`; nothing is scraped by default.
Newly detected advisories enter a review queue unless `NEWS_AUTO_PUBLISH=true`.
Keep that setting off until the classifier and location extraction have been
validated with the selected publishers.

## Deploy with Coolify

The production API image is built from the root `Dockerfile`. Supabase is
deployed as a separate Coolify service and connected to the API over Coolify's
private network. Follow [the Coolify deployment guide](deploy/COOLIFY.md) for
DNS, environment variables, invite-only email auth, migration, and verification
steps.

## Repository

The local git remote is configured for `https://github.com/deansheriff/deyalert.git`.

## Design source

The Phase 1 screen references were generated in Stitch project `561067981101915133`, using the shared Dey Alert design direction and mobile viewport. The generated references cover onboarding, profile setup, map, feed, report, and incident detail. Phone auth and the home shell were implemented against the same design tokens after Stitch returned a transient transport error for those two generation requests.
