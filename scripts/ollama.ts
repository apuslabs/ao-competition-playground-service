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

const EvaluateSystemPrompt1 = `# Role

You are a robot evaluating whether the context contains sufficient information to derive the expected_response for the given question.

# Instructions

Follow these steps carefully:
1.	Analyze the Context
    -   Carefully read the "context" provided.
    -   **Only** use information from the "context".
    -   **Do not** use any external knowledge or make assumptions.
2.	Assess Sufficiency
    -   Determine if the "context" provides enough information to answer the "question" with the "expected_response".
    -   **Focus on** whether the core content of the "expected_response" is present in the "context".
3.	Assign a Score
    -   If the "context" fully supports deriving the "expected_response", assign a score between 8 and 10.
    -   If the "context" partially supports deriving the "expected_response", assign a score between 4 and 7.
    -   If the "context" does not support deriving the "expected_response", assign a score between 0 and 3.
    -   Within each score range, higher relevance and completeness lead to a higher score.
4.	Provide the Final Score
    -   **Only** output the final score.
    -   **Do not** include any explanations or additional text.

# Input Format

\`\`\`json
{"question": "...", "context": "...", "expected_response": "..."}
\`\`\`

# Output Format

7`;

const ChatSystemPrompt = `You are Satoshi Nakamoto, answer question based on the context.

Input JSON format:
\`\`\`json
{"question": "...","context": "<QA of AO>"}
\`\`\`
  - "context" may contain multiple lines or be null.

Output:
1. Plain text, MAX 40 words, no line breaks.
2. Answer concisely in one sentence, no line breaks, stop when complete.
2. If context is null, use existing knowledg, but don't invent facts.`;

interface Task {
  idx: number;
  workerType: 'Evaluate' | 'Chat';
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
    const result = await msgResult(
      OLLAMA_PROCESS,
      {
        Action: 'Inference-Response',
      },
      {
        idx: task.idx,
        response,
      }
    );
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
        expected_response: prompt.expected_response,
      }),
      stream: false,
      options: {
        seed: 1234,
        temperature: 0,
      },
    };
    const result = await axios.post(`${OLLAMA_SERVICE}/api/generate`, options);
    // const options2 = {
    //     model: 'phi3:medium',
    //     system: EvaluateSystemPrompt2,
    //     prompt: JSON.stringify({
    //         response: result.data.response,
    //         expected_response: prompt.expected_response,
    //     }),
    //     stream: false,
    //     options: {
    //         seed: 1234,
    //         temperature: 0
    //     }
    // }
    // const result2 = await axios.post(`${OLLAMA_SERVICE}/api/generate`, options2)
    let score = Number.parseInt(result.data.response);
    if (Number.isNaN(score) || score < 0 || score > 10) {
      logger.warn(`Invalid score for task ${task.idx}: ${result.data.response}`);
      score = 0;
    }
    cache.setKey(task.idx.toString(), {
      response: result.data.response,
      score,
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