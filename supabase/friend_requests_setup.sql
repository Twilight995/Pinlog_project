-- friend_requests table + RLS + accept RPC
-- from_uid/to_uid as UUID to match auth.uid() type directly

CREATE TABLE IF NOT EXISTS public.friend_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_uid UUID NOT NULL,
  to_uid UUID NOT NULL,
  from_nickname TEXT NOT NULL DEFAULT '',
  from_friend_code TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (from_uid, to_uid)
);

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sender_manage" ON public.friend_requests
  FOR ALL
  USING (from_uid = auth.uid())
  WITH CHECK (from_uid = auth.uid());

CREATE POLICY "receiver_read" ON public.friend_requests
  FOR SELECT
  USING (to_uid = auth.uid());

CREATE POLICY "receiver_delete" ON public.friend_requests
  FOR DELETE
  USING (to_uid = auth.uid());

CREATE OR REPLACE FUNCTION public.accept_friend_request(
  p_request_id UUID,
  p_from_uid UUID,
  p_from_nickname TEXT,
  p_from_code TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.friend_requests
    WHERE id = p_request_id AND to_uid = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not found or unauthorized';
  END IF;

  INSERT INTO public.friendships (user_uid, friend_uid, nickname, friend_code)
  VALUES (auth.uid()::text, p_from_uid::text, p_from_nickname, upper(p_from_code))
  ON CONFLICT (user_uid, friend_uid) DO NOTHING;

  DELETE FROM public.friend_requests WHERE id = p_request_id;
END;
$$;
