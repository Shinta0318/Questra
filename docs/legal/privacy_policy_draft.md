# Questra Privacy Policy Draft

**Document version:** `2026-08-18-beta.1`
**Release status:** Draft / human legal approval required

## Draft Status

This is a product draft for internal beta planning. It requires human legal
review before any public release or external distribution.

## Data We Store

Questra may collect and store:

- Account profile data such as nickname, email, onboarding state, and profile
  settings.
- Quest, Mission, Trail, Reflection, and Guild content created by the user.
- Arc Memory records generated from the user's Questra activity.
- Private Trail media and related media metadata.
- Subscription, business account, notification, report, and block records when
  those features are enabled.
- Basic analytics events and generation logs needed to operate and improve the
  service.

## Data Processed For Arc Generation

When remote generation is configured, Arc Chat may process the user's message,
recent conversation history, active Quest, recent Missions and Trails, and a
limited set of relevant Arc Memory records. Quest Guide may process the target
Quest title, description, category, difficulty, and target date.

The Flutter app sends this context to Supabase Edge Functions. The MVP/Beta
default provider is the Gemini API. The OpenAI compatibility path is used only
when the operator explicitly selects it. Gemini Interactions requests set
`store=false`; if remote generation is unavailable, Questra uses a local
fallback response. Arc Chat text is not currently stored as a standalone chat
history table, although derived Arc Memory may be stored.

## How We Use Data

Questra uses user data to:

- Provide the Quest, Mission, Trail, Guild, Profile, and Arc experiences.
- Preserve journey context and Arc Memory for the signed-in user.
- Sync private user data across devices.
- Maintain safety, abuse prevention, and support workflows.
- Improve product reliability and beta readiness.

## Arc Memory

Arc Memory stores journey context from the user's Questra activity. Arc Memory
records are intended to be private to the account owner unless explicit sharing
controls are introduced in a future release.

## Media

Trail media is stored in a private Supabase Storage bucket and linked to private
media metadata rows. Users can remove or replace attached Trail images.

## Guild Activity

Guild features may involve shared activity. Private Quest, Trail, media, and Arc
Memory data should not become Guild-visible unless a future sharing workflow
explicitly asks the user to share it.

## Data Retention and Deletion

Crash/error evidence is retained for 30 days under the current Beta operations
plan. Before public release, Questra must document:

- How users request account deletion.
- How users request deletion of Quest, Mission, Trail, Arc Memory, and media
  data.
- How long backups and operational logs are retained.

## Third-Party Services

Questra uses Supabase for authentication, database, storage, and Edge Function
infrastructure. The Beta Supabase project uses the Tokyo region. When configured,
Questra uses the Gemini API for Arc Chat and Quest Guide generation. An OpenAI
compatibility path remains available only through explicit server configuration.
Gemini billing tier, project logging settings, provider retention, and processor
terms must be confirmed before external beta distribution.

The in-app beta feedback form currently copies a report to the clipboard and
does not automatically submit it. External crash reporting is currently
disabled. Additional analytics, crash reporting, AI, or payment providers must
be added to this policy before they are enabled.

## Contact

Add a support and privacy contact address before public release.

## Release Review Notes

- Confirm target release regions and legal requirements.
- Add data processor list.
- Add user rights language for applicable jurisdictions.
- Add children's privacy language if required.
- Add final retention periods.
- Confirm Gemini paid-service status, logging settings, and provider retention.
- Confirm any explicitly enabled OpenAI compatibility project data controls.
