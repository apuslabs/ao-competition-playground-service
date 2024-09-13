import { EMBEDDING_SERVICE } from "./ao/config";
import { dryrun, msgResult } from "./ao/wallet";
import axios from "axios";

axios.defaults.baseURL = EMBEDDING_SERVICE;

const EMBEDDING_PROCESS = "GbCrfjYRxhrVx-UNYPgCOB8-KW_j_6cKfhmKpSoUXFY";

async function getUnembeddedDocuments() {
  const result = await dryrun(EMBEDDING_PROCESS, {
    Action: "Get-Unembeded-Documents",
  });
  const data = result.Messages?.[0]?.Data ?? "[]";
  return JSON.parse(data);
}

interface Docuemnt {
  id: number;
  content: string;
  dataset_hash: string;
  meta: string;
}

function decodeMeta(meta: string) {
  try {
    return JSON.parse(meta);
  } catch (e) {
    // console.error("Failed to decode meta", e);
    return {};
  }
}

async function embedDocuments(docs: Docuemnt[]) {
  // group by dataset_hash
  const groupedDocs = docs.reduce(
    (acc, doc) => {
      (acc[doc.dataset_hash] = acc[doc.dataset_hash] || []).push({
        content: doc.content,
        meta: decodeMeta(doc.meta),
      });
      return acc;
    },
    {} as Record<string, any[]>,
  );
  // group to list
  const list = Object.entries(groupedDocs).map(([dataset_hash, docs]) => ({
    dataset_id: dataset_hash,
    documents: docs,
  }));
  const res = await axios.post("/create-dataset", { list });
  return res.data?.count ?? 0;
}

async function setDocumentsEmbedded(embeddingDocs: Docuemnt[]) {
  // exact ids from embeddingDocs
  const result = await msgResult(
    EMBEDDING_PROCESS,
    { Action: "Embedding-Data" },
    embeddingDocs.map((doc) => doc.id),
  );
  const data = result.Messages?.[0]?.Data ?? 0;
  return data;
}

function executeWithRetry(asyncFunc: () => Promise<void>, intervalMs: number) {
  async function wrapper() {
    try {
      await asyncFunc();
    } catch (e) {
      console.error("An error occurred during execution", e);
    } finally {
      setTimeout(wrapper, intervalMs);
    }
  }
  // Initial call to start the process
  setTimeout(wrapper, intervalMs);
}

async function embeddingDocs() {
  const toEmbeddedDocs = await getUnembeddedDocuments();
  if (toEmbeddedDocs.length) {
    try {
      const embeddingDocs = await embedDocuments(toEmbeddedDocs);
      console.log(`Successfully embedded ${embeddingDocs} documents`);
    } catch (e) {
      console.error("Failed to embed documents", e);
    }
    await setDocumentsEmbedded(toEmbeddedDocs);
  }
}

interface Prompt {
  id: number;
  reference: string;
  sender: string;
  dataset_hash: string;
  prompt_text: string;
  retrieve_result?: string;
}

const PromptPool: Record<string, Prompt> = {};
const ErrorPool: Record<string, Prompt> = {};

async function getToRetrievePrompt() {
  const result = await dryrun(EMBEDDING_PROCESS, {
    Action: "GET-TORETRIEVE-PROMPT",
  });
  const data = result.Messages?.[0]?.Data ?? "[]";
  const prompts = JSON.parse(data);
  prompts.length && console.log(`Retrieved ${prompts.length} prompts`);
  prompts.map((prompt: any) => {
    PromptPool[prompt.reference] = { ...prompt };
  });
}

async function retrievePrompt() {
  const toRetrievePrompts = Object.values(PromptPool).filter(
    (p) => !p.retrieve_result,
  );
  if (!toRetrievePrompts.length) return;
  // only process 1 prompts at a time
  const toRetrievePrompts50 = toRetrievePrompts.slice(0, 1);
  // group by dataset_hash
  const groupedPrompts = toRetrievePrompts50.reduce(
    (acc, doc) => {
      (acc[doc.dataset_hash] = acc[doc.dataset_hash] || []).push({
        prompt: doc.prompt_text,
        reference: doc.reference,
      });
      return acc;
    },
    {} as Record<string, any[]>,
  );
  // group to list
  const list = Object.entries(groupedPrompts).map(([dataset_id, prompts]) => ({
    dataset_id,
    prompts,
  }));
  const res = await axios.post("/retrieve-data", { list });
  console.log(`Successfully retrieved ${res.data?.length ?? 0} prompts`);
  res.data.map(({ reference, result }: any) => {
    const prompt = PromptPool[reference];
    if (prompt) {
      prompt.retrieve_result = result || "Null";
    }
  });
}

async function setPromptRetrieved() {
  const toSetPrompt = Object.values(PromptPool).filter(
    (p) => !!p.retrieve_result,
  );
  if (!toSetPrompt.length) return;
  try {
    await msgResult(
      EMBEDDING_PROCESS,
      { Action: "Set-Retrieve-Result" },
      toSetPrompt,
    );
    console.log(
      `Successfully set retrieve result for ${toSetPrompt.length} prompts`,
    );
    for (const prompt of toSetPrompt) {
      delete PromptPool[prompt.reference];
    }
  } catch {
    for (const prompt of toSetPrompt) {
      ErrorPool[prompt.reference] = prompt;
      delete PromptPool[prompt.reference];
    }
  }
}

function autoRetrievePrompts() {
  setInterval(() => {
    getToRetrievePrompt();
  }, 2000);
  executeWithRetry(async () => {
    await retrievePrompt();
    await setPromptRetrieved();
  }, 100);
}

async function main() {
  executeWithRetry(embeddingDocs, 5000);
  autoRetrievePrompts();
}

main();
