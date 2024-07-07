local json = require("json")

Llama = require('llama')
Llama.logLevel = 4
DefaultModel = "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
DefaultMaxTokens = 1
DefaultSystemPrompt = "You are performing an benchmark testing. Choose RIGHT answer for the question based on the context. [Important] Only answer with the letter of the correct answer. If you are not sure, answer with 'N'"

Handlers.add(
  "loadModel",
  Handlers.utils.hasMatchingData("setModel"),
  function(msg)
    Llama.load(msg.Data or DefaultModel)
  end
)

-- set Max Token
Handlers.add(
  "setMaxTokens",
  Handlers.utils.hasMatchingData("setMaxTokens"),
  function(msg)
    MaxTokens = msg.Data or DefaultMaxTokens
  end
)

-- set system prompt
Handlers.add(
  "setSystemPrompt",
  Handlers.utils.hasMatchingData("setSystemPrompt"),
  function(msg)
    SystemPrompt = msg.Data or DefaultSystemPrompt
  end
)

-- Inference
Handlers.add(
  "Inference",
  Handlers.utils.hasMatchingData("Inference"),
  function(msg)
    local response = json.deocde(msg.Data)
    local prompt = response.prompt
    local model = response.model
    local id = response.id
    local dataset = response.dataset
    -- TODO: check if the model is loaded
    ao.Send({
      Target = msg.From,
      Action = "Inference-Response",
      Data = json.encode({
        id = id,
        dataset = dataset,
        result = infer(prompt),
      }),
    })
  end
)

function infer(prompt)
  Llama.setPrompt(prompt)
  local response = ""
  local tokens = 0
  while true do
    local token = Llama.next()
    tokens = tokens + 1
    if token == nil or tokens > MaxTokens then
      break
    else
      response = response .. token
    end
  end
  return response
end