// Phase 2 — claim, tx-status and Relay proxy routes, against the local webapp on testnet 46630.
const WEB = 'http://127.0.0.1:3100';
const BENEFICIARY = '0xA10Dfe3bCE841E3C89FAa794738A7156754C04B5';
const VESTING = '0x47cDC1C9DB9a250AAb2b0F82f830acd3038ed69f';
const STRANGER = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
let failures = 0;
let ip = 1;

function check(name: string, ok: boolean, detail: unknown) {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `\n      ${JSON.stringify(detail).slice(0, 400)}`}`);
}
async function call(path: string, init: RequestInit & { ip?: string } = {}) {
  const response = await fetch(WEB + path, { ...init, headers: { 'X-Forwarded-For': init.ip ?? `10.8.0.${ip++}`, ...(init.body ? { 'content-type': 'application/json' } : {}), ...(init.headers as Record<string, string>) } });
  const text = await response.text();
  let json: any = null;
  try { json = JSON.parse(text); } catch { /* not JSON */ }
  return { status: response.status, json, text, headers: response.headers };
}

// --- H-1: the page's path now exists; the old one does not ---------------------------------------------------
{
  const old = await call(`/api/vesting?chainId=46630&account=${BENEFICIARY}`);
  const now = await call(`/api/claim/vesting?chainId=46630&account=${BENEFICIARY}`);
  check('H-1: /api/claim/vesting answers the beneficiary with allocations', now.status === 200 && Array.isArray(now.json?.allocations ?? now.json?.wallets ?? now.json) , { status: now.status, body: now.text.slice(0, 300) });
  check('H-1: the old path stays a 404', old.status === 404, old.status);
  console.log('      vesting body keys:', now.json && Object.keys(now.json));
  const stranger = await call(`/api/claim/vesting?chainId=46630&account=${STRANGER}`);
  check('an account with no allocation gets an empty answer, not an error', stranger.status === 200, { status: stranger.status, body: stranger.text.slice(0, 200) });
}

// --- M-2: minBlock ----------------------------------------------------------------------------------------
{
  const far = await call(`/api/claim/vesting?chainId=46630&account=${BENEFICIARY}&minBlock=99999999999`);
  check('M-2: a minBlock far beyond the chain is refused as bad_request', far.status === 400 && far.json?.error?.code === 'bad_request', { status: far.status, body: far.json });
  const past = await call(`/api/claim/vesting?chainId=46630&account=${BENEFICIARY}&minBlock=1`);
  check('M-2: a past minBlock is answered from the shared snapshot', past.status === 200, past.status);
  const t0 = Date.now();
  const burst = await Promise.all(Array.from({ length: 20 }, () => call(`/api/claim/vesting?chainId=46630&account=${BENEFICIARY}&minBlock=99999999999`)));
  check(`M-2: 20 hostile minBlock calls are refused cheaply (${Date.now() - t0} ms)`, burst.every((r) => r.status === 400 || r.status === 429), burst.map((r) => r.status));
}

// --- Inputs ---------------------------------------------------------------------------------------------
{
  const wrongChain = await call(`/api/claim/vesting?chainId=4663&account=${BENEFICIARY}`);
  check('the wrong chain is refused', wrongChain.status >= 400 && wrongChain.status < 500, { status: wrongChain.status, body: wrongChain.json });
  const badAddress = await call(`/api/claim/vesting?chainId=46630&account=0x123`);
  check('a malformed address is refused', badAddress.status === 400, badAddress.json);
  const badChecksum = await call(`/api/claim/vesting?chainId=46630&account=0xa10dfe3bce841e3c89faa794738a7156754C04B5`);
  check('a mis-checksummed mixed-case address is refused', badChecksum.status === 400, { status: badChecksum.status, body: badChecksum.json });
  const dup = await call(`/api/claim/vesting?chainId=46630&chainId=1&account=${BENEFICIARY}`);
  check('a doubled parameter is refused', dup.status === 400, { status: dup.status, body: dup.json });
}

// --- Prepare: never for someone else ------------------------------------------------------------------------
{
  const other = await call('/api/claim/prepare', { method: 'POST', body: JSON.stringify({ chainId: 46630, account: STRANGER, vestingWallet: VESTING }) });
  check("prepare refuses an account that does not own the vesting wallet", other.status >= 400 && other.status < 500, { status: other.status, body: other.json });
  const owner = await call('/api/claim/prepare', { method: 'POST', body: JSON.stringify({ chainId: 46630, account: BENEFICIARY, vestingWallet: VESTING }) });
  check("prepare for the owner returns release(token) on the vesting wallet, never a value", owner.status === 200 ? owner.json?.request?.to?.toLowerCase() === VESTING.toLowerCase() && owner.json?.request?.value === '0' : owner.status < 500, { status: owner.status, body: owner.json });
  const notManifest = await call('/api/claim/prepare', { method: 'POST', body: JSON.stringify({ chainId: 46630, account: BENEFICIARY, vestingWallet: STRANGER }) });
  check('prepare refuses a vesting wallet outside the manifest', notManifest.status >= 400 && notManifest.status < 500, { status: notManifest.status, body: notManifest.json });
  const extra = await call('/api/claim/prepare', { method: 'POST', body: JSON.stringify({ chainId: 46630, account: BENEFICIARY, vestingWallet: VESTING, to: STRANGER }) });
  check('prepare refuses unknown fields', extra.status === 400, { status: extra.status, body: extra.json });
  const huge = await call('/api/claim/prepare', { method: 'POST', body: JSON.stringify({ chainId: 46630, account: BENEFICIARY, vestingWallet: VESTING, pad: 'x'.repeat(200_000) }) });
  check('prepare refuses an oversized body', huge.status === 413 || huge.status === 400, huge.status);
}

// --- Transaction status ---------------------------------------------------------------------------------
{
  const random = '0x' + 'ab'.repeat(32);
  const unknown = await call(`/api/claim/transactions/${random}?chainId=46630&account=${BENEFICIARY}&vestingWallet=${VESTING}`);
  check('an unknown hash is a status, not an error', unknown.status === 200 || unknown.status === 404, { status: unknown.status, body: unknown.json });
  const inject = await call(`/api/claim/transactions/${random}%22%7D?chainId=46630&account=${BENEFICIARY}&vestingWallet=${VESTING}`);
  check('a hash with trailing bytes is refused', inject.status === 400, inject.status);
  const nonce = await call(`/api/claim/transactions/${random}?chainId=46630&account=${BENEFICIARY}&vestingWallet=${VESTING}&nonce=99999999999999999999`);
  check('an out-of-range nonce is refused', nonce.status === 400, { status: nonce.status, body: nonce.json });
  const cache = unknown.headers.get('cache-control') ?? '';
  check('transaction status is never cached publicly', /private|no-store/.test(cache), cache);
}

// --- Relay proxy ---------------------------------------------------------------------------------------
{
  for (const path of ['/api/relay/..%2f..%2fadmin', '/api/relay/https:%2f%2fevil.example', '/api/relay/%2e%2e', '/api/relay/chains/../../admin', '/api/relay/requests/v2/x/../../y']) {
    const r = await call(path);
    check(`relay refuses ${path}`, r.status === 400 || r.status === 404, { status: r.status, body: r.text.slice(0, 120) });
  }
  const notAllowed = await call('/api/relay/admin/keys');
  check('relay refuses an endpoint outside its allowlist', notAllowed.status === 400 || notAllowed.status === 404, { status: notAllowed.status, body: notAllowed.text.slice(0, 120) });
  const del = await call('/api/relay/chains', { method: 'DELETE' });
  check('relay refuses a method outside its allowlist', del.status === 405 || del.status === 400 || del.status === 404, del.status);
  const big = await call('/api/relay/quote', { method: 'POST', body: JSON.stringify({ pad: 'x'.repeat(2_000_000) }) });
  check('relay refuses a 2 MB body', big.status === 413 || big.status === 400, big.status);
  const chains = await call('/api/relay/chains');
  check('relay passes an allowed read through as JSON', chains.status === 200 && Array.isArray(chains.json?.chains), { status: chains.status, type: chains.headers.get('content-type') });
  check('the Relay key never reaches the browser', !/api[-_]?key/i.test(chains.text.slice(0, 5000)) , null);
}

console.log(failures ? `\n${failures} FAILED` : '\nall passed');
process.exit(failures ? 1 : 0);
