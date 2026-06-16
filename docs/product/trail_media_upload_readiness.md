# Trail Media Upload Readiness

## Purpose

Trail media lets a user attach a concrete proof image to a Trail while keeping
the MVP private-first and aligned with Supabase RLS policies.

## Storage Boundary

- Bucket: `trail-media`
- Public access: disabled
- Object path: `{ownerId}/{trailId}/{timestamp}_{fileName}`
- Storage policies: owner-scoped by the first path segment matching
  `auth.uid()`.

## Data Boundary

The `media` table stores attachment metadata:

- `owner_id`
- `bucket`
- `path`
- `media_type`
- `related_table = trails`
- `related_id = trail.id`
- `visibility = private`
- `metadata.content_type`
- `metadata.size_bytes`

## MVP UI Path

1. User opens Trail.
2. User opens a Trail card action menu.
3. User chooses `Attach image`.
4. App opens the platform gallery picker.
5. App uploads the image to `trail-media`.
6. App creates a private `media` row linked to the Trail.
7. Trail sync banner reports upload success or failure.

## Release Notes

- Private upload is implemented first.
- Public and Guild media visibility must stay blocked until share review UX is
  added.
- Deleting a Trail media object and media row together should be added before
  broader media management.
