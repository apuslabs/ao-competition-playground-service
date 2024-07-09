local json = require("json")
local ao = require('ao')

Llama = require('llama')
Llama.logLevel = 4
DefaultModel = "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
DefaultMaxTokens = 1
DefaultSystemPrompt = "You are performing an benchmark testing. Choose RIGHT answer for the question based on the context. [Important] Only answer with the letter of the correct answer. If you are not sure, answer with 'N'"
DEBUG = false

Handlers.add(
  "loadModel",
  Handlers.utils.hasMatchingTag("Action", "setModel"),
  function(msg)
    Llama.load(msg.Data or DefaultModel)
  end
)

-- set Max Token
Handlers.add(
  "setMaxTokens",
  Handlers.utils.hasMatchingTag("Action", "setMaxTokens"),
  function(msg)
    MaxTokens = msg.Data or DefaultMaxTokens
  end
)

-- set system prompt
Handlers.add(
  "setSystemPrompt",
  Handlers.utils.hasMatchingTag("Action", "setSystemPrompt"),
  function(msg)
    SystemPrompt = msg.Data or DefaultSystemPrompt
  end
)

-- Inference
Handlers.add(
  "Inference",
  Handlers.utils.hasMatchingTag("Action", "Inference"),
  function(msg)
    local response = json.deocde(msg.Data)
    local prompt = response.prompt
    local model = response.model
    local id = response.id
    local dataset = response.dataset
    -- TODO: check if the model is loaded
    ao.send({
      Target = msg.From,
      Tags = {
        { name = "Action", value = "Inference-Response" }
      },
      Data = json.encode({
        id = id,
        model = model,
        dataset = dataset,
        result = infer(prompt),
      }),
    })
  end
)

function infer(prompt)
  if DEBUG then
    return "A"
  end
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