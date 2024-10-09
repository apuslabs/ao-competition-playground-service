-- Module: XcWULRSWWv_bmaEyx4PEOFf4vgRSVCP9vM5AucRvI40
local aos2 = require("module.utils.aos2polyfill")
local Config = require("module.utils.config")

Colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

WorkerType = "Chat"

ModelID = ModelID or Config.Llama.DefaultModel
Llama = Llama or nil
RouterID = RouterID or Config.Process.LlamaHerder

InferenceAllowList = {
    [RouterID] = true,
    [ao.id] = true
}

DefaultMaxResponse = DefaultMaxResponse or 40

SystemPrompt = [[
You are an AI bot, answer question about Satoshi Nakamoto based on the context.

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

    print("Loading model: " .. ModelID)
    Llama.load("/data/" .. ModelID)

    local initialPrompt = PrimePromptText(SystemPrompt)
    print("Initial Prompt: " .. initialPrompt)
    Llama.setPrompt(initialPrompt)

    print("Save state")
    Llama.saveState()
end

function CompletePromptText(userPrompt)
    return userPrompt .. [[<|end|>
<|assistant|>]]
end

DefaultResponse = {
    Answer = "",
}

function ProcessPetition(userPrompt)
    local additionalPrompt = CompletePromptText(userPrompt)
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

        ModelID = msg.Tags["Model-ID"] or ModelID
        DefaultMaxResponse = msg.Tags["Max-Response"] or DefaultMaxResponse
        Init()
        ao.send({
            Target = RouterID,
            Tags = {
                Action = "Init-Response",
                WorkerType = WorkerType,
            },
        })
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

        local userPrompt = msg.Data
        local response = ProcessPetition(userPrompt)

        local answer = response.Answer
        print("[" .. Colors.gray .. "INFERENCE" .. Colors.reset .. " ]" ..
            " From: " .. Colors.blue .. msg.From .. Colors.reset ..
            " | Reference: " .. Colors.blue .. msg.Tags["Reference"] .. Colors.reset ..
            " | Answer: " .. Colors.blue .. answer .. Colors.reset)

        aos2.replyMsg(msg, { Data = answer })

        Llama.loadState()
    end
)
