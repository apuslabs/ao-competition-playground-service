import { OLLAMA_PROCESS, OLLAMA_SERVICE } from './ao/config';
import { dryrun, msgResult } from './ao/wallet';
import axios from 'axios';
import { FlatCache } from 'flat-cache';
import winston from 'winston'

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.simple(),
    transports: [
      //
      // - Write all logs with importance level of `error` or higher to `error.log`
      //   (i.e., error, fatal, but not other levels)
      //
      new winston.transports.File({ filename: 'logs/error.log', level: 'warn' }),
      //
      // - Write all logs with importance level of `info` or higher to `combined.log`
      //   (i.e., fatal, error, warn, and info, but not trace)
      //
      new winston.transports.File({ filename: 'logs/combined.log' }),
    ],
  });

const cache = new FlatCache({
    persistInterval: 5 * 1000 * 60, // 5 minutes
    cacheId: 'ollama',
});

const EvaluateSystemPrompt1 = `You are a robot evaluating dataset quality. You'll be given an Input JSON.
Input JSON format:
\`\`\`json
{"question": "...","context": "<Content about question>"}
\`\`\`
  - "context" may contain multiple lines or be null.

Then Follow these steps:
1. Understand the topic based on "context" field and "question" field in input json.
2. Formulate your answer to the "question" based on "context" field in input json.
  - In a single sentence, no line breaks, MAX 40 words.
  - All your knowledge MUST come from the "context" field in input json
  - DON'T use existing knowledge, DON'T invent facts.
`

const EvaluateSystemPrompt2 = `You are a robot evaluating dataset quality. You'll be given an Input JSON.
Input JSON format:
\`\`\`json
{"response": "...","expected_response": "..."} 
\`\`\`

Compare your answer with the "expected_response" field in input json. Score semantic similarity from integer between 0 and 10 (0 = no similarity, 10 = almost identical).

Output: Only return the integer score.
Example: 7`

const ChatSystemPrompt = `You are Satoshi Nakamoto, answer question based on the context.

Input JSON format:
\`\`\`json
{"question": "...","context": "<QA of AO>"}
\`\`\`
  - "context" may contain multiple lines or be null.

Output:
1. Plain text, MAX 40 words, no line breaks.
2. Answer concisely in one sentence, no line breaks, stop when complete.
2. If context is null, use existing knowledg, but don't invent facts.`

interface Task {
    idx: number;
    workerType: "Evaluate" | "Chat";
    prompt: string;
}

async function getTaskFromHerder(): Promise<Task | undefined> {
  try {
    const result = await dryrun(OLLAMA_PROCESS, {
      Action: 'Get-Inference',
    });
    if (!result.Messages?.length) {
        return;
    }
    const data = result.Messages?.[0]?.Data;
    return JSON.parse(data);
  } catch (e) {
    logger.error('Failed to retrieve task' + JSON.stringify(e));
  }
}

async function setResult(task: Task, response: string) {
  try {
    const result = await msgResult(OLLAMA_PROCESS, {
      Action: 'Inference-Response',
    }, {
        idx: task.idx,
        response,
    });
    return result;
  } catch (e) {
    logger.error('Failed to send task' + JSON.stringify(e));
  }
}

async function evaluate(task: Task): Promise<string | undefined> {
    try {
        const prompt = JSON.parse(task.prompt);
        const options = {
            model: 'phi3:medium',
            system: EvaluateSystemPrompt1,
            prompt: JSON.stringify({
                question: prompt.question,
                context: prompt.context,
            }),
            stream: false,
            options: {
                seed: 1234,
                temperature: 0
            }
        }
        const result = await axios.post(`${OLLAMA_SERVICE}/api/generate`, options)
        const options2 = {
            model: 'phi3:medium',
            system: EvaluateSystemPrompt2,
            prompt: JSON.stringify({
                response: result.data.response,
                expected_response: prompt.expected_response,
            }),
            stream: false,
            options: {
                seed: 1234,
                temperature: 0
            }
        }
        const result2 = await axios.post(`${OLLAMA_SERVICE}/api/generate`, options2)
        let score = Number.parseInt(result2.data.response)
        if (Number.isNaN(score) || score < 0 || score > 10) {
            logger.warn(`Invalid score for task ${task.idx}: ${result2.data.response}`);
            score = 0;
        }
        cache.setKey(task.idx.toString(), {
            response: result.data.response,
            score
        });
        logger.info(`Evaluated task ${task.idx} with score ${score}`);
        return score.toString();
    } catch (e) {
        logger.error('Failed to perform inference' + JSON.stringify(e));
    }
}

async function chat(task: Task): Promise<string | undefined> {
    try {
        const prompt = JSON.parse(task.prompt);
        const options = {
            model: 'phi3:medium',
            system: ChatSystemPrompt,
            prompt: JSON.stringify({
                question: prompt.question,
                context: prompt.context,
            }),
            stream: false,
            options: {
                seed: 1234,
                temperature: 0
            }
        }
        const result = await axios.post(`${OLLAMA_SERVICE}/api/generate`, options)
        logger.info(`Chat task ${task.idx} with response ${result.data.response}`);
        cache.setKey(task.idx.toString(), {
            response: result.data.response,
        });
        return result.data.response;
    } catch (e) {
        logger.error('Failed to perform inference'+ JSON.stringify(e));
    }
}

function executeWithRetry(asyncFunc: () => Promise<void>, intervalMs: number) {
    async function wrapper() {
        try {
            await asyncFunc();
        } catch (e) {
            logger.error('An error occurred during execution' + JSON.stringify(e));
        } finally {
            setTimeout(wrapper, intervalMs);
        }
    }
    // Initial call to start the process
    setTimeout(wrapper, intervalMs);
}

function autoInference() {
    async function wrapper() {
        const task = await getTaskFromHerder();
        if (task) {
            let response;
            if (task.workerType === "Evaluate") {
                response = await evaluate(task);
            } else {
                response = await chat(task);
            }
            if (response) {
                await setResult(task, response);
            }
        }
    }
    executeWithRetry(wrapper, 1000);
}

autoInference();