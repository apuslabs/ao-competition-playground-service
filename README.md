# Benchmark POC: Model Benchmark on AO

The benchmark POC is a proof of concept that aims to benchmark LLM models on AO.
Funders can setup a funding pool with a set of questions and get a leaderboard of the models that are able to answer the questions.
Everyone can train their own model and compete against the other models.
The leaderboard is updated everyday with the latest scores.
After the funding pool is over, the leaderboard is used to determine the winners and rewards are distributed.

# Getting Started

## Prerequesites

- [Node.js](https://nodejs.org/en) (v20.0 or later)
- [AOS installed](https://cookbook_ao.arweave.dev/welcome/getting-started.html)

## Sending Message

### Pool Creation

Funders can create a funding pool by transfer [wrappedAR](https://aox.xyz/#/beta) with the following payload:

```js
ao.send({
   Target = 'xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10',
   Action = 'Transfer',
   Recipient = 'DLJoP8Xtdat6SKz3kqYGZPaa7DJBG6etF1jRLQCwquo',
   Quantity = Fee,
   ['X-Dataset'] = <your dataset process id>,
   ['X-Allocation'] = 'ArithmeticDecrease'
})
```

### Prepare Model for Benchmark

Ardrive -> Data Tx Id

- Opensource Models
  - Phi-3 Mini 4k Instruct: ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo
  - Phi-2: kd34P4974oqZf2Db-hFTUiCipsU6CzbR6t-iJoQhKIo
  - GPT-2 117M: XOJ8FBxa6sGLwChnxhF2L71WkKLSKq1aU5Yn5WnFLrY
  - GPT-2-XL 4-bit quantized model: M-OzkyjxWhSvWYF87p0kvmkuAEEkvOzIj4nMNoSIydc
  - CodeQwen 1.5 7B Chat q3: sKqjvBbhqKvgzZT4ojP1FNvt4r_30cqjuIIQIr-3088
  - Llama3 8B Instruct q4: Pr2YVrxd7VwNdg6ekC0NXWNKXxJbfTlHhhlrKbAd1dA
  - Llama3 8B Instruct q8: jbx-H6aq7b3BbNCHlK50Jz9L-6pz9qmldrYXMwjqQVI
- Fine-tuned Models
  -

### Model Evaluation

Trainer can join a pool by sending a message to the pool process with the following payload:

```js
ao.send({
   Target = 'DLJoP8Xtdat6SKz3kqYGZPaa7DJBG6etF1jRLQCwquo',
   Action = 'Join-Pool',
   Data = '{"dataset": <the pool id you want to join>, "model": <your model id>}'
})
```

Once you join a pool, the model will start evaluating the dataset and sending back the score to the pool process.

### Get leaderboard

Trainer can get the leaderboard result by sending a message to the pool process with the following payload:

_Leaderboard updated every 24 hours_

```js
ao.send({
   Target = 'DLJoP8Xtdat6SKz3kqYGZPaa7DJBG6etF1jRLQCwquo',
   Action = 'Leaderboard',
   Data = <pool id>
})
```

# Running a benchmark

## Architecture

### Benchmark

The Benchmark is reponsible for managing pool, funding, and rewards.

**Key Data Structure:**

- Benchmarks: A table that holds all the benchmark pools. Each pool contains:
  - funder: The address of the funder.
  - funds: The amount of funds in the pool.
  - allocation: The allocation rule for the pool.
  - startTime: The start time of the pool.
  - endTime: The end time of the pool.
  - models: A table of models participating in the pool. Each model contains:
    - participant: The address of the participant.
    - score: The score of the model.
    - progress: The progress of the model.

**Key Functions:**

- Allocation: calculate allocation for each rule.

**Handlers:**

- Create-Pool: Handles the creation of a new funding pool.
- Join-Pool: Handles the joining of a model to an existing pool.
- Get-Pools: Retrieves the list of all existing pools.
- Update-Leaderboard: Updates the leaderboard with the latest scores.
- Allocate-Rewards: Allocates rewards to participants based on their scores.
- Score-Response: Handles the response for the score action.
- Leaderboard: Retrieves and prints the current leaderboard.

**Cron:**

- Update-Leaderboard: Updates the leaderboard every 24 hours.
- Allocate-Rewards: Check if the pool is over and allocate rewards to participants every 24 hours.

### Siqa Dataset

The Siqa Dataset is an example dataset that is used to benchmark the LLM models.

**Initialization:**

- DataTxID: Transaction Data ID for the dataset
- LlamaRouter: Router for Llama
- WrappedAR: Wrapped AR token address
- SystemPrompt: System prompt for the assistant

**Table Definition:**

- datasets: Stores the context, question, and possible answers (A, B, C) along with the correct result.

  - id: INTEGER PRIMARY KEY AUTOINCREMENT
  - context: TEXT NOT NULL
  - question: TEXT NOT NULL
  - answerA: TEXT NOT NULL
  - answerB: TEXT NOT NULL
  - answerC: TEXT NOT NULL
  - result: TEXT NOT NULL

- models: Stores the model information.

  - id: INTEGER PRIMARY KEY AUTOINCREMENT
  - name: TEXT NOT NULL
  - inference_process: TEXT NOT NULL
  - data_tx: TEXT NOT NULL

- evaluations: Stores the evaluation results of models on datasets.
  - id: INTEGER PRIMARY KEY AUTOINCREMENT
  - dataset_id: INTEGER NOT NULL
  - model_id: INTEGER NOT NULL
  - prompt: TEXT NOT NULL
  - correct_answer: TEXT NOT NULL
  - prediction: TEXT
  - inference_start_time: DATETIME
  - inference_end_time: DATETIME
  - inference_reference: TEXT
  - UNIQUE(dataset_id, model_id)
  - FOREIGN KEY (dataset_id) REFERENCES datasets(id)

**Key Functions:**

- ResultRetriever: Converts answer letters (A, B, C) to corresponding numerical values.

**Handlers:**

- Init: Initializes the SQLite database and creates necessary tables.
- Load-Data: Loads dataset into the database from a given message.
- Info: Provides information about the Siqa dataset.
- Get-Models: Retrieves and prints all models from the database.
- Benchmark: Benchmarks a given model using the dataset.
- Evaluate: Evaluates the model's predictions against the dataset.
- Score: Calculates and sends the score of a model.
- LlamaHerder.Transfer-Error: Handles transfer errors from LlamaHerder.

**Cron:**

- Evaluate: Evaluates the model's predictions against the dataset every 1 hours. Each time up to 1000 inferences are made.

### Llama Router & Llama Worker

Llama Router and Llama Worker is where inference actually happens.

Handlers:

- Register-Worker: Registers a worker and initializes its workload.
- Unregister-Worker: Unregisters a worker and removes it from the list.
- Inference: Handles inference requests by distributing them to workers with the least workload.
- Inference-Response: Handles responses from workers and sends the results back to the requester.
- loadModel: Loads a specified model for inference.
- setMaxTokens: Sets the maximum number of tokens for inference.
- setSystemPrompt: Sets the system prompt for the inference process.
- Inference: Performs inference using the loaded model and sends the result back to the requester.

## Build a dataset

A dataset is currently a collection of questions that are sent to the LLM models.

You have to install [@sam/Llama-Herder](https://github.com/permaweb/llama-herder) to be able to run a benchmark.

```shell
aos> .load-blueprint apm
Loading...  apm
📦 Loaded APM Client
aos> APM.install("@sam/Llama-Herder")
📤 Download request sent
ℹ️ Attempting to load @sam/Llama-Herder@1.0.3 package
📦 Package has been loaded, you can now import it using require function
```

Then, load the dataset process

```shell
.load src/datasets/siqa.lua
```

Then, Initialize the table

```shell
aos> Send({
   Target = '<dataset process id>',
   Action = 'Init'
})
```

Then, load the dataset into the table

```shell
aos> Send({
   Target = '<dataset process id>',
   Action = 'Load-Data',
   Data = '<path to your dataset>'
})
```

### Build your own Dataset

a Dataset should contains

- Info: Describe the dataset
- Dataset Loader: we use message to pass in siqa
- Prompt Template
- Result Retriever
- Score Calculator
- Evaluater: we use llama-herder here

## Evaluate

You can use [LlamaHerder](https://github.com/permaweb/llama-herder) to evaluate the model's performance.

or

You can setup your [local CU](https://github.com/permaweb/ao/tree/main/servers/cu) using `llama-router.lua` in `src`

Make sure you have a CU running and setup the correct envs. such as `checkAdmissions` in [weaveDriver](https://github.com/permaweb/aos/tree/main/extensions/weavedrive).

Finally, you can use `aos --cu-url=http://ip:6363` to start the llama-worker.

Make sure you use your own `authority` Tags of the process and forward the message using [aoconnect](https://github.com/permaweb/ao/tree/main/connect)

## Useful Resources

### Links

- [LlamaHerder](https://github.com/permaweb/llama-herder)
- [WeaveDriver](https://github.com/permaweb/aos/tree/main/extensions/weavedrive)
- [AO Connect](https://github.com/permaweb/ao/tree/main/connect)

### Scirpts

- [scripts/wrappedAR.ts](scripts/wrappedAR.ts) : A script to send wrappedAR to the pool/dataset process
- [scripts/spawn.ts](scripts/spawn.ts) : A script to spawn all processes to setup the benchmark
- [scripts/siqa.ts](scripts/siqa.ts) : A script to load the siqa data into the dataset process

### Process ID

- Benchmark: `DLJoP8Xtdat6SKz3kqYGZPaa7DJBG6etF1jRLQCwquo`
- Siqa: `XUw5NtwUzk7hf_dE4ifEFD2rHfXffMLb8s2QfnZEvg4`
- WrappedAR: `xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10`

# Contributing

We welcome contributions! If you find a bug or have suggestions, please open an issue. If you'd like to contribute code, please fork the repository and submit a pull request.

# Llama-Herder

## Evaluate

```lua
Send({
   Target = "jaSRY9nVTdUE48QMg9SMuKbW8T9yk8Vi1FNZpau9M2A",
   Tags = {
      Action = "Inference",
      WorkerType = "Evaluate",
      Reference = "<Reference>",
   },
   Data = json.encode({question = "xxx", expected_response = "xxx", context = "xxx"}),
})
```

### Response

```lua
Send({
   Target = msg.From,
   Tags = {
      Action = "Inference-Response",
      WorkerType = "Evaluate",
      Reference = "<User Reference>",
   },
   Data = "<score:0-10>"
})
```

## Chat

```lua
Send({
   Target = "jaSRY9nVTdUE48QMg9SMuKbW8T9yk8Vi1FNZpau9M2A",
   Tags = {
      Action = "Inference",
      WorkerType = "Chat",
      Reference = "<Reference>",
   },
   Data = json.encode({question = "xxx", context = "xxx"}),
})
```

### Response

```lua
Send({
   Target = msg.From,
   Tags = {
      Action = "Inference-Response",
      WorkerType = "Chat",
      Reference = "<User Reference>",
   },
   Data = "<answer:max 40 tokens>"
})
```

# Embedding Service

aos text-embedding-service --module=ghSkge2sIUD_F00ym5sEimC63BDBuBrq4b5OcwxOjiw

## How to use

Create-Dataset

```
Send({ Target = 'hMEUOgWi97d9rGT-lHNCbm937bTypMq7qxMWeaUnMLo', Action = "Create-Dataset", Data='{"hash":"673322f20121f3dc36538578295819386f1ef2b8","list":[{"content":"This contains variable declarations","meta":{"title":"one"}},{"content":"This contains another sort of variable declarations","meta":{"title":"two"}},{"content":"This has nothing to do with variable declarations","meta":{"title":"three"}},{"content":"A random doc","meta":{"title":"four"}}]}' })
```

Search-Prompt

```
Send({ Target = 'hMEUOgWi97d9rGT-lHNCbm937bTypMq7qxMWeaUnMLo', Action = "Search-Prompt", Data = '{"dataset_hash": "673322f20121f3dc36538578295819386f1ef2b8","prompt":"variable declarations"}' })
```

## Process ID

hMEUOgWi97d9rGT-lHNCbm937bTypMq7qxMWeaUnMLo
