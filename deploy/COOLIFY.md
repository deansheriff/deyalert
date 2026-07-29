# Deploy Dey Alert and self-hosted Supabase on Coolify

The root `Dockerfile` deploys the FastAPI service. Supabase must be deployed as
its own Coolify service because Supabase is a multi-container platform (Postgres,
Auth, Storage, Realtime, Studio, Kong, and supporting services).

## 1. Prepare DNS and the server

Create DNS records pointing to the Coolify server:

- `api.example.com` for the Dey Alert API
- `supabase.example.com` for the Supabase API
- `studio.example.com` for Supabase Studio

For a production installation, budget at least 4 CPU cores, 8 GB RAM, and enough
SSD storage for the database, media, logs, and backups. Supabase can start on
less, but the complete stack has many containers.

## 2. Create Supabase in Coolify

1. Open the same Coolify project, environment, and destination that will contain
   the Dey Alert API.
2. Choose **New Resource > Service > Supabase**.
3. Assign `https://supabase.example.com` to the Kong/API service and
   `https://studio.example.com` to Studio.
4. Deploy the service and wait until all required containers are healthy.
5. In the service environment, record these generated values:
   - `SERVICE_PASSWORD_POSTGRES`
   - `SERVICE_PASSWORD_JWT`
   - `SUPABASE_PUBLISHABLE_KEY`, when populated, otherwise
     `SERVICE_SUPABASEANON_KEY`
6. Enable **Connect to Predefined Network** for the Supabase service and the Dey
   Alert application. This lets the API reach `supabase-db` without exposing
   PostgreSQL port 5432 to the internet.

Do not put the service-role/secret key in the Flutter app. Only the publishable
key (or legacy anon key) is safe to compile into the client.

## 3. Configure invite-only email authentication

Add these variables to the Coolify Supabase service and redeploy it:

```dotenv
DISABLE_SIGNUP=true
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=true
ENABLE_PHONE_SIGNUP=false
```

This allows email/password login but blocks users from creating their own
accounts. Create pilot members from **Supabase Studio > Authentication > Users**
and give each member a strong temporary password through a secure channel.

The Flutter app independently hides account creation unless it is compiled with
`AUTH_ALLOW_SIGN_UP=true`. Keep that setting false for invite-only builds.

When public registration is enabled later:

1. Configure production SMTP in the Supabase service.
2. Set `DISABLE_SIGNUP=false`.
3. Set `ENABLE_EMAIL_AUTOCONFIRM=false` so users must confirm their addresses.
4. Build the app with `--dart-define=AUTH_ALLOW_SIGN_UP=true`.

Phone is now optional, unverified profile data. When paid SMS verification is
introduced, the database already includes `phone_verified`. A later phase will
add the verification UI and connect a supported SMS provider before
`ENABLE_PHONE_SIGNUP` is turned on.

## 4. Deploy the API from the repository

1. Choose **New Resource > Public Repository** (or Private Repository) and select
   the Dey Alert repository and deployment branch.
2. Select the **Dockerfile** build pack.
3. Set:
   - Base directory: `/`
   - Dockerfile location: `/Dockerfile`
   - Port: `8000`
   - Health-check path: `/health`
4. Assign `https://api.example.com`.
5. Enable **Connect to Predefined Network**.
6. Add the following application environment variables:

```dotenv
ENVIRONMENT=production
PORT=8000
DATABASE_URL=postgresql+psycopg://postgres:URL_ENCODED_POSTGRES_PASSWORD@supabase-db:5432/postgres
SUPABASE_URL=https://supabase.example.com
SUPABASE_JWKS_URL=https://supabase.example.com/auth/v1/.well-known/jwks.json
SUPABASE_JWT_SECRET=the-value-of-SERVICE_PASSWORD_JWT
ALLOW_UNAUTHENTICATED_DEV=false
USE_IN_MEMORY_STORE=false
CORS_ORIGINS=https://app.example.com
```

Important:

- URL-encode the PostgreSQL password before placing it in `DATABASE_URL`.
- `supabase-db` is the database service name in Coolify's Supabase template. If
  you renamed it, use the new service name.
- Keep `SUPABASE_JWT_SECRET` while the installation issues legacy HS256 tokens.
  The API also supports the newer ES256/RS256 keys through the JWKS URL.
- For a mobile-only client, `CORS_ORIGINS` may be blank. Add comma-separated
  HTTPS origins when deploying Flutter Web.

Deploy the application. On every container start it waits for PostgreSQL and
applies any unapplied SQL files in `backend/migrations` before starting Uvicorn.

## 5. Build the Flutter app for production

The values passed with `--dart-define` are compiled into the app:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=SUPABASE_URL=https://supabase.example.com \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-or-anon-key \
  --dart-define=AUTH_ALLOW_SIGN_UP=false \
  --dart-define=GOOGLE_MAPS_API_KEY=your-restricted-maps-key
```

Use the same defines with `flutter build appbundle`, `flutter build ipa`, or
`flutter build web`. Restrict the Google Maps key by app/package and API in the
Google Cloud console.

## 6. Verify the deployment

```bash
curl https://api.example.com/health
curl https://supabase.example.com/auth/v1/health
```

The API response should contain `"status":"ok"`. Then sign in with an
administrator-created pilot account, complete profile setup, submit a test
report, and confirm the incident appears in Supabase Studio.

## 7. Production operations

- Configure off-server PostgreSQL backups and test a restore.
- Back up Supabase Storage volumes if incident media is stored locally.
- Keep Coolify, Supabase images, and the server OS patched.
- Monitor disk space, Postgres health, API health, and SMS delivery errors.
- Never expose Studio without a strong password and HTTPS.
- Never expose PostgreSQL publicly unless there is no private-network option.
