/**
 * `@mintabear/contracts-client` — the typed client for the MintABear contracts on Robinhood Chain.
 *
 * Start with {@link createMintABearClient}; every function it uses is exported too. Errors are
 * {@link MintABearError}s — `explainError(error).userMessage` is the text to show a holder.
 * The voucher backend is a separate, server-only entry point: `@mintabear/contracts-client/backend`.
 *
 * @packageDocumentation
 */
export * from "./abi/index.js";
export * from "./activation.js";
export * from "./addresses.js";
export * from "./allowlist.js";
export * from "./calls.js";
export * from "./chains.js";
export * from "./client.js";
export * from "./constants.js";
export * from "./errors.js";
export * from "./events.js";
export * from "./mint.js";
export * from "./split/compute.js";
export * from "./split/inputs.js";
export * from "./transfer.js";
export * from "./units.js";
export * from "./whitelist.js";
export * from "./whitelistImport.js";
