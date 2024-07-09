const { connect, createDataItemSigner } = require("@permaweb/aoconnect");

const {
  result,
  results,
  message,
  spawn,
  monitor,
  unmonitor,
  dryrun,
} = connect({
  CU_URL: "http://localhost:6363",
});

const { readFileSync } = require('fs')

const wallet = JSON.parse(
  readFileSync("./wallet.json").toString(),
);

async function msg(process, tags, data) {
  const tagsArr = Object.entries(tags).map(([name, value]) => ({ name, value }));
  return message({
    process,
    tags: tagsArr,
    data: JSON.stringify(data),
    signer: createDataItemSigner(wallet),
  })
}

const SiqaProcess = "qiNFdzQ82ecHqLIpEk1FvU1Q1udRj9mmoYdCZ0tj04E"
const PoolProcess = "1mkMVtnJDAGGCjke6Cx1juspsGJ3YRO-twntzBTYqvs"
const ModelID = "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
const RouterProcess = "glGRJ4CqL-mL29RN8udCTro2-7svs7hfqH9Vf4WXAn4"
const WorkerProcess = "Ourv4yTMcfTmyqy3KnilgmajzpZcGWBnRkm-BKe-Md8"

async function main() {
  // await InitSiqa()
  // await GetSiqaState()
  // await CreatePool()
  await JoinPool()
  // await InitWorker()
  // await RegisterWorker()
  // await Benchmark()

  // await GetDataSetInfo()
  // console.log(await GetLeaderboard())
}

function InitSiqa() {
  return msg(SiqaProcess, {
    Action: "Init",
  }).then(msgId => {
    console.log(msgId)
    return result({
      message: msgId,
        process: SiqaProcess,
      })
  }).then(output => {
    console.log(output)
    console.log("InitSiqa done")
  })
}

async function GetSiqaState() {
  return msg(SiqaProcess, {
    Action: "Eval",
  }, "DataSets").then(msgId => {
    return result({
      message: msgId,
      process: SiqaProcess,
    })
  })
}

async function CreatePool() {
  await msg(PoolProcess, {
    Action: "Create-Pool",
  }, {
    dataset: SiqaProcess,
  })
}

async function JoinPool() {
  await msg(PoolProcess, {
    Action: "Join-Pool",
  }, {
    dataset: SiqaProcess,
    model: ModelID
  })
}

async function InitWorker() {
  await msg(WorkerProcess, {
    Action: "setModel",
  }, ModelID)
}


async function RegisterWorker() {
  await msg(RouterProcess, {
    Action: "Register-Worker",
  })
}

async function GetLeaderboard() {
  const msgId = await msg(SiqaProcess, {
    Action: "Leaderboard",
  }, {
    dataset: SiqaProcess,
  })
  const { Output } = await result({
    message: msgId,
    process: SiqaProcess,
  })
  return Output.data
}
main()