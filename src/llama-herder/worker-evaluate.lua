-- Module: XcWULRSWWv_bmaEyx4PEOFf4vgRSVCP9vM5AucRvI40

Colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

WorkerType = "Evaluate"

local json = require("json")

ModelID = ModelID or "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
Llama = Llama or nil
RouterID = RouterID or "tgSFV4I0LvTmGw6RPjY4WZi1mDZ5r_2nt_7SDEjS9Hs"

InferenceAllowList = {
    [RouterID] = true,
    [ao.id] = true
}

DefaultMaxResponse = DefaultMaxResponse or 40

SystemPrompt = [[You are evaluating dataset quality. Follow these steps:
1. Assume the role of Sam Williams, Arweave founder, to understand the topic.
2. Formulate your answer to the question based on context and question.
3. As a robot, compare your answer with the expected response. Score semantic similarity from integer between 0 and 10 (0 = no similarity, 10 = almost identical).
  - If context is null, score based on existing knowledge.

Input JSON format:
```json
{"question": "...","context": "<QA of Sam's Tweet>","expected_response": "..."}
```
  - "context" may contain multiple lines or be null.

Output: Always respond in this JSON format:
```json
{"score": <integer_score_0_to_10>}
```
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
    Score = -1,
}

function ProcessPetition(userPrompt)
    local additionalPrompt = CompletePromptText(userPrompt)
    Llama.add(additionalPrompt)

    local responseJson = nil

    local responseBuilder = ""
    for i = 1, DefaultMaxResponse do
        responseBuilder = responseBuilder .. Llama.next()

        local responseJsonMatch = string.match(responseBuilder, ".*({.*}).*")
        if responseJsonMatch then
            responseJson = json.decode(responseJsonMatch)
            break
        end

        -- if end of <|endoftext|> or <|end|>, stop
        if string.match(responseBuilder, ".*<|end|>.*") or string.match(responseBuilder, ".*<|endoftext|>.*") or string.match(responseBuilder, ".*<|user|>.*") or string.match(responseBuilder, ".*<|assistant|>.*") or string.match(responseBuilder, ".*<|system|>.*") then
            break
        end
    end

    if not responseJson or not responseJson.score then
        print("Unusable response: " .. responseBuilder)
        return DefaultResponse
    end

    -- Parse the grade
    local scoreNumber = tonumber(responseJson.score)
    if not scoreNumber then
        print("Invalid grade: " .. responseJson.score)
        return DefaultResponse
    end

    -- Clamp the grade
    scoreNumber = math.min(10, math.max(-1, scoreNumber))

    return {
        Score = scoreNumber,
    }
end

Handlers.add(
    "Init",
    { Action = "Init" },
    function(msg)
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
    "Inference",
    { Action = "Inference" },
    function(msg)
        if not InferenceAllowList[msg.From] then
            print("Inference not allowed: " .. msg.From)
            return
        end

        local userPrompt = msg.Data
        local response = ProcessPetition(userPrompt)

        local score = response.Score
        print("[" .. Colors.gray .. "INFERENCE" .. Colors.reset .. " ]" ..
            " From: " .. Colors.blue .. msg.From .. Colors.reset ..
            " | Reference: " .. Colors.blue .. msg.Tags["Reference"] .. Colors.reset ..
            " | Score: " .. Colors.blue .. score .. Colors.reset)

        Send({
            Target = msg.From,
            Tags = {
                Action = "Inference-Response",
                Reference = msg.Tags["Reference"],
                WorkerType = WorkerType,
            },
            Data = tostring(score),
        })

        Llama.loadState()
    end
)

local testPrompt = [[{"question":"It is 2021-07-10 01:09:09 now. What are the use cases for a decentralized podcasting app?","expected_response":"It is 2021-07-10 03:33:07 now. Announcement of the next permaweb incubator, Open Web Foundry v4, is coming very soon! Anyone up for building a permaweb podcasting app? There are major opportunities in this area.","context":"Question: What is the UI preview for the upcoming social media platform? Answer: The UI preview shows a functional public prototype for a truly decentralized social media platform.\nQuestion: What is the importance of governance in cryptonetworks? Answer: Governance tokens represent the power to change the rules of the system, and their value increases as the cryptonetwork grows.\nQuestion: Why are content creation and distribution governed by anyone other than creators and end users? Answer: This is a core question driving many underlying issues in society, and the answer lies in the deficiency of the HTTP protocol.\n"}]]

function testInference()
    Send({
        Target = ao.id,
        Tags = {
            Action = "Inference",
            Reference = "test",
        },
        Data = testPrompt,
    })
end