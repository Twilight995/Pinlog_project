import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface FcmPayload {
  target_uid: string
  title: string
  body: string
  data?: Record<string, string>
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Missing auth header' }, 401)

  // 호출자 인증
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  )
  const { data: { user }, error: authError } = await userClient.auth.getUser()
  if (authError || !user) return json({ error: 'Unauthorized' }, 401)

  const payload: FcmPayload = await req.json()
  if (!payload.target_uid || !payload.title) {
    return json({ error: 'target_uid and title required' }, 400)
  }

  // 대상 유저의 FCM 토큰 조회
  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { autoRefreshToken: false, persistSession: false } },
  )
  const { data: targetUser } = await adminClient
    .from('users')
    .select('fcm_token')
    .eq('uid', payload.target_uid)
    .maybeSingle()

  const fcmToken = targetUser?.fcm_token as string | undefined
  if (!fcmToken) return json({ error: 'FCM token not found' }, 404)

  // Firebase FCM HTTP v1 API 호출
  // FIREBASE_PROJECT_ID, FIREBASE_SERVICE_ACCOUNT_JSON 환경변수 필요
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID')
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
  if (!projectId || !serviceAccountJson) {
    return json({ error: 'Firebase config missing' }, 500)
  }

  const accessToken = await getAccessToken(JSON.parse(serviceAccountJson))
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

  const fcmRes = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title: payload.title, body: payload.body },
        data: payload.data ?? {},
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      },
    }),
  })

  if (!fcmRes.ok) {
    const err = await fcmRes.text()
    return json({ error: err }, 500)
  }

  return json({ success: true }, 200)
})

// Google OAuth2 service account → access token
async function getAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claimSet = btoa(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))

  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(`${header}.${claimSet}`),
  )
  const jwt = `${header}.${claimSet}.${btoa(String.fromCharCode(...new Uint8Array(sig)))}`

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  })
  const { access_token } = await tokenRes.json()
  return access_token
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}

function json(body: object, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
