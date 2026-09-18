import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*' };
const LIVE_SOURCE = 'TMDb Watch Providers';
const NETWORK_SOURCE = 'TMDb Network';
const USER_CONFIRMED = 'Confirmed by you';
const LISTING_URL = 'Listing URL';
const REMOVAL_AFTER = 3;
const ALIASES: Record<string, string[]> = {
  amazon: [
    'amazon',
    'amazon prime',
    'amazon prime video',
    'amazon video',
    'prime video',
    'prime',
    'amazon prime video with ads',
  ],
  plex: ['plex', 'plex tv', 'plex channel', 'plex free'],
  fawesome: [
    'fawesome',
    'future today',
    'future today fawesome',
    'future today (fawesome)',
  ],
  ofive_plus: ['ofive+', 'ofive plus', 'ofive', 'ofiveplus'],
  relay: ['relay', 'relay.film', 'relay film'],
  netflix: ['netflix', 'netflix standard with ads', 'netflix basic with ads'],
};
const SHARED_CATALOG_HOSTS = ['justwatch.com', 'themoviedb.org'];
const HOST_IDS: Record<string, string> = {
  'amazon.com': 'amazon',
  'primevideo.com': 'amazon',
  'plex.tv': 'plex',
  'watch.plex.tv': 'plex',
  'netflix.com': 'netflix',
  'relay.film': 'relay',
};

type Listing = {
  name: string;
  live: boolean;
  url?: string;
  providerId?: string;
  detail: string;
  source: string;
};

type PlatformRow = {
  id?: string;
  owner_user_id: string;
  title_id: string;
  platform_name: string;
  status: string;
  origin: string;
  license_relationship: string;
  first_detected_at: string | null;
  last_checked_at: string | null;
  removed_at: string | null;
  status_message: string | null;
  status_detail: string | null;
  evidence_source: string | null;
  evidence_url: string | null;
  last_monitoring_source: string | null;
  last_match_confidence: string | null;
  last_check_failed: boolean;
  consecutive_verified_absences: number;
  source_provider_id: string | null;
  history: unknown;
};

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
    const parsed = JSON.parse(
      atob(padded + '='.repeat((4 - (padded.length % 4)) % 4)),
    ) as { role?: string };
    return String(parsed.role ?? '');
  } catch {
    return '';
  }
}

function normalizeName(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[()]/g, ' ')
    .replace(/\s+/g, ' ');
}

function canonicalId(name: string): string | null {
  const normalized = normalizeName(name);
  for (const [id, aliases] of Object.entries(ALIASES)) {
    if (aliases.some((alias) => normalizeName(alias) === normalized)) {
      return id;
    }
  }
  return null;
}

function sameService(left: string, right: string): boolean {
  const leftId = canonicalId(left);
  const rightId = canonicalId(right);
  if (leftId && rightId) {
    return leftId === rightId;
  }
  return normalizeName(left) === normalizeName(right);
}

function parseUrl(value?: string | null): URL | null {
  const trimmed = (value ?? '').trim();
  if (!trimmed) {
    return null;
  }
  try {
    return new URL(trimmed);
  } catch {
    return null;
  }
}

function bareHost(host: string): string {
  const lower = host.trim().toLowerCase();
  return lower.startsWith('www.') ? lower.slice(4) : lower;
}

function isSharedCatalogHost(host: string): boolean {
  return SHARED_CATALOG_HOSTS.some(
    (catalog) => host === catalog || host.endsWith(`.${catalog}`),
  );
}

function canonicalIdFromUrl(url?: string | null): string | null {
  const parsed = parseUrl(url);
  if (!parsed) {
    return null;
  }
  const host = bareHost(parsed.hostname);
  if (isSharedCatalogHost(host)) {
    return null;
  }
  return HOST_IDS[host] ?? null;
}

function specificListingUrl(url?: string | null): string | null {
  const parsed = parseUrl(url);
  if (!parsed || isSharedCatalogHost(bareHost(parsed.hostname))) {
    return null;
  }
  return `${parsed.protocol}//${parsed.host}${parsed.pathname}`.replace(/\/+$/, '');
}

function preferSpecificUrl(
  current?: string | null,
  incoming?: string | null,
): string | null {
  return specificListingUrl(current) ||
    specificListingUrl(incoming) ||
    (current?.trim() || null) ||
    (incoming?.trim() || null);
}

function sameChannel(row: PlatformRow, listing: Listing): boolean {
  if (row.source_provider_id && listing.providerId &&
      row.source_provider_id === listing.providerId) {
    return true;
  }
  if (sameService(row.platform_name, listing.name)) {
    return true;
  }
  const rowHostId = canonicalIdFromUrl(row.evidence_url);
  const listingHostId = canonicalIdFromUrl(listing.url);
  const rowNameId = canonicalId(row.platform_name);
  const listingNameId = canonicalId(listing.name);
  if (rowHostId && (rowHostId === listingNameId || rowHostId === listingHostId)) {
    return true;
  }
  if (listingHostId && listingHostId === rowNameId) {
    return true;
  }
  const left = specificListingUrl(row.evidence_url);
  const right = specificListingUrl(listing.url);
  return !!(left && left === right);
}

function listingKey(listing: Listing): string {
  return listing.providerId || canonicalId(listing.name) || normalizeName(listing.name);
}

function isUserConfirmed(row: PlatformRow): boolean {
  return (
    row.status === 'live' &&
    [
      row.evidence_source,
      row.last_monitoring_source,
    ].some((value) => value === USER_CONFIRMED || value === LISTING_URL)
  );
}

function historyList(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value) ? value as Record<string, unknown>[] : [];
}

function withHistory(
  row: PlatformRow,
  nextStatus: string,
  checkedAt: string,
  source: string,
  reason: string,
): Record<string, unknown>[] {
  if (row.status === nextStatus) {
    return historyList(row.history);
  }
  return [
    ...historyList(row.history),
    {
      previousStatus: row.status,
      newStatus: nextStatus,
      timestamp: checkedAt,
      sourceName: source,
      reason,
      fromAutomatedCheck: true,
    },
  ];
}

function matchListing(
  row: PlatformRow,
  listings: Listing[],
): Listing | undefined {
  return listings.find((listing) => sameChannel(row, listing));
}

function applyFailure(row: PlatformRow, checkedAt: string, detail: string): PlatformRow {
  return {
    ...row,
    last_checked_at: checkedAt,
    last_check_failed: true,
    status_message: 'Could not complete this check',
    status_detail: detail,
  };
}

function adoptListing(row: PlatformRow, listing: Listing): PlatformRow {
  const name = listing.name.trim();
  return {
    ...row,
    platform_name: name || row.platform_name,
    origin: 'automatic',
    license_relationship: 'unknown',
  };
}

function applyLive(row: PlatformRow, listing: Listing, checkedAt: string): PlatformRow {
  const adopted = adoptListing(row, listing);
  return {
    ...adopted,
    status: 'live',
    first_detected_at: adopted.first_detected_at ?? checkedAt,
    last_checked_at: checkedAt,
    removed_at: null,
    status_message: `Detected on ${adopted.platform_name}`,
    status_detail: listing.detail,
    evidence_source: listing.source,
    evidence_url: preferSpecificUrl(row.evidence_url, listing.url),
    last_monitoring_source: listing.source,
    last_match_confidence: 'verifiedMatch',
    last_check_failed: false,
    consecutive_verified_absences: 0,
    source_provider_id: listing.providerId ?? row.source_provider_id,
    history: withHistory(adopted, 'live', checkedAt, listing.source, listing.detail),
  };
}

function applyNetwork(row: PlatformRow, listing: Listing, checkedAt: string): PlatformRow {
  const adopted = adoptListing(row, listing);
  if (isUserConfirmed(row)) {
    return {
      ...adopted,
      last_checked_at: checkedAt,
      last_check_failed: false,
      source_provider_id: listing.providerId ?? row.source_provider_id,
      evidence_url: preferSpecificUrl(row.evidence_url, listing.url),
    };
  }
  return {
    ...adopted,
    status: 'originalNetwork',
    last_checked_at: checkedAt,
    status_message: 'Original network',
    status_detail: listing.detail,
    last_monitoring_source: listing.source,
    last_match_confidence: 'verifiedMatch',
    last_check_failed: false,
    source_provider_id: listing.providerId ?? row.source_provider_id,
    evidence_url: preferSpecificUrl(row.evidence_url, listing.url),
    history: withHistory(
      adopted,
      'originalNetwork',
      checkedAt,
      listing.source,
      listing.detail,
    ),
  };
}

function applyAbsence(row: PlatformRow, checkedAt: string, detail: string): PlatformRow {
  if (isUserConfirmed(row)) {
    return {
      ...row,
      last_checked_at: checkedAt,
      last_check_failed: false,
      last_match_confidence: 'verifiedMatch',
      status_detail:
        'Public listings still do not show this platform. Your confirmation is unchanged.',
    };
  }
  if (row.status !== 'live' && row.status !== 'removed') {
    return {
      ...row,
      last_checked_at: checkedAt,
      last_check_failed: false,
      last_match_confidence: 'verifiedMatch',
      consecutive_verified_absences: 0,
      status_message: 'Not detected yet',
      status_detail: detail,
      last_monitoring_source: LIVE_SOURCE,
    };
  }
  if (row.status === 'removed') {
    return {
      ...row,
      last_checked_at: checkedAt,
      last_check_failed: false,
      last_match_confidence: 'verifiedMatch',
      status_message: 'Previously detected, no longer found',
      status_detail: detail,
      last_monitoring_source: LIVE_SOURCE,
    };
  }
  const consecutive = (row.consecutive_verified_absences ?? 0) + 1;
  if (consecutive < REMOVAL_AFTER) {
    return {
      ...row,
      last_checked_at: checkedAt,
      last_check_failed: false,
      last_match_confidence: 'verifiedMatch',
      consecutive_verified_absences: consecutive,
      status_message: `Detected on ${row.platform_name}`,
      status_detail:
        `Still marked live. Public listings have not shown this platform ${consecutive} of ${REMOVAL_AFTER} confirmed checks.`,
      last_monitoring_source: LIVE_SOURCE,
    };
  }
  return {
    ...row,
    status: 'removed',
    last_checked_at: checkedAt,
    removed_at: checkedAt,
    last_check_failed: false,
    last_match_confidence: 'verifiedMatch',
    consecutive_verified_absences: consecutive,
    status_message: 'Previously detected, no longer found',
    status_detail: detail,
    last_monitoring_source: LIVE_SOURCE,
    history: withHistory(row, 'removed', checkedAt, LIVE_SOURCE, detail),
  };
}

function newFromListing(
  owner: string,
  titleId: string,
  listing: Listing,
  checkedAt: string,
): PlatformRow {
  const waiting: PlatformRow = {
    owner_user_id: owner,
    title_id: titleId,
    platform_name: listing.name,
    status: 'waiting',
    origin: 'automatic',
    license_relationship: 'unknown',
    first_detected_at: null,
    last_checked_at: null,
    removed_at: null,
    status_message: null,
    status_detail: null,
    evidence_source: null,
    evidence_url: null,
    last_monitoring_source: null,
    last_match_confidence: null,
    last_check_failed: false,
    consecutive_verified_absences: 0,
    source_provider_id: listing.providerId ?? null,
    history: [],
  };
  return listing.live
    ? applyLive(waiting, listing, checkedAt)
    : applyNetwork(waiting, listing, checkedAt);
}

function applyListings(
  existing: PlatformRow[],
  listings: Listing[],
  checkedAt: string,
  owner: string,
  titleId: string,
  failedDetail?: string,
): PlatformRow[] {
  if (failedDetail) {
    return existing.map((row) => applyFailure(row, checkedAt, failedDetail));
  }
  const next = existing.map((row) => {
    const listing = matchListing(row, listings);
    if (!listing) {
      return applyAbsence(
        row,
        checkedAt,
        'Verified the title, but public availability was not listed for this platform.',
      );
    }
    return listing.live
      ? applyLive(row, listing, checkedAt)
      : applyNetwork(row, listing, checkedAt);
  });
  for (const listing of listings) {
    if (next.some((row) => matchListing(row, [listing]))) {
      continue;
    }
    next.push(newFromListing(owner, titleId, listing, checkedAt));
  }
  return collapseRows(next);
}

function samePlatformRow(left: PlatformRow, right: PlatformRow): boolean {
  return sameChannel(left, {
    name: right.platform_name,
    live: right.status === 'live',
    url: right.evidence_url ?? undefined,
    providerId: right.source_provider_id ?? undefined,
    detail: '',
    source: '',
  });
}

function collapseRows(rows: PlatformRow[]): PlatformRow[] {
  const kept: PlatformRow[] = [];
  for (const row of rows) {
    const index = kept.findIndex((existing) => samePlatformRow(existing, row));
    if (index < 0) {
      kept.push(row);
      continue;
    }
    kept[index] = preferRow(kept[index], row);
  }
  return kept;
}

function channelRank(row: PlatformRow): number {
  if (row.status === 'live') {
    return 3;
  }
  if (row.status === 'originalNetwork') {
    return 2;
  }
  if (row.status === 'waiting') {
    return 1;
  }
  return 0;
}

function preferRow(left: PlatformRow, right: PlatformRow): PlatformRow {
  const primary = channelRank(right) > channelRank(left) ? right : left;
  const secondary = primary === right ? left : right;
  return {
    ...primary,
    first_detected_at: primary.first_detected_at ?? secondary.first_detected_at,
    source_provider_id: primary.source_provider_id ?? secondary.source_provider_id,
    evidence_url: preferSpecificUrl(primary.evidence_url, secondary.evidence_url),
  };
}

async function tmdbJson(
  apiKey: string,
  path: string,
): Promise<Record<string, unknown>> {
  const url = new URL(`https://api.themoviedb.org${path}`);
  url.searchParams.set('api_key', apiKey);
  const res = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) {
    throw new Error(`tmdb_${res.status}`);
  }
  return await res.json() as Record<string, unknown>;
}

async function fetchListings(
  apiKey: string,
  tmdbId: string,
  mediaType: 'tv' | 'movie',
): Promise<{ listings: Listing[]; posterUrl: string | null }> {
  const providers = await tmdbJson(
    apiKey,
    `/3/${mediaType}/${tmdbId}/watch/providers`,
  );
  const results = providers.results;
  const region =
    results && typeof results === 'object'
      ? (results as Record<string, unknown>).US
      : null;
  const listings: Listing[] = [];
  const seen = new Set<string>();
  if (region && typeof region === 'object') {
    const regionMap = region as Record<string, unknown>;
    const link = typeof regionMap.link === 'string' ? regionMap.link : undefined;
    for (const bucket of ['flatrate', 'free', 'ads', 'rent', 'buy']) {
      const entries = regionMap[bucket];
      if (!Array.isArray(entries)) {
        continue;
      }
      for (const entry of entries) {
        if (!entry || typeof entry !== 'object') {
          continue;
        }
        const item = entry as Record<string, unknown>;
        const name = `${item.provider_name ?? ''}`.trim();
        if (!name) {
          continue;
        }
        const listing: Listing = {
          name,
          live: true,
          url: link,
          providerId: item.provider_id == null ? undefined : String(item.provider_id),
          detail: `Listed as ${name}.`,
          source: LIVE_SOURCE,
        };
        const key = listingKey(listing);
        if (seen.has(key)) {
          continue;
        }
        seen.add(key);
        listings.push(listing);
      }
    }
  }
  let posterUrl: string | null = null;
  if (mediaType === 'tv') {
    const details = await tmdbJson(apiKey, `/3/tv/${tmdbId}`);
    const posterPath = `${details.poster_path ?? ''}`.trim();
    if (posterPath) {
      posterUrl = `https://image.tmdb.org/t/p/w500${posterPath.startsWith('/') ? posterPath : `/${posterPath}`}`;
    }
    const networks = details.networks;
    if (Array.isArray(networks)) {
      for (const raw of networks) {
        if (!raw || typeof raw !== 'object') {
          continue;
        }
        const name = `${(raw as Record<string, unknown>).name ?? ''}`.trim();
        if (!name) {
          continue;
        }
        const listing: Listing = {
          name,
          live: false,
          detail:
            `TMDb lists ${name} as the original network. This is not a current US watch offer.`,
          source: NETWORK_SOURCE,
        };
        const key = listingKey(listing);
        if (seen.has(key)) {
          continue;
        }
        seen.add(key);
        listings.push(listing);
      }
    }
  } else {
    const details = await tmdbJson(apiKey, `/3/movie/${tmdbId}`);
    const posterPath = `${details.poster_path ?? ''}`.trim();
    if (posterPath) {
      posterUrl = `https://image.tmdb.org/t/p/w500${posterPath.startsWith('/') ? posterPath : `/${posterPath}`}`;
    }
  }
  return { listings, posterUrl };
}

function isDue(
  lastCompleted: string | null,
  intervalHours: number,
  now: Date,
): boolean {
  if (!lastCompleted) {
    return true;
  }
  const last = Date.parse(lastCompleted);
  if (Number.isNaN(last)) {
    return true;
  }
  return now.getTime() >= last + intervalHours * 60 * 60 * 1000;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

serve(async (req) => {
  try {
    return await handleCheck(req);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'crash';
    return json({ error: `check_${message}`.slice(0, 140) }, 500);
  }
});

async function handleCheck(req: Request): Promise<Response> {
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
    force?: boolean;
    owner_user_id?: string;
  };
  const ownerUserId = isService
    ? (body.owner_user_id ?? '').toString()
    : (userData.user?.id ?? '');
  if (!isService && !ownerUserId) {
    return json({ error: 'unauthorized' }, 401);
  }
  if (!serviceKey) {
    return json({ error: 'missing_service_role' }, 500);
  }
  const admin: SupabaseClient = createClient(supabaseUrl, serviceKey);
  const apiKey =
    Deno.env.get('RELEASE_STATUS_TMDB_API_KEY') ??
    Deno.env.get('TMDB_API_KEY') ??
    '';
  if (!apiKey) {
    return json({ checked: 0, reason: 'tmdb_not_configured' });
  }

  const { data: lockRow } = await admin
    .from('release_status_check_lock')
    .select('locked_until')
    .eq('id', 1)
    .maybeSingle();
  const now = new Date();
  const lockedUntil = lockRow?.locked_until
    ? Date.parse(String(lockRow.locked_until))
    : 0;
  if (!body.force && lockedUntil > now.getTime()) {
    return json({ checked: 0, reason: 'already_running' });
  }
  await admin.from('release_status_check_lock').upsert({
    id: 1,
    locked_until: new Date(now.getTime() + 20 * 60 * 1000).toISOString(),
    updated_at: now.toISOString(),
  });

  try {
    let profileQuery = admin
      .from('release_status_profiles')
      .select(
        'user_id, monitoring_enabled, check_interval_hours, last_completed_check_at',
      )
      .eq('monitoring_enabled', true);
    if (ownerUserId) {
      profileQuery = profileQuery.eq('user_id', ownerUserId);
    }
    const { data: profiles, error: profileError } = await profileQuery;
    if (profileError) {
      return json({ error: profileError.message }, 400);
    }
    const due = (profiles ?? []).filter((profile) =>
      body.force ||
      isDue(
        profile.last_completed_check_at as string | null,
        (profile.check_interval_hours as number | null) ?? 24,
        now,
      )
    );
    if (due.length === 0) {
      return json({ checked: 0, users: 0, reason: 'none_due' });
    }
    const dueIds = due.map((profile) => profile.user_id as string);
    const { data: titles, error: titleError } = await admin
      .from('release_status_titles')
      .select('owner_user_id, id, tmdb_id, content_type, poster_url')
      .in('owner_user_id', dueIds)
      .not('tmdb_id', 'is', null);
    if (titleError) {
      return json({ error: titleError.message }, 400);
    }
    const titled = (titles ?? []).filter((row) =>
      `${row.tmdb_id ?? ''}`.trim().length > 0
    );
    const factCache = new Map<string, {
      listings: Listing[];
      posterUrl: string | null;
      error?: string;
    }>();
    let fetched = 0;
    let failed = 0;
    let updated = 0;
    for (const title of titled) {
      const tmdbId = `${title.tmdb_id}`.trim();
      const mediaType =
        `${title.content_type ?? ''}`.trim().toLowerCase() === 'tv series'
          ? 'tv'
          : 'movie';
      const cacheKey = `${mediaType}:${tmdbId}`;
      if (!factCache.has(cacheKey)) {
        if (fetched > 0) {
          await sleep(300);
        }
        try {
          const result = await fetchListings(apiKey, tmdbId, mediaType);
          factCache.set(cacheKey, result);
          fetched += 1;
          await admin.from('release_status_tmdb_facts').upsert({
            tmdb_id: tmdbId,
            content_type: title.content_type,
            us_watch_providers: result.listings.filter((item) => item.live),
            original_networks: result.listings.filter((item) => !item.live),
            last_checked_at: now.toISOString(),
            last_error: null,
          });
        } catch (error) {
          failed += 1;
          const message = error instanceof Error ? error.message : 'tmdb_failed';
          factCache.set(cacheKey, {
            listings: [],
            posterUrl: null,
            error: message.slice(0, 120),
          });
          await admin.from('release_status_tmdb_facts').upsert({
            tmdb_id: tmdbId,
            content_type: title.content_type,
            last_checked_at: now.toISOString(),
            last_error: message.slice(0, 120),
          });
        }
      }
      const facts = factCache.get(cacheKey)!;
      const { data: platforms } = await admin
        .from('release_status_platforms')
        .select('*')
        .eq('owner_user_id', title.owner_user_id)
        .eq('title_id', title.id);
      const existing = (platforms ?? []) as PlatformRow[];
      const next = applyListings(
        existing,
        facts.listings,
        now.toISOString(),
        title.owner_user_id as string,
        title.id as string,
        facts.error,
      ).filter((row) => row.platform_name.trim().length > 0);
      const keepNames = new Set(next.map((row) => row.platform_name));
      const stale = existing.filter((row) => {
        if (keepNames.has(row.platform_name)) {
          return false;
        }
        return next.some((kept) => samePlatformRow(kept, row));
      });
      for (const row of stale) {
        await admin
          .from('release_status_platforms')
          .delete()
          .eq('owner_user_id', row.owner_user_id)
          .eq('title_id', row.title_id)
          .eq('platform_name', row.platform_name);
      }
      if (next.length > 0) {
        const upsertRows = next.map((row) => {
          const previous = existing.find((item) => item.id && item.id === row.id);
          if (previous && previous.platform_name === row.platform_name) {
            return row;
          }
          const { id: _id, ...rest } = row;
          return rest;
        });
        const { error: upsertError } = await admin
          .from('release_status_platforms')
          .upsert(upsertRows, { onConflict: 'owner_user_id,title_id,platform_name' });
        if (!upsertError) {
          updated += next.length;
        }
      }
      await admin
        .from('release_status_titles')
        .update({
          last_looked_up_at: now.toISOString(),
          poster_url: facts.posterUrl ?? title.poster_url,
        })
        .eq('owner_user_id', title.owner_user_id)
        .eq('id', title.id);
    }
    for (const profile of due) {
      await admin
        .from('release_status_profiles')
        .update({ last_completed_check_at: now.toISOString() })
        .eq('user_id', profile.user_id);
    }
    return json({
      checked: titled.length,
      users: due.length,
      fetched,
      failed,
      platformsTouched: updated,
    });
  } finally {
    await admin.from('release_status_check_lock').upsert({
      id: 1,
      locked_until: new Date(0).toISOString(),
      updated_at: new Date().toISOString(),
    });
  }
}
