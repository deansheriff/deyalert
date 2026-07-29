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

## 3. Configure phone OTP

Phone signup can be enabled while SMS delivery is still unconfigured. For
production OTP delivery, edit the Supabase service Compose configuration and
pass the matching variables into the `supabase-auth` service. A Twilio example:

```yaml
environment:
  GOTRUE_EXTERNAL_PHONE_ENABLED: "true"
  GOTRUE_SMS_PROVIDER: twilio
  GOTRUE_SMS_OTP_EXP: "300"
  GOTRUE_SMS_OTP_LENGTH: "6"
  GOTRUE_SMS_MAX_FREQUENCY: 60s
  GOTRUE_SMS_TEMPLATE: "Your Dey Alert code is {{ .Code }}"
  GOTRUE_SMS_TWILIO_ACCOUNT_SID: ${SMS_TWILIO_ACCOUNT_SID}
  GOTRUE_SMS_TWILIO_AUTH_TOKEN: ${SMS_TWILIO_AUTH_TOKEN}
  GOTRUE_SMS_TWILIO_MESSAGE_SERVICE_SID: ${SMS_TWILIO_MESSAGE_SERVICE_SID}
```

Store the three `SMS_TWILIO_*` values as Coolify service environment variables,
then redeploy Supabase. Supabase Auth also supports MessageBird, Vonage, and
TextLocal, but their provider-specific variables differ. Use E.164 phone numbers
such as `+2348012345678`.

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

The API response should contain `"status":"ok"`. Then request an OTP from the
app, complete profile setup, submit a test report, and confirm the incident
appears in Supabase Studio.

## 7. Production operations

- Configure off-server PostgreSQL backups and test a restore.
- Back up Supabase Storage volumes if incident media is stored locally.
- Keep Coolify, Supabase images, and the server OS patched.
- Monitor disk space, Postgres health, API health, and SMS delivery errors.
- Never expose Studio without a strong password and HTTPS.
- Never expose PostgreSQL publicly unless there is no private-network option.
