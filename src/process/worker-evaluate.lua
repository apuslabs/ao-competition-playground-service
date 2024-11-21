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

DefaultMaxResponse = DefaultMaxResponse or 20
SystemPrompt = [[
# Role

You are a robot evaluating whether the context contains sufficient information to derive the expected_response for the given question.

# Instructions

Follow these steps carefully:
1.	Analyze the Context
    -   Carefully read the "context" provided.
    -   **Only** use information from the "context".
    -   **Do not** use any external knowledge or make assumptions.
2.	Assess Sufficiency
    -   Determine if the "context" provides enough information to answer the "question" with the "expected_response".
    -   **Focus on** whether the core content of the "expected_response" is present in the "context".
3.	Assign a Score
    -   If the "context" fully supports deriving the "expected_response", assign a score between 8 and 10.
    -   If the "context" partially supports deriving the "expected_response", assign a score between 4 and 7.
    -   If the "context" does not support deriving the "expected_response", assign a score between 0 and 3.
    -   Within each score range, higher relevance and completeness lead to a higher score.
4.	Provide the Final Score
    -   **Only** output the final score in the json format.
    -   **Do not** include any explanations or additional text.

# Input Format

```json
{"question": "...", "context": "...", "expected_response": "..."}
```

# Output Format

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
    Llama.load("/data/" .. Config.Llama.DefaultModel)

    local initialPrompt = PrimePromptText(SystemPrompt)
    Llama.setPrompt(initialPrompt)
    Log.info("Initial Prompt: " .. initialPrompt)
    Llama.saveState()
end

function Ready()
    Send({
        Target = Config.Process.LlamaHerder,
        Action = "Worker-Ready",
        WorkerType = "Evaluate",
    })
end


function CompletePromptText(data)
    Helper.assert_non_empty(data, data.question, data.context, data.expected_response)
    local prompt = json.encode({
        question = data.question,
        context = data.context,
        expected_response = data.expected_response
    })
    return prompt .. [[<|end|>
<|assistant|>]]
end

DefaultResponse = {
    Score = -1,
}

function ProcessPetition(data)
    Llama.loadState()

    local additionalPrompt = CompletePromptText(data)
    Llama.add(additionalPrompt)

    local responseJson = nil
    local responseBuilder = ""

    for i = 1, DefaultMaxResponse do
        responseBuilder = responseBuilder .. Llama.next()

        local responseJsonMatch = string.match(responseBuilder, "({.*})")
        if responseJsonMatch then
            responseJson = json.decode(responseJsonMatch)
            break
        end

        if string.match(responseBuilder, "<|end|>") or
           string.match(responseBuilder, "<|endoftext|>") or
           string.match(responseBuilder, "<|user|>") or
           string.match(responseBuilder, "<|assistant|>") or
           string.match(responseBuilder, "<|system|>") then
            break
        end
    end

    if not responseJson or not responseJson.score then
        print("Unusable response: " .. responseBuilder)
        return DefaultResponse
    end

    -- 解析得分
    local scoreNumber = tonumber(responseJson.score)
    if not scoreNumber then
        print("Invalid score: " .. responseJson.score)
        return DefaultResponse
    end

    -- 限制得分范围
    scoreNumber = math.min(10, math.max(0, scoreNumber))

    return {
        Score = scoreNumber,
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
    "Inference",
    Handlers.utils.hasMatchingTag("Action", "Inference"),
    function (msg)
        if not InferenceAllowList[msg.From] then
            print("Inference not allowed: " .. msg.From)
            return
        end

        local data = json.decode(msg.Data)
        local response = ProcessPetition(data)
        local score = response.Score
        Log.info(msg["X-TraceID"], score)

        Ready()
        data.score = score
        Send({
            Target = Config.Process.Competition,
            Action = "Inference-Response",
            ["X-TraceID"] = msg["X-TraceID"],
            Data = json.encode(data)
        })
    end
)

function TestInference()
    local userPrompt = [[{"question": "What is the name of the car wash that Walter White buys to launder money?","context": "Question: What is Walter White's alias in 'Breaking Bad'? Answer: Walter White's alias in 'Breaking Bad' is Heisenberg, which he adopts as part of his drug lord persona.\nQuestion: How does Walter White initially start manufacturing methamphetamine? Answer: Walter White initially starts manufacturing methamphetamine using a mobile RV lab in the New Mexico desert, partnering with former student Jesse Pinkman.","expected_response": "A1A Car Wash."}]]
    local response = ProcessPetition(userPrompt)
    return response
end
