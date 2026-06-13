# Supabase

This directory contains the Supabase project files for Questra.

## Structure

- `migrations`: SQL migrations for the MVP database schema.
- `functions`: Supabase Edge Functions.
- `seed`: Seed data and scripts.

## Flutter Configuration

Pass Supabase values to the Flutter app with Dart defines:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key
```

The mobile app skips Supabase initialization when either value is omitted, which
keeps local tests and UI-only development fast.
