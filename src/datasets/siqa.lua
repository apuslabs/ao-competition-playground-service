DataTxID = DataTxID or "-3WsuaNDa8-ke9pYcpq5kKUpPOl4Z6UwY09kQ6KypLk"
LlamaRouter = LlamaRouter or "glGRJ4CqL-mL29RN8udCTro2-7svs7hfqH9Vf4WXAn4"
BenchmarkProcess = BenchmarkProcess or "1mkMVtnJDAGGCjke6Cx1juspsGJ3YRO-twntzBTYqvs"

weave = require('weave')
json = require('json')
local ao = require('ao')

DataSets = DataSets or {}

ScoreSets = ScoreSets or {}

Handlers.add(
  "Init",
  Handlers.utils.hasMatchingTag("Action", "Init"),
  function()
    DataSets = weave.getJsonData(DataTxID)
    print("Init")
  end
)

Handlers.add(
  "Info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
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
  Handlers.utils.hasMatchingTag("Action", "Benchmark"),
  function(msg)
    local model = msg.Data
    local scoreSet = ScoreSets[model]
    if scoreSet == nil then
      scoreSet = {}
      ScoreSets[model] = scoreSet
    end
    local prompts = {}
    for _, DataSetItem in ipairs(DataSets) do
      local userPrompt = "Context: " .. DataSetItem.context .. 
      "\nQuestion: " .. 
      DataSetItem.question .. 
      "\nAnswer A: " .. DataSetItem.answerA .. 
      "\nAnswer B: " .. DataSetItem.answerB .. 
      "\nAnswer C: " .. DataSetItem.answerC .. 
      "\nWhich answer is most likely correct? "
      local prompt = [[<|system|>]] .. SystemPrompt .. [[\n<|user|>]] .. userPrompt .. [[\n<|assistant|>]]
      table.insert(prompts, { prompt = prompt, id = DataSetItem.id })
      scoreSet[DataSetItem.id] = { status = "pending", c_result = DataSetItem.result }
    end
    return ao.send({
      Target = LlamaRouter,
      Tags = {
        { name = "Action", value = "Inference" }
      },
      Data = json.encode({
        model = model,
        prompts = prompts,
      })
    })
  end
)

Handlers.add(
  "Data-Info",
  Handlers.utils.hasMatchingTag("Action", "Data-Info"),
  function(msg)
    local id = msg.Data
    return DataSets[id]
  end
)

Handlers.add(
  "Score-Info",
  Handlers.utils.hasMatchingTag("Action", "Score-Info"),
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
  "Inference-Response",
  Handlers.utils.hasMatchingTag("Action", "Inference-Response"),
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
    if isComplete(model) then
      ao.send({
        Target = BenchmarkProcess,
        Tags = {
          { name = "Action", value = "Benchmark-Response" }
        },
        Data = json.endcode({
          model = model,
          score = score(model),
        })
      })
    end
  end
)

function isComplete(model)
  local scoreSet = ScoreSets[model]
  for _, scoreItem in pairs(scoreSet) do
    if scoreItem.status == "pending" then
      return false
    end
  end
  return true
end

function score(model)
  local scoreSet = ScoreSets[model]
  if scoreSet == nil then
    return -1
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
  return correct / total
end

Handlers.add(
  "Statistics",
  Handlers.utils.hasMatchingTag("Action", "Statistics"),
  function(msg)
    local model = msg.Data
    return statistics(model)
  end
)