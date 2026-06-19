# Questra Privacy Policy Draft

## Draft Status

This is a product draft for internal beta planning. It requires human legal
review before any public release or external distribution.

## Data We Collect

Questra may collect and store:

- Account profile data such as nickname, email, onboarding state, and profile
  settings.
- Quest, Mission, Trail, Reflection, Guild, and Arc Chat content created by the
  user.
- Arc Memory records generated from the user's Questra activity.
- Private Trail media and related media metadata.
- Subscription, business account, notification, report, and block records when
  those features are enabled.
- Basic analytics events and generation logs needed to operate and improve the
  service.

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

Before public release, Questra must document:

- How users request account deletion.
- How users request deletion of Quest, Mission, Trail, Arc Memory, and media
  data.
- How long backups and operational logs are retained.

## Third-Party Services

Questra currently uses Supabase for authentication, database, storage, and Edge
Function infrastructure. Additional analytics, crash reporting, or payment
providers must be added to this policy before public release.

## Contact

Add a support and privacy contact address before public release.

## Release Review Notes

- Confirm target release regions and legal requirements.
- Add data processor list.
- Add user rights language for applicable jurisdictions.
- Add children's privacy language if required.
- Add final retention periods.
