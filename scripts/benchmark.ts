import { ModelID, PoolProcess, SiqaProcess, WrappedARProcess } from "./config"
import { moneySigner, msgResultWrapper, originSigner } from "./wallet"

const msgResultOrigin = msgResultWrapper(originSigner)
const msgResultMoney = msgResultWrapper(moneySigner)

async function CreatePool() {
  await msgResultOrigin(WrappedARProcess, {
    Action: "Transfer",
    Recipient: PoolProcess,
    Quantity: "100",
    "X-Dataset": SiqaProcess,
    "X-Allocation": "ArithmeticDecrease"
  })
}

async function JoinPool() {
  await msgResultMoney(PoolProcess, {
    Action: "Join-Pool"
  }, {
    dataset: SiqaProcess,
    model: ModelID
  })
}

async function UpdateLeaderboard() {
  await msgResultMoney(PoolProcess, {
    Action: "Update-Leaderboard"
  }, {
    dataset: SiqaProcess,
    model: ModelID
  })
}

async function GetLeaderboard() {
  const result = await msgResultMoney(PoolProcess, {
    Action: "Leaderboard"
  }, SiqaProcess)
  console.log(result)
}

async function main() {
  // await CreatePool()
  // await JoinPool()
  // await UpdateLeaderboard()
  await GetLeaderboard()
}

main().then(() => {
  process.exit(0)
})