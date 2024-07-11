import { SiqaProcess, WrappedARProcess } from "./config";
import { msgResultWrapper, originSigner } from "./wallet";

const msgResult = msgResultWrapper(originSigner)

async function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function depositProcess(processID: string) {
  await msgResult(WrappedARProcess, {
    Action: "Transfer",
    Recipient: processID,
    Quantity: "1000",
  })
}

async function balance(processID: string) {
  await msgResult(WrappedARProcess, {
    Action: "Balance",
    Recipient: processID,
  })
}

// async function getBalance(processID: string)

async function main() {
  await depositProcess(SiqaProcess)
  await sleep(2000)
  await balance(SiqaProcess)
}

main().then(() => {
  process.exit(0)
})