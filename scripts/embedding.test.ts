import { EMBEDDING_PROCESS } from "./config";
import { msgResult } from "./wallet";
import crypto from "crypto"



function createDataset() {
  const testData = [
    { "content": "This contains variable declarations", "meta": {"title": "one"} },
    { "content": "This contains another sort of variable declarations", "meta": {"title": "two"} },
    { "content": "This has nothing to do with variable declarations", "meta": { "title": "three"} },
    { "content": "A random doc", "meta": {"title": "four"} }
  ]

  const hashOfData = crypto.hash('sha1', testData.map(item => item.content).join(''))

  const result = msgResult(EMBEDDING_PROCESS, {
    Action: "Create-Dataset",
  }, {
    hash: hashOfData,
    list: testData
  })
  result.then(response => {
    console.log("Dataset created successfully:", response);
  }).catch(error => {
    console.error("Failed to create dataset:", error);
    throw new Error("Dataset creation failed");
  });
}

function searchPrompt() {
  const result = msgResult(EMBEDDING_PROCESS, {
    Action: "Search-Prompt"
  }, { 
    dataset_hash: "673322f20121f3dc36538578295819386f1ef2b8",
    prompt: "variable declarations"
  })
}

function main() {
  // createDataset();
  searchPrompt();
}

main()