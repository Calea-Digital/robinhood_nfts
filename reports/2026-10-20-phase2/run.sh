#!/bin/bash
cd ~/trees/NFT-qa/apps/whitelist-api
npx -y pnpm@12.14.0 run mock-wager > /private/tmp/claude-501/-Users-bojanjovin-trees-robinhood-nfts/3fa42f41-4f1a-4108-a725-4bd8a37f6c1d/scratchpad/stack/mock.log 2>&1 &
env NODE_ENV=development HOST=127.0.0.1 PORT=8787 DATABASE_URL=postgres://whitelist:whitelist@127.0.0.1:55432/whitelist SERVICE_TOKEN=$TOKEN AUTH_MODE=dev WAGER_API_URL=http://127.0.0.1:8788/api/external/me/wagered CAMPAIGN_START=2026-10-01T12:00:00Z CAMPAIGN_END=2026-10-27T12:00:00Z TRUST_PROXY=1 RPC_URL=https://rpc.testnet.chain.robinhood.com npx -y pnpm@12.14.0 exec tsx src/main.ts > /private/tmp/claude-501/-Users-bojanjovin-trees-robinhood-nfts/3fa42f41-4f1a-4108-a725-4bd8a37f6c1d/scratchpad/stack/api.log 2>&1 &
cd ~/trees/NFT-qa/apps/webapp
env -i PATH="$PATH" HOME="$HOME" NODE_ENV=production PORT=3100 APP_TRUSTED_PROXY_HOPS=1 WHITELIST_API_URL=http://127.0.0.1:8787 WHITELIST_SERVICE_TOKEN=$TOKEN PRIVY_APP_ID=local-qa CLAIM_CHAIN_ID=46630 CLAIM_CLAIMS_ENABLED=true CLAIM_RPC_URL=https://rpc.testnet.chain.robinhood.com STAKING_CHAIN_ID=46630 APP_PUBLIC_URL=http://localhost:3100 npx -y pnpm@12.14.0 exec next start --port 3100 > /private/tmp/claude-501/-Users-bojanjovin-trees-robinhood-nfts/3fa42f41-4f1a-4108-a725-4bd8a37f6c1d/scratchpad/stack/web.log 2>&1 &
wait
