import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'npm:jose@5';

const cors = { 'Access-Control-Allow-Origin': '*' };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

function bearerToken(auth: string): string {
  return auth.toLowerCase().startsWith('bearer ')
    ? auth.slice(7).trim()
    : auth.trim();
}

function jwtRole(token: string): string {
  try {
    const payload = token.split('.')[1];
    if (!payload) {
      return '';
    }
    const padded = payload.replace(/-/g, '+').replace(/_/g, '/');
    const json = JSON.parse(
      atob(padded + '='.repeat((4 - (padded.length % 4)) % 4)),
    ) as { role?: string };
    return String(json.role ?? '');
  } catch {
    return '';
  }
}

function normalizeP8(p8: string): string {
  let value = p8.trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1).trim();
  }
  value = value.replace(/\\n/g, '\n').replace(/\r\n/g, '\n').trim();
  if (value.includes('BEGIN PRIVATE KEY')) {
    return value;
  }
  return `-----BEGIN PRIVATE KEY-----\n${value}\n-----END PRIVATE KEY-----`;
}

async function apnsJwt(p8: string, keyId: string, teamId: string): Promise<string> {
  const pem = normalizeP8(p8);
  const key = await importPKCS8(pem, 'ES256');
  return await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(key);
}

type ApnsResult = {
  ok: boolean;
  status: number;
  reason: string;
};

async function postApns(
  host: string,
  deviceToken: string,
  jwt: string,
  bundleId: string,
  payload: string,
): Promise<ApnsResult> {
  const base = host.replace(/\/$/, '');
  const url = `${base}/3/device/${deviceToken}`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        authorization: `bearer ${jwt}`,
        'apns-topic': bundleId,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': '0',
        'content-type': 'application/json',
      },
      body: payload,
    });
    const text = await res.text();
    let reason = res.headers.get('apns-reason') ?? '';
    if (!reason && text) {
      try {
        reason = (JSON.parse(text) as { reason?: string }).reason ?? text.slice(0, 80);
      } catch {
        reason = text.slice(0, 80);
      }
    }
    return {
      ok: res.ok,
      status: res.status,
      reason: reason || `http_${res.status}`,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'fetch_failed';
    return { ok: false, status: 0, reason: `fetch_${message}`.slice(0, 140) };
  }
}

serve(async (req) => {
  try {
    return await handleNotify(req);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'crash';
    return json({ error: `notify_${message}`.slice(0, 140) }, 500);
  }
});

async function handleNotify(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey = (Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '').trim();
  const auth = req.headers.get('Authorization') ?? '';
  const token = bearerToken(auth);
  const isService =
    (serviceKey.length > 0 && token === serviceKey) ||
    jwtRole(token) === 'service_role';
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userData } = isService
    ? { data: { user: null } }
    : await userClient.auth.getUser();
  const body = (await req.json().catch(() => ({}))) as {
    title?: string;
    body?: string;
    owner_user_id?: string;
    title_id?: string;
    platform_name?: string;
    claimed?: boolean;
    skipClaim?: boolean;
    alerts?: { titleName?: string; platformName?: string; titleId?: string }[];
  };
  const ownerUserId = isService
    ? (body.owner_user_id ?? '').toString()
    : (userData.user?.id ?? '');
  if (!ownerUserId) {
    return json({ error: 'unauthorized' }, 401);
  }
  const admin: SupabaseClient = serviceKey
    ? createClient(supabaseUrl, serviceKey)
    : userClient;
  const title = (body.title ?? 'Release Status').toString();
  const alertBody = (body.body ?? 'A title is live.').toString();
  const alertRows = (body.alerts ?? []).map((row) => ({
    titleId: (row.titleId ?? body.title_id ?? '').toString(),
    platformName: (row.platformName ?? body.platform_name ?? '').toString(),
  }));
  if (alertRows.length === 0 && (body.title_id || body.platform_name)) {
    alertRows.push({
      titleId: (body.title_id ?? '').toString(),
      platformName: (body.platform_name ?? '').toString(),
    });
  }

  if (!body.claimed && !body.skipClaim) {
    let claimedAny = alertRows.length === 0;
    for (const row of alertRows) {
      if (!row.titleId || !row.platformName) {
        claimedAny = true;
        break;
      }
      const { data: claimed, error: claimError } = await admin.rpc(
        'release_status_claim_live_alert',
        {
          p_owner: ownerUserId,
          p_title_id: row.titleId,
          p_platform: row.platformName,
        },
      );
      if (claimError) {
        claimedAny = true;
        break;
      }
      if (claimed === true) {
        claimedAny = true;
      }
    }
    if (!claimedAny) {
      return json({ sent: 0, tokenCount: 0, reason: 'already_sent' });
    }
  }

  const { data: tokens, error } = await admin
    .from('release_status_push_tokens')
    .select('device_token, platform')
    .eq('owner_user_id', ownerUserId)
    .eq('platform', 'ios');
  if (error) {
    return json({ error: error.message }, 400);
  }
  const iosTokens = (tokens ?? [])
    .map((row) => (row.device_token as string | null)?.trim() ?? '')
    .filter((tokenValue) => tokenValue.length > 0);
  const p8 =
    Deno.env.get('RELEASE_STATUS_APNS_P8') ?? Deno.env.get('APNS_P8') ?? '';
  const keyId =
    Deno.env.get('RELEASE_STATUS_APNS_KEY_ID') ??
    Deno.env.get('APNS_KEY_ID') ??
    '';
  const teamId =
    Deno.env.get('RELEASE_STATUS_APNS_TEAM_ID') ??
    Deno.env.get('APNS_TEAM_ID') ??
    'DYF32BTXXJ';
  const bundleId =
    Deno.env.get('RELEASE_STATUS_APNS_BUNDLE_ID') ??
    'com.orbium.releaseStatus';
  if (!p8 || !keyId) {
    return json({
      sent: 0,
      tokenCount: iosTokens.length,
      reason: 'apns_not_configured',
    });
  }
  if (iosTokens.length === 0) {
    return json({ sent: 0, tokenCount: 0, reason: 'no_ios_tokens' });
  }
  let jwt = '';
  try {
    jwt = await apnsJwt(p8, keyId, teamId);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'sign_failed';
    return json({
      sent: 0,
      tokenCount: iosTokens.length,
      reason: `apns_key_invalid`.slice(0, 40),
      detail: message.slice(0, 80),
    });
  }
  const host = Deno.env.get('APNS_HOST') ?? 'https://api.push.apple.com:443';
  const payload = JSON.stringify({
    aps: {
      alert: { title, body: alertBody },
      sound: 'default',
    },
  });
  let sent = 0;
  const reasons: string[] = [];
  for (const deviceToken of iosTokens) {
    const result = await postApns(host, deviceToken, jwt, bundleId, payload);
    if (result.ok) {
      sent += 1;
      continue;
    }
    reasons.push(result.reason);
    if (
      result.reason === 'Unregistered' ||
      result.reason === 'ExpiredToken'
    ) {
      await admin
        .from('release_status_push_tokens')
        .delete()
        .eq('owner_user_id', ownerUserId)
        .eq('device_token', deviceToken);
    }
  }
  return json({
    sent,
    tokenCount: iosTokens.length,
    reason: sent > 0 ? null : reasons[0] ?? 'apns_failed',
  });
}
