local sqlite3 = require("lsqlite3")
local json = require('json')
Llama = require("@sam/Llama-Herder")

DB = DB or nil
DataTxID = DataTxID or "-3WsuaNDa8-ke9pYcpq5kKUpPOl4Z6UwY09kQ6KypLk"
LlamaRouter = LlamaRouter or "glGRJ4CqL-mL29RN8udCTro2-7svs7hfqH9Vf4WXAn4"
WrappedAR = WrappedAR or "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10"
-- BenchmarkProcess = BenchmarkProcess or "1mkMVtnJDAGGCjke6Cx1juspsGJ3YRO-twntzBTYqvs"
SystemPrompt = SystemPrompt or [[You are a helpful assistant that can answer questions about the SQuAD dataset. 
Choose the correct answer for question based on the context. If you are not sure, answer N.
**Important**You must only answer with A, B, C, or N.
]]

Handlers.add(
  "Init",
  Handlers.utils.hasMatchingTag("Action", "Init"),
  function()
    -- DataSets = weave.getJsonData(DataTxID)
    DB = sqlite3.open_memory()
  
    DB:exec[[
      CREATE TABLE datasets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          context TEXT NOT NULL,
          question TEXT NOT NULL,
          answerA TEXT NOT NULL,
          answerB TEXT NOT NULL,
          answerC TEXT NOT NULL,
          result TEXT NOT NULL
      );

      CREATE TABLE models (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          inference_process TEXT NOT NULL,
          data_tx TEXT NOT NULL
      );

      CREATE TABLE evaluations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dataset_id INTEGER NOT NULL,
          model_id INTEGER NOT NULL,
          prompt TEXT NOT NULL,
          correct_answer TEXT NOT NULL,
          prediction TEXT,
          inference_start_time DATETIME,
          inference_end_time DATETIME,
          inference_reference TEXT,
          UNIQUE(dataset_id, model_id),
          FOREIGN KEY (dataset_id) REFERENCES datasets(id)
      );
      INSERT INTO models (name, inference_process, data_tx) VALUES
        ('Phi-3 Mini 4k Instruct', 'wh5vB2IbqmIBUqgodOaTvByNFDPr73gbUq1bVOUtCrw', 'ISrbGzQot05rs_HKC08O_SmkipYQnqB1yC3mjZZeEo'),
        ('Model B', 'Process B', 'Data TX B');
    ]]
    
    return "ok"
  end
)

local SQL = {
  INSERT_DATASET = [[
    INSERT INTO datasets (context, question, answerA, answerB, answerC, result) VALUES ('%s', '%s', '%s', '%s', '%s', '%s');
  ]],
  COUNT_DATASETS = [[
    SELECT COUNT(id) as count FROM datasets;
  ]],
  GET_ALL_DATASETS = [[
    SELECT * FROM datasets;
  ]],
  GET_ALL_MODELS = [[
    SELECT * FROM models;
  ]],
  GET_UNEVALUATED_EVALUATIONS = [[
    SELECT * FROM evaluations WHERE inference_start_time IS NULL AND model_id = '%s' LIMIT %d;
  ]],
  CREATE_EVALUATION = [[
    INSERT INTO evaluations (dataset_id, model_id, prompt, correct_answer) VALUES ('%s', '%s', '%s', '%s') ON CONFLICT(dataset_id, model_id) DO NOTHING;
  ]],
  START_EVALUATION = [[
    UPDATE evaluations SET inference_start_time = CURRENT_TIMESTAMP, inference_reference = '%s' WHERE id = '%s';
  ]],
  END_EVALUATION = [[
    UPDATE evaluations SET inference_end_time = CURRENT_TIMESTAMP, prediction = '%s' WHERE inference_reference = '%s';
  ]],
  CORRECT_COUNT = [[
    SELECT COUNT(*) as count FROM evaluations WHERE model_id = '%s' AND correct_answer = prediction;
  ]],
  UNEVALUATED_COUNT = [[
    SELECT COUNT(*) as count FROM evaluations WHERE inference_start_time IS NULL AND model_id = '%s';
  ]],
}

Handlers.add(
  "Load-Data",
  Handlers.utils.hasMatchingTag("Action", "Load-Data"),
  function(msg)
    local data = msg.Data
    assert(data ~= nil, "Data is nil")
    local DataSets = json.decode(data)
    for _, DataSetItem in ipairs(DataSets) do
      local query = string.format(
        SQL.INSERT_DATASET,
        DataSetItem.context,
        DataSetItem.question,
        DataSetItem.answerA,
        DataSetItem.answerB,
        DataSetItem.answerC,
        DataSetItem.result
      )
      DB:exec(query)
    end
    print('ok')
  end
)

function getDataSetCount()
  for row in DB:nrows(SQL.COUNT_DATASETS) do
    return tonumber(row.count)
  end
end

Handlers.add(
  "Info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function()
    local count = getDataSetCount()
    return {
      name = "Siqa",
      description = "The Siqa dataset is a collection of questions and answers from the SQuAD dataset.",
      num_samples = count,
      data_txid = DataTxID,
    }
  end
)

Handlers.add(
  "Get-Models",
  Handlers.utils.hasMatchingTag("Action", "Get-Models"),
  function()
    for row in DB:nrows(SQL.GET_ALL_MODELS) do
      print(row.id .. ": " .. row.name .. " " .. row.inference_process .. " " .. row.data_tx)
    end
    print('ok')
  end
)

-- benchmark on given model
Handlers.add(
  "Benchmark",
  Handlers.utils.hasMatchingTag("Action", "Benchmark"),
  function(msg)
    local model = msg.Data
    -- TODO: check if model exists, register model
    for row in DB:nrows(SQL.GET_ALL_DATASETS) do
      local userPrompt = "Context: " .. row.context .. 
      "\nQuestion: " .. 
      row.question .. 
      "\nAnswerA: " .. row.answerA .. 
      "\nAnswerB: " .. row.answerB .. 
      "\nAnswerC: " .. row.answerC
      local prompt = [[<|system|>]] .. SystemPrompt .. [[<|user|>]] .. userPrompt .. [[<|assistant|>]]
      DB:exec(string.format(
        SQL.CREATE_EVALUATION,
        row.id, model, prompt, row.result
      ))
    end
    print('ok')
  end
)


-- A:1 B:2 ...
local function ResultRetriever(answer)
  if answer:find("A") then
    return "1"
  elseif answer:find("B") then
    return "2"
  elseif answer:find("C") then
    return "3"
  end
  return "0"
end

Handlers.add(
  "Evaluate",
  Handlers.utils.hasMatchingTag("Action", "Evaluate"),
  function(msg)
    local model = msg.Tags.Model
    local limit = tonumber(msg.Data) or 1
    for row in DB:nrows(string.format(SQL.GET_UNEVALUATED_EVALUATIONS, model, limit)) do
      local reference = Llama.Reference
      print("Inference: " .. row.prompt .. "\n")
      -- TODO: support switch models
      Llama.run(row.prompt, 1, function (answer)
        print("Answer: " .. answer .. "\n")
        DB:exec(string.format(
          SQL.END_EVALUATION,
          ResultRetriever(answer), reference
        ))
      end)
      DB:exec(string.format(
        SQL.START_EVALUATION,
        reference, row.id
      ))
    end
    print('ok')
  end
)

function GetCorrectCount(model)
  for row in DB:nrows(string.format(SQL.CORRECT_COUNT, model)) do
    return tonumber(row.count)
  end
  return 0
end

function GetUnevaluatedCount(model)
  for row in DB:nrows(string.format(SQL.UNEVALUATED_COUNT, model)) do
    return tonumber(row.count)
  end
  return 0
end

local function ScoreCalculator(correct, total)
  if total == 0 then
    return 0
  end
  return correct / total
end

Handlers.add(
  "Score",
  Handlers.utils.hasMatchingTag("Action", "Score"),
  function(msg)
    local model = msg.Data
    local correct = GetCorrectCount(model)
    local unevaluated = GetUnevaluatedCount(model)
    local total = getDataSetCount()
    ao.send({
      Target = msg.From,
      Tags = {
        Action = "Score-Response",
        Model = model,
      },
      Data = json.encode({
        correct = correct,
        unevaluated = unevaluated,
        total = total,
        score = ScoreCalculator(correct, total - unevaluated),
        progress = (total - unevaluated) / total,
      })
    })
  end
)

Handlers.add(
  "LlamaHerder.Transfer-Error",
  function (msg)
    return msg.From == WrappedAR and
      msg.Tags.Action == "Transfer-Error"
  end,
  function(msg)
    print("Transfer-Error: " .. msg.Tags["Message-Id"] .. "\n")
    -- TODO: revert inference status
  end
)