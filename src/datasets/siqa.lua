DataTxID = "-3WsuaNDa8-ke9pYcpq5kKUpPOl4Z6UwY09kQ6KypLk"
LlamaRouter = ""

local weave = require('weave')
local json = require('json')

DataSets = DataSets or {}

ScoreSets = ScoreSets or {}

Handlers.add(
  "Init",
  Handlers.utils.hasMatchingData("Init"),
  function()
    DataSets = weave.getJsonData(DataTxID)
  end
)

Handlers.add(
  "Info",
  Handlers.utils.hasMatchingData("Info"),
  function()
    return {
      name = "Siqa",
      description = "The Siqa dataset is a collection of 10000 questions and answers from the SQuAD dataset.",
      num_samples = #DataSets,
      data_txid = DataTxID,
    }
  end
)

-- benchmark on given model
Handlers.add(
  "Benchmark",
  Handlers.utils.hasMatchingData("Benchmark"),
  function(msg)
    local model = msg.Data
    local scoreSet = ScoreSets[model]
    local prompts = {}
    for _, DataSetItem in ipairs(DataSets) do
      local userPrompt = "Context: " .. DataSetItem.context .. 
      "\nQuestion: " .. 
      DataSetItem.question .. 
      "\nAnswer A: " .. DataSetItem.answerA .. 
      "\nAnswer B: " .. DataSetItem.answerB .. 
      "\nAnswer C: " .. DataSetItem.answerC .. 
      "\nWhich answer is most likely correct? "
      local prompt = [[<|system|>]] .. SystemPrompt .. [[\n<|user|>]] .. prompt .. [[\n<|assistant|>]]
      table.insert(prompts, { prompt = prompt, id = DataSetItem.id })
      scoreSet[DataSetItem.id] = { status = "pending", c_result = DataSetItem.result }
    end
    return ao.Send({
      Target = LlamaRouter,
      Method = "Inference",
      Data = json.encode({
        model = model,
        prompts = prompts,
      })
    })
  end
)

Handlers.add(
  "Data-Info",
  Handlers.utils.hasMatchingData("Data-Info"),
  function(msg)
    local id = msg.Data
    return DataSets[id]
  end
)

Handlers.add(
  "Score-Info",
  Handlers.utils.hasMatchingData("Score-Info"),
  function(msg)
    local response = json.decode(msg.Data)
    local model = response.model
    local id = response.id
    local scoreSet = ScoreSets[model]
    if scoreSet == nil then
      return
    end
    return scoreSet[id]
  end
)

Handlers.add(
  "Benchmark-Response",
  Handlers.utils.hasMatchingData("Benchmark-Result"),
  function(msg)
    local response = json.decode(msg.Data)
    local result = response.result
    local model = response.model
    local id = response.id
    local scoreSet = ScoreSets[model]
    if scoreSet == nil then
      return
    end
    local scoreItem = scoreSet[id]
    if scoreItem == nil then
      return
    end
    scoreItem.result = result
    if scoreItem.c_result == scoreItem.result then
      scoreItem.status = "correct"
    else
      scoreItem.status = "incorrect"
    end
  end
)

-- Statistics Model Benchmark
Handlers.add(
  "Statistics",
  Handlers.utils.hasMatchingData("Statistics"),
  function(msg)
    local model = msg.Data
    local scoreSet = ScoreSets[model]
    if scoreSet == nil then
      return {
        model = model,
        total = 0,
        pending = 0,
        correct = 0,
        incorrect = 0,
      }
    end
    local total = #scoreSet
    local correct = 0
    local incorrect = 0 
    for id, scoreItem in pairs(scoreSet) do
      if scoreItem.status == "correct" then
        correct = correct + 1
      else
        incorrect = incorrect + 1
      end
    end
    return {
      model = model,
      total = total,
      pending = total - correct - incorrect,
      correct = correct,
      incorrect = incorrect,
    }
  end
)