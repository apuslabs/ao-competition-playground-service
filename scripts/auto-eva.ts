import { ModelID, PoolProcess, SiqaProcess, WrappedARProcess } from "./config";
import { msgResultWrapper, commonSigner } from "./wallet";

const msgResultCommon = msgResultWrapper(commonSigner);

async function Evaluate() {
  console.log(`Running Evaluate at ${new Date().toISOString()}`);
  await msgResultCommon(
    PoolProcess,
    {
      Action: "Evaluate",
    },
    18
  );
}

async function AllocateRewards() {
  console.log(`Running AllocateRewards at ${new Date().toISOString()}`);
  await msgResultCommon(
    PoolProcess,
    {
      Action: "Allocate-Rewards",
    }
  );
}

function runTaskAtInterval(task: () => Promise<void>, interval: number) {
    task().catch(console.error); // 立即运行一次
    setInterval(() => {
        task().catch(console.error);
    }, interval);
}

const evaluateInterval = 60 * 60 * 1000; // 60分钟
const allocateInterval = 60 * 60 * 1000; // 60分钟

runTaskAtInterval(Evaluate, evaluateInterval);
runTaskAtInterval(AllocateRewards, allocateInterval);

process.on("SIGINT", () => {
    console.log("Process interrupted. Exiting gracefully...");
    process.exit();
});

process.on("SIGTERM", () => {
    console.log("Process terminated. Exiting gracefully...");
    process.exit();
});
