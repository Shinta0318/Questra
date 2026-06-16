-- Trail media storage bucket and owner-scoped object policies.

insert into storage.buckets (id, name, public)
values ('trail-media', 'trail-media', false)
on conflict (id) do nothing;

create policy "Users read their own Trail media objects"
  on storage.objects for select
  using (
    bucket_id = 'trail-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users upload their own Trail media objects"
  on storage.objects for insert
  with check (
    bucket_id = 'trail-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users update their own Trail media objects"
  on storage.objects for update
  using (
    bucket_id = 'trail-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'trail-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users delete their own Trail media objects"
  on storage.objects for delete
  using (
    bucket_id = 'trail-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
