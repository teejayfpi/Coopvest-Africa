-- 029: Enable Supabase Realtime for notifications
--
-- The Flutter app subscribes to postgres_changes on the notifications table
-- (see realtime_notification_service.dart) so members see in-app/push
-- notifications appear instantly. For INSERT payloads to carry the full new
-- row (title/body/type/profile_id,…), we also need REPLICA IDENTITY FULL.


-- Make sure the table is published for realtime.（Safe to re-run: checks
-- whether it's already in the publication before adding..
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- Deliver full change payloads on INSERT so the app can render the row without
-- an extra fetch..
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- device_tokens isn't needed for realtime channels, but FULL identity keeps
-- FCM token-upsert change payloads consistent if ever subscribed..
ALTER TABLE public.device_tokens REPLICA IDENTITY FULL;