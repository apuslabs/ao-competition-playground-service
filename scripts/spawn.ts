import { connect, createDataItemSigner } from "@permaweb/aoconnect";
import { DEFAULT_SCHEDULER, SQLITE_MODULE } from "./config";
import { readFileSync } from "fs";
import { join } from "path";
import { obj2tags } from "./utils";

const wallet = JSON.parse(
  readFileSync(join(__dirname, "../wallet.json")).toString(),
);

const ao = connect();
async function SpawnBenchmarkProcess() {
  const processID = await ao.spawn({
    module: SQLITE_MODULE,
    scheduler: DEFAULT_SCHEDULER,
    signer: createDataItemSigner(wallet),
    tags: obj2tags({
      Extensions: "WeaveDrive",
      Variant: "weavedrive.1",
      "Availability-Type": JSON.stringify(["Assignments", "Individual"])
    })
  });
  console.info(`Spawned benchmark process: ${processID}`);
}

SpawnBenchmarkProcess();