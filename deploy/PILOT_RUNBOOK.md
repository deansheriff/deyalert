# Invite-only pilot runbook

## Scope

- One staging environment and one production environment.
- 20-50 invited members in Ikeja LGA only.
- At least two vetted verifiers per participating ward.
- One named moderator on duty whenever incident reporting is enabled.
- Public signup remains disabled.

## Launch gates

- CI is green on the exact deployment commit.
- Staging migration, incident creation, media upload, Realtime update,
  corroboration, verifier confirmation, moderation and news review all pass.
- SMS provider test messages succeed for every trusted-contact network used in
  the pilot. If not, keep SOS unavailable in the app.
- Google Maps keys are restricted to the production Android/iOS identifiers.
- PostgreSQL and Storage backups complete off-server and both restores are
  verified using the scripts in `deploy/scripts`.
- Privacy notice, terms, community rules, support contact and escalation
  procedure are published and accepted by pilot members.

## Pilot procedure

1. Create accounts in Supabase Studio; do not distribute shared accounts.
2. Have each member complete their profile and confirm their ward/radius.
3. Run scripted drills for offline reporting, duplicate retry, false flagging,
   verifier scope, high-severity notification and SOS cancellation/delivery.
4. Review audit logs and moderation queues daily.
5. Record false positives, delivery latency, crashes and user-reported confusion.
6. Stop the pilot immediately if sample data appears, SOS reports success
   without delivery, unauthorized users can moderate, or backups cannot restore.

## Public onboarding gate

Do not enable public signup until rate limits and abuse workflows have been
load-tested, production SMTP is configured, SMS verification is implemented,
and the pilot has completed without an unresolved severity-one safety defect.
