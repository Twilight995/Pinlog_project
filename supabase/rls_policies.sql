-- ============================================================
-- Pinlog — RLS 정책 전체 설정
-- Supabase Dashboard → SQL Editor 에서 실행하세요
-- ============================================================


-- ──────────────────────────────────────────────────────────
-- 1. users 테이블
-- ──────────────────────────────────────────────────────────
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 인증된 사람은 누구나 읽기 가능 (친구 코드 검색용)
CREATE POLICY "users: authenticated read"
  ON users FOR SELECT
  USING (auth.role() = 'authenticated');

-- 자기 row만 삽입/수정/삭제
CREATE POLICY "users: own row insert"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = uid);

CREATE POLICY "users: own row update"
  ON users FOR UPDATE
  USING (auth.uid() = uid)
  WITH CHECK (auth.uid() = uid);

CREATE POLICY "users: own row delete"
  ON users FOR DELETE
  USING (auth.uid() = uid);


-- ──────────────────────────────────────────────────────────
-- 2. pins 테이블
-- ──────────────────────────────────────────────────────────
ALTER TABLE pins ENABLE ROW LEVEL SECURITY;

-- 내 핀: 모든 권한
CREATE POLICY "pins: owner full access"
  ON pins FOR ALL
  USING (auth.uid() = uid)
  WITH CHECK (auth.uid() = uid);

-- 전체 공개 핀: 누구나 읽기
CREATE POLICY "pins: public read"
  ON pins FOR SELECT
  USING (visibility = '🌐 전체 공개');

-- 친구 공개 핀: 친구만 읽기
CREATE POLICY "pins: friends read"
  ON pins FOR SELECT
  USING (
    visibility = '👥 친구 공개'
    AND EXISTS (
      SELECT 1 FROM friendships
      WHERE friendships.user_uid = auth.uid()
        AND friendships.friend_uid = pins.uid
    )
  );


-- ──────────────────────────────────────────────────────────
-- 3. friendships 테이블
--    + 트리거: 한쪽이 친구 추가하면 반대쪽 row 자동 생성
-- ──────────────────────────────────────────────────────────
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- 내 친구 목록만 읽기
CREATE POLICY "friendships: own read"
  ON friendships FOR SELECT
  USING (auth.uid() = user_uid);

-- 내 쪽 row만 삽입 (반대 row는 트리거가 생성)
CREATE POLICY "friendships: own insert"
  ON friendships FOR INSERT
  WITH CHECK (auth.uid() = user_uid);

-- 내 쪽 row만 삭제
CREATE POLICY "friendships: own delete"
  ON friendships FOR DELETE
  USING (auth.uid() = user_uid);

-- 양방향 자동 생성 트리거 (SECURITY DEFINER: RLS 우회)
CREATE OR REPLACE FUNCTION create_reverse_friendship()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  sender_nickname TEXT;
BEGIN
  SELECT nickname INTO sender_nickname FROM users WHERE uid = NEW.user_uid;

  INSERT INTO friendships (user_uid, friend_uid, friend_code, nickname)
  VALUES (
    NEW.friend_uid,
    NEW.user_uid,
    NULL,
    COALESCE(sender_nickname, 'Pinlog 탐험가')
  )
  ON CONFLICT (user_uid, friend_uid) DO NOTHING;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_reverse_friendship
  AFTER INSERT ON friendships
  FOR EACH ROW
  EXECUTE FUNCTION create_reverse_friendship();


-- ──────────────────────────────────────────────────────────
-- 4. scheduled_meetings 테이블
-- ──────────────────────────────────────────────────────────
ALTER TABLE scheduled_meetings ENABLE ROW LEVEL SECURITY;

-- 약속 참여자 (주최자 또는 초대받은 사람) 읽기
CREATE POLICY "meetings: participant read"
  ON scheduled_meetings FOR SELECT
  USING (auth.uid() = meet_uid OR auth.uid() = invitee_uid);

-- 주최자만 생성
CREATE POLICY "meetings: creator insert"
  ON scheduled_meetings FOR INSERT
  WITH CHECK (auth.uid() = meet_uid);

-- 참여자 모두 상태 변경 가능
CREATE POLICY "meetings: participant update"
  ON scheduled_meetings FOR UPDATE
  USING (auth.uid() = meet_uid OR auth.uid() = invitee_uid)
  WITH CHECK (auth.uid() = meet_uid OR auth.uid() = invitee_uid);

-- 참여자 모두 삭제 가능
CREATE POLICY "meetings: participant delete"
  ON scheduled_meetings FOR DELETE
  USING (auth.uid() = meet_uid OR auth.uid() = invitee_uid);
