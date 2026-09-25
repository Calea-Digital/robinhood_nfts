import type { Address } from "viem";

/** OpenSea's canonical SeaDrop, the collection's only allowed minter (COL-1). */
export const SEADROP_ADDRESS: Address = "0x00005EA00Ac477B1030CE78506496e8C2dE24bf5";

/** The address the royalty split excludes from the eligible total (ACT-10). */
export const DEAD_ADDRESS: Address = "0x000000000000000000000000000000000000dEaD";

/** The collection's fixed supply; ids run 1..MAX_BEARS (COL-2). */
export const MAX_BEARS = 4444;

/** The highest activation level (ACT-2). */
export const MAX_LEVEL = 5;

/** Whitelist caps (WL-1): allocations per wallet and per getminted.io account. */
export const MAX_CLAIMS_PER_WALLET = 2;
export const MAX_CLAIMS_PER_ACCOUNT = 2;
