# Dey Alert

Dey Alert is a mobile-first, hyper-local security alert app for Nigerian communities. Phase 1 implements the core loop: report an incident, see nearby alerts on a map/feed, and inspect the verification trail.

## Phase 1 included

- Dark Nigerian-night design system: `#101815`, Nigerian green `#008751`, amber corroboration, red danger/SOS.
- Flutter onboarding, map view, nearby feed, report form, incident detail, SOS surface, and profile settings.
- Incident type selection, anonymous reporting, approximate location copy, media attachment affordances, corroboration/flag actions, and offline-sync messaging.
- FastAPI endpoints for incident create/list/detail, corroboration, and false-report flagging.
- PostGIS migration with spatial index, corroboration and flag tables, and the core user/incident schema.
- Docker Compose for the API and PostGIS.

## Integrated core loop

The app now supports the first real end-to-end slice:

- Supabase phone OTP with a credential-free demo mode (`123456`).
- State/LGA/ward profile setup with alert radius and privacy precision.
- Authenticated FastAPI requests; user identity comes from the verified JWT.
- PostGIS persistence and `ST_DWithin` proximity queries.
- Report submission with GPS and an SQLite offline queue.
- Automatic retry when connectivity returns.
- Live feed data from the API with fixture fallback while the API is unavailable.
- Google Maps incident markers when a Maps key is supplied.
- Database-backed corroboration and false-report flagging.

## Run the Flutter app

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-publishable-key \
  --dart-define=GOOGLE_MAPS_API_KEY=your-maps-key
```

For Android, also set the Gradle property `GOOGLE_MAPS_API_KEY`. For iOS, set
the `GOOGLE_MAPS_API_KEY` build setting. Without these values the app uses its
safe demo auth and stylized map fallback.

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

The API exposes `/health` and interactive docs at `/docs`.

Copy `.env.example` to `.env` and set `SUPABASE_JWT_SECRET` before disabling
`ALLOW_UNAUTHENTICATED_DEV`. Docker Compose mounts the ordered SQL files in
`backend/migrations` into PostGIS for first-run initialization.

## Repository

The local git remote is configured for `https://github.com/deansheriff/deyalert.git`.

## Design source

The Phase 1 screen references were generated in Stitch project `561067981101915133`, using the shared Dey Alert design direction and mobile viewport. The generated references cover onboarding, profile setup, map, feed, report, and incident detail. Phone auth and the home shell were implemented against the same design tokens after Stitch returned a transient transport error for those two generation requests.
