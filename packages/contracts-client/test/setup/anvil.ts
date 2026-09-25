import { spawn, type ChildProcess } from "node:child_process";
import { createServer } from "node:net";

/** A local anvil node for one test file: a fresh chain, stopped in `afterAll`. */
export interface Anvil {
  rpcUrl: string;
  stop: () => Promise<void>;
}

function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.unref();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (address === null || typeof address === "string") return reject(new Error("no port"));
      server.close(() => resolve(address.port));
    });
  });
}

async function waitForRpc(rpcUrl: string, child: ChildProcess): Promise<void> {
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) throw new Error(`anvil exited with code ${child.exitCode}`);
    try {
      const response = await fetch(rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] }),
      });
      if (response.ok) return;
    } catch {
      // not listening yet
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error("anvil did not start within 15 s");
}

/** Starts anvil on a free port with its default mnemonic and chain id 31337. */
export async function startAnvil(): Promise<Anvil> {
  const port = await freePort();
  const child = spawn("anvil", ["--port", String(port), "--silent", "--chain-id", "31337"], {
    stdio: ["ignore", "ignore", "inherit"],
  });
  const rpcUrl = `http://127.0.0.1:${port}`;
  await waitForRpc(rpcUrl, child);
  return {
    rpcUrl,
    stop: () =>
      new Promise((resolve) => {
        if (child.exitCode !== null) return resolve();
        child.once("exit", () => resolve());
        child.kill();
      }),
  };
}
