import { ModelID, PoolProcess, SiqaProcess, WrappedARProcess } from "./config"
import { msgResultWrapper, commonSigner } from "./wallet"

const msgResultCommon = msgResultWrapper(commonSigner)

async function Evaluate() {
    console.log(`Running Evaluate at ${new Date().toISOString()}`);
    const result = await msgResultCommon(PoolProcess, {
        Action: "Evaluate"
    }, 2)
    console.log(result)
}

async function AllocateRewards() {
    console.log(`Running AllocateRewards at ${new Date().toISOString()}`);
    const result = await msgResultCommon(PoolProcess, {
        Action: "Allocate-Rewards"
    }, 2)
    console.log(result)
}

function runTaskAtInterval(task: () => Promise<void>, interval: number) {
    task().catch(console.error); // 立即运行一次
    setInterval(() => {
        task().catch(console.error);
    }, interval);
}

const main = async () => {

    const evaluateInterval = 60 * 60 * 1000; // 60分钟
    const allocateInterval = 12 * 60 * 60 * 1000; // 12小时

    runTaskAtInterval(Evaluate, evaluateInterval);
    runTaskAtInterval(AllocateRewards, allocateInterval);
};

main().catch(error => {
    console.error("An error occurred:", error);
    process.exit(1);
});