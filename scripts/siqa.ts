import { Phi3Mini4kModelDataTx, SiqaProcess } from "./config";
import siqaData from "./siqa-dev.json"
import { msgResultWrapper, moneySigner } from "./wallet";

const msgResult = msgResultWrapper(moneySigner)


async function main() {
  // await InitSiqa()
  // await CreatePool()
  // await JoinPool()
  // await InitBenchmark()
  await EvaluateBenchmark()
  // await GetDataSetInfo()
  // console.log(await GetLeaderboard())
}

async function InitSiqa() {
  await msgResult(SiqaProcess, {
    Action: "Init",
  })
  await msgResult(SiqaProcess, {
    Action: "Load-Data"
  }, siqaData)
}

async function InitBenchmark() {
  await msgResult(SiqaProcess, {
    Action: "Benchmark",
  }, Phi3Mini4kModelDataTx)
}

async function EvaluateBenchmark() {
  await msgResult(SiqaProcess, {
    Action: "Evaluate",
    Model: Phi3Mini4kModelDataTx,
  }, 100)
}

main()