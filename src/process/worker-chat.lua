-- Module: XcWULRSWWv_bmaEyx4PEOFf4vgRSVCP9vM5AucRvI40
local Config = require("module.utils.config")
local Log = require("module.utils.log")
local Helper = require("module.utils.helper")
local json = require("json")

Llama = Llama or nil
InferenceAllowList = {
    [Config.Process.LlamaHerder] = true,
    [ao.id] = true
}

DefaultMaxResponse = DefaultMaxResponse or 40
SystemPrompt = [[
You are Walter White, answer question based on the context.

Input JSON format:
```json
{"question": "...","context": "<QA of AO>"}
```
  - "context" may contain multiple lines or be null.

Output:
1. Plain text, MAX 25 words, ]] .. DefaultMaxResponse .. [[ tokens.
2. Answer concisely in one sentence, no line breaks, stop when complete.
2. If context is null, use existing knowledg, but don't invent facts.
]]


function PrimePromptText(systemPrompt)
    return [[<|system|>
]] .. systemPrompt .. [[<|end|>
<|user|>
]]
end

function Init()
    Llama = require("llama")
    Llama.logLevel = 4
    Llama.load("/data/" .. Config.Llama.DefaultModel)

    local initialPrompt = PrimePromptText(SystemPrompt)
    Log.info("Initial Prompt: " .. initialPrompt)
    Llama.setPrompt(initialPrompt)

    Llama.saveState()
end

function Ready()
    Send({
        Target = Config.Process.LlamaHerder,
        Action = "Worker-Ready",
        WorkerType = "Chat",
    })
end

function CompletePromptText(data)
    Helper.assert_non_empty(data, data.question, data.context)
    local prompt = json.encode({
        question = data.question,
        context = data.context
    })
    return prompt .. [[<|end|>
<|assistant|>]]
end

DefaultResponse = {
    Answer = "",
}

function ProcessPetition(data)
    Llama.loadState()
    
    local additionalPrompt = CompletePromptText(data)
    Llama.add(additionalPrompt)

    local responseBuilder = ""
    for i = 1, DefaultMaxResponse do
        responseBuilder = responseBuilder .. Llama.next()

        -- if end of <|endoftext|> or <|end|>, stop
        if string.match(responseBuilder, ".*<|.*") then
            responseBuilder = string.gsub(responseBuilder, "<|.*", "")
            break
        end
    end

    return {
        Answer = responseBuilder,
    }
end

Handlers.add(
    "Init",
    Handlers.utils.hasMatchingTag("Action", "Init"),
    function (msg)
        if msg.From ~= ao.id then
            return print("Init not allowed: " .. msg.From)
        end
        Init()
        Ready()
    end
)

Handlers.add(
    "UpdateSystemPrompt",
    Handlers.utils.hasMatchingTag("Action", "Update-System-Prompt"),
    function (msg)
        if msg.From ~= ao.id then
            return print("UpdateSystemPrompt not allowed: " .. msg.From)
        end

        local initialPrompt = PrimePromptText(SystemPrompt)
        print("Updated System Prompt: " .. initialPrompt)
        Llama.setPrompt(initialPrompt)
        Llama.saveState()
    end
)

Handlers.add(
    "Inference",
    Handlers.utils.hasMatchingTag("Action", "Inference"),
    function (msg)
        if not InferenceAllowList[msg.From] then
            print("Inference not allowed: " .. msg.From)
            return
        end

        local data = json.decode(msg.Data)
        local response = ProcessPetition(data)
        local answer = response.Answer
        Log.info("Inference", msg["X-TraceID"], answer)

        Ready()
        data.answer = answer
        Send({
            Target = Config.Process.Chat,
            Action = "Inference-Response",
            ["X-TraceID"] = msg["X-TraceID"],
            Data = json.encode(data)
        })
    end
)
