local json = require("json")
local ao = require('ao')

Workers = Workers or {}
PromptRequests = PromptRequests or {}

Handlers.add(
  "Register-Worker",
  Handlers.utils.hasMatchingTag("Action", "Register-Worker"),
  function(msg)
    -- TODO: add supported models to worker
    Workers[msg.From] = { workload = 0 }
  end
)

Handlers.add(
  "Unregister-Worker",
  Handlers.utils.hasMatchingTag("Action", "Unregister-Worker"),
  function(msg)
    Workers[msg.From] = nil
  end
)

function getWorkerWithLessWorkload()
  local minWorker = nil
  local minWorkload = math.huge
  for worker, workerData in pairs(Workers) do
    if workerData == nil then
    else
      if workerData.workload < minWorkload then
        minWorker = worker
        minWorkload = workerData.workload
      end
    end
  end
  return minWorker
end

Handlers.add(
  "Inference",
  Handlers.utils.hasMatchingTag("Action", "Inference"),
  function(msg)
    local response = json.decode(msg.Data)
    local prompts = response.prompts
    local model = response.model
    if PromptRequests[msg.From] == nil then
      PromptRequests[msg.From] = {}
    end
    PromptRequests[msg.From][model] = prompts
    -- deliver all requests to workers with less workload
    for _, prompt in ipairs(prompts) do
      local worker = getWorkerWithLessWorkload()
      ao.send({
        Target = worker,
        Tags = {
          { name = "Action", value = "Inference" }
        },
        Data = json.encode({
          prompt = prompt.prompt,
          model = model,
          id = prompt.id,
          dataset = prompt.dataset,
        })
      })
    end
  end
)

Handlers.add(
  "Inference-Response",
  Handlers.utils.hasMatchingTag("Action", "Inference-Response"),
  function(msg)
    local response = json.decode(msg.Data)
    if PromptRequests[response.dataset] == nil then
      return
    end
    Workers[msg.From].workload = Workers[msg.From].workload - 1
    ao.send({
      Target = response.dataset,
      Tags = {
        { name = "Action", value = "Inference-Response" }
      },
      Data = json.encode({
        id = response.id,
        model = response.model,
        result = response.result,
      })
    })
  end
)