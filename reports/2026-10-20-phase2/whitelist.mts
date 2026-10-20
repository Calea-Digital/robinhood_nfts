// Phase 2 — adversarial run against the local stack, through the webapp's public routes only.
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';

const WEB = 'http://127.0.0.1:3100';
const MOCK = 'http://127.0.0.1:8788/_mock/wagers/';
const run = Math.random().toString(36).slice(2, 8);
let failures = 0;
let ipCounter = 1;
const freshIp = () => `10.9.${Math.floor(ipCounter / 250)}.${(ipCounter++ % 250) + 1}`;

function check(name: string, ok: boolean, detail: unknown) {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `\n      ${JSON.stringify(detail).slice(0, 400)}`}`);
}

async function call(path: string, opts: { method?: string; did?: string; body?: unknown; raw?: string; ip?: string; headers?: Record<string, string> } = {}) {
  const headers: Record<string, string> = { 'X-Forwarded-For': opts.ip ?? freshIp(), ...opts.headers };
  if (opts.did) headers.Authorization = `Bearer dev:${opts.did}`;
  if (opts.body !== undefined || opts.raw !== undefined) headers['content-type'] = 'application/json';
  const response = await fetch(WEB + path, { method: opts.method ?? (opts.body !== undefined || opts.raw !== undefined ? 'POST' : 'GET'), headers, body: opts.raw ?? (opts.body !== undefined ? JSON.stringify(opts.body) : undefined) });
  const text = await response.text();
  let json: any = null;
  try { json = JSON.parse(text); } catch { /* not JSON */ }
  return { status: response.status, json, text };
}

const setWager = (did: string, usd: number) => fetch(MOCK + did, { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ totalWageredUsd: usd }) });

/** A fresh account whose starting point is $0 and who has wagered `usd` since. */
async function account(name: string, usd: number) {
  const did = `did:privy:qa-${run}-${name}`;
  await setWager(did, 0);
  await call('/api/whitelist/me', { did });
  await setWager(did, usd);
  return did;
}

async function sign(key: `0x${string}`, request: any) {
  const signer = privateKeyToAccount(key);
  const message = { ...request.message, expiry: BigInt(request.message.expiry) };
  return signer.signTypedData({ domain: request.domain, types: request.types, primaryType: request.primaryType, message });
}

async function bind(did: string, key: `0x${string}`, wallet = privateKeyToAccount(key).address) {
  const challenge = await call('/api/whitelist/me/wallet/challenge', { did, body: { wallet } });
  if (challenge.status !== 200) return challenge;
  return call('/api/whitelist/me/wallet', { did, body: { nonce: challenge.json.nonce, signature: await sign(key, challenge.json.request) } });
}

async function claimOnce(did: string, key: `0x${string}`) {
  const challenge = await call('/api/whitelist/me/claims/challenge', { did, body: { quantity: 1 } });
  if (challenge.status !== 200) return challenge;
  return call('/api/whitelist/me/claims', { did, body: { nonce: challenge.json.nonce, signature: await sign(key, challenge.json.request) } });
}

// --- Auth and transport ---------------------------------------------------------------------------
{
  const noAuth = await call('/api/whitelist/me');
  check('no bearer is refused', noAuth.status === 401, noAuth);
  const junk = await call('/api/whitelist/me', { headers: { Authorization: 'Bearer dev:not-a-did' } });
  check('a bearer that is not a Privy DID is refused', junk.status === 401, junk);
  const notJwt = await call('/api/whitelist/me', { headers: { Authorization: 'Bearer eyJhbGciOiJub25lIn0.eyJzdWIiOiJkaWQ6cHJpdnk6eCJ9.' } });
  check('an unsigned (alg none) token is refused', notJwt.status === 401, notJwt);
  for (const path of ['/api/whitelist/me/../pool', '/api/whitelist/%2e%2e/pool', '/api/whitelist/admin', '/api/whitelist/public/wallets/0x70997970C51812dc3A010C7d01b50e0d17dc79C8']) {
    const r = await call(path);
    check(`no route beyond the allowlist: ${path}`, r.status === 404 || (path.includes('..') && r.json?.capacity !== undefined), { status: r.status, body: r.text.slice(0, 80) });
  }
  const wrongMethod = await call('/api/whitelist/me/claims', { method: 'GET', did: 'did:privy:x' });
  check('a wrong method is refused', wrongMethod.status === 405, wrongMethod);
}

// --- Body validation in the proxy --------------------------------------------------------------------
{
  const did = await account('body', 60);
  const extra = await call('/api/whitelist/me/claims/challenge', { did, body: { quantity: 1, wallet: '0x0000000000000000000000000000000000000001' } });
  check('an extra field is refused before the API', extra.status === 400, extra);
  const two = await call('/api/whitelist/me/claims/challenge', { did, body: { quantity: 2 } });
  check('quantity 2 is refused', two.status === 400, two);
  const proto = await call('/api/whitelist/me/claims/challenge', { did, raw: '{"quantity":1,"__proto__":{"admin":true}}' });
  check('a __proto__ key is refused', proto.status === 400, proto);
  const big = await call('/api/whitelist/me/wallet', { did, raw: JSON.stringify({ nonce: '0x' + '1'.repeat(64), signature: '0x' + 'a'.repeat(30_000) }) });
  check('a body over 24 KB is refused', big.status === 413 || big.status === 400, { status: big.status, body: big.text.slice(0, 120) });
  const notJson = await call('/api/whitelist/me/wallet', { did, raw: '{nonce:' });
  check('malformed JSON is refused', notJson.status === 400, notJson);
}

// --- The full flow, then the attacks on it -------------------------------------------------------------
const aliceKey = generatePrivateKey();
const malloryKey = generatePrivateKey();
const alice = await account('alice', 150);
const mallory = await account('mallory', 150);
const aliceWallet = privateKeyToAccount(aliceKey).address;
{
  const bound = await bind(alice, aliceKey);
  check('alice binds her wallet with a free signature', bound.status === 200 && bound.json?.wallet?.verified === true, bound);
  const first = await claimOnce(alice, aliceKey);
  const second = await claimOnce(alice, aliceKey);
  const third = await claimOnce(alice, aliceKey);
  check('alice claims spot 1 and spot 2', first.status === 200 && second.status === 200 && second.json?.spots?.claimed === 2, { first: first.json?.spots, second: second.json?.spots });
  check('a third claim is refused', third.status >= 400, third);
}
{
  // Mallory binds alice's wallet: he can only sign with his own key.
  const challenge = await call('/api/whitelist/me/wallet/challenge', { did: mallory, body: { wallet: aliceWallet } });
  const forged = challenge.status === 200 ? await call('/api/whitelist/me/wallet', { did: mallory, body: { nonce: challenge.json.nonce, signature: await sign(malloryKey, challenge.json.request) } }) : challenge;
  check("mallory cannot bind alice's wallet with his own signature", forged.status >= 400, { challenge: [challenge.status, challenge.json?.code], forged: [forged.status, forged.json?.code] });
  // A wallet nobody has claimed with yet: mallory asks to bind it and signs with his own key.
  const fresh = privateKeyToAccount(generatePrivateKey()).address;
  const c2 = await call('/api/whitelist/me/wallet/challenge', { did: mallory, body: { wallet: fresh } });
  const f2 = await call('/api/whitelist/me/wallet', { did: mallory, body: { nonce: c2.json?.nonce, signature: await sign(malloryKey, c2.json?.request) } });
  check("a wallet's binding needs that wallet's own signature", c2.status === 200 && f2.status >= 400, { c2: c2.status, f2: [f2.status, f2.json?.code] });
  // Mallory replays a nonce from alice's (used) flow, and re-submits alice's request as his.
  const aliceChallenge = await call('/api/whitelist/me/claims/challenge', { did: alice, body: { quantity: 1 } });
  const stolen = await call('/api/whitelist/me/claims', { did: mallory, body: { nonce: aliceChallenge.json?.nonce ?? '0x' + '0'.repeat(64), signature: aliceChallenge.json?.request ? await sign(aliceKey, aliceChallenge.json.request) : '0x00' } });
  const malloryView = await call('/api/whitelist/me', { did: mallory });
  check("alice's nonce and signature claim nothing for mallory", malloryView.json?.spots?.claimed === 0, { stolen: stolen.json, view: malloryView.json?.spots });
  // The same wallet on a second account.
  const steal = await bind(mallory, aliceKey);
  check('a wallet that took wagering spots cannot be bound by another account (even with its key)', steal.status >= 400, steal);
}

// --- Races through the public routes ---------------------------------------------------------------
{
  const key = generatePrivateKey();
  const racer = await account('racer', 150);
  await bind(racer, key);
  const challenges = await Promise.all(Array.from({ length: 8 }, () => call('/api/whitelist/me/claims/challenge', { did: racer, body: { quantity: 1 } })));
  const signed = await Promise.all(challenges.filter((c) => c.status === 200).map(async (c) => ({ nonce: c.json.nonce, signature: await sign(key, c.json.request) })));
  const results = await Promise.all(signed.map((body) => call('/api/whitelist/me/claims', { did: racer, body })));
  const view = await call('/api/whitelist/me', { did: racer });
  check(`8 parallel claims (${signed.length} challenges) record exactly two spots`, view.json?.spots?.claimed === 2, { statuses: results.map((r) => r.status), spots: view.json?.spots });
}
{
  // Two accounts race to bind one wallet whose owner signs both (e.g. a shared device).
  const key = generatePrivateKey();
  const a = await account('race-a', 60);
  const b = await account('race-b', 60);
  await Promise.all([bind(a, key), bind(b, key)]);
  const [ca, cb] = await Promise.all([claimOnce(a, key), claimOnce(b, key)]);
  check('one wallet bound by two accounts at once: only one account gets wagering spots on it', [ca, cb].filter((r) => r.status === 200 && (r.json?.spots?.claimed ?? 0) > 0).length === 1, { a: [ca.status, ca.json?.code], b: [cb.status, cb.json?.code] });
}

// --- Rate limiting (M-3 fix: one bucket per visitor) ---------------------------------------------------
{
  const flood = await Promise.all(Array.from({ length: 125 }, () => call('/api/whitelist/pool', { ip: '10.77.0.1' })));
  const limited = flood.filter((r) => r.status === 429).length;
  const other = await call('/api/whitelist/pool', { ip: '10.77.0.2' });
  check(`one visitor is limited (${limited} of 125 got 429) and another is not`, limited > 0 && other.status === 200, { limited, other: other.status });
}

console.log(failures ? `\n${failures} FAILED` : '\nall passed');
process.exit(failures ? 1 : 0);
