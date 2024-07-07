local json = require("json")

Workers = Workers or {}
PromptRequests = PromptRequests or {}

Handlers.add(
  "Register-Worker",
  Handlers.utils.hasMatchingData("Register-Worker"),
  function(msg)
    -- TODO: add supported models to worker
    Workers[msg.From] = { workload = 0 }
  end
)

Handler.add(
  "Unregister-Worker",
  Handlers.utils.hasMatchingData("Unregister-Worker"),
  function(msg)
    Workers[msg.From] = nil
  end
)

function getWorkerWithLessWorkload()
  local minWorker = nil
  local minWorkload = math.huge
  for worker, workerData in pairs(Workers) do
    if workerData == nil then
      continue
    end
    if workerData.workload < minWorkload then
      minWorker = worker
      minWorkload = workerData.workload
    end
  end
  return minWorker
end

Handlers.add(
  "Inference",
  Handlers.utils.hasMatchingData("Inference"),
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
      ao.Send({
        Target = worker,
        Action = "Inference",
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
  Handlers.utils.hasMatchingData("Inference-Response"),
  function(msg)
    local response = json.decode(msg.Data)
    if PromptRequests[response.dataset] == nil then
      return
    end
    Workers[msg.From].workload = Workers[msg.From].workload - 1
    ao.Send({
      Target = response.dataset,
      Action = "Inference-Response",
      Data = json.encode({
        id = response.id,
        result = response.result,
      })
    })
  end
)