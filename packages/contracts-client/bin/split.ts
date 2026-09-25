// The reference royalty split (DEL-6), as a command:
//
//   npx tsx bin/split.ts --rpc <archive RPC> --bears <MintABear> --activation <Activation> \
//     --from-block <collection deploy block> --block <closing block> --funding <base units> \
//     [--carried-in <base units>] [--mode events|snapshot] [--gas-budget <gas>] [--block-range <blocks>]
//
// Prints JSON: the distributable amount, eligible and excluded weight, one allocation per wallet
// (ascending by address), and the rounding carried to the next distribution. Allocations plus
// carried equal funding plus carried-in exactly. Reads only; sends nothing.

import { parseArgs } from "node:util";
import { createPublicClient, getAddress, http } from "viem";

import { computeSplit } from "../src/split/compute.js";
import { rowsFromEvents, rowsFromSnapshot } from "../src/split/inputs.js";

const { values } = parseArgs({
  options: {
    rpc: { type: "string" },
    bears: { type: "string" },
    activation: { type: "string" },
    "from-block": { type: "string" },
    block: { type: "string" },
    funding: { type: "string" },
    "carried-in": { type: "string", default: "0" },
    mode: { type: "string", default: "events" },
    "gas-budget": { type: "string" },
    "block-range": { type: "string" },
  },
});

function required(name: keyof typeof values): string {
  const value = values[name];
  if (typeof value !== "string" || value === "") {
    console.error(`missing --${name}`);
    process.exit(2);
  }
  return value;
}

const client = createPublicClient({ transport: http(required("rpc")), cacheTime: 0 });
const bears = getAddress(required("bears"));
const activation = getAddress(required("activation"));
const closingBlock = BigInt(required("block"));
const funding = BigInt(required("funding"));
const carriedIn = BigInt(values["carried-in"] ?? "0");

let rows;
if (values.mode === "events") {
  rows = await rowsFromEvents(
    client,
    { bears, activation },
    {
      fromBlock: BigInt(required("from-block")),
      closingBlock,
      blockRange: values["block-range"] ? BigInt(values["block-range"]) : undefined,
    },
  );
} else if (values.mode === "snapshot") {
  rows = (await rowsFromSnapshot(client, { activation }, { closingBlock, gasBudget: values["gas-budget"] ? BigInt(values["gas-budget"]) : undefined }))
    .rows;
} else {
  console.error(`--mode is events or snapshot, not ${values.mode}`);
  process.exit(2);
}

const result = computeSplit(rows, funding, { carriedIn });
console.log(JSON.stringify({ closingBlock, bears: rows.length, ...result }, (_, v) => (typeof v === "bigint" ? v.toString() : v), 2));
