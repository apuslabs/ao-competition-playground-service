-- Module: XcWULRSWWv_bmaEyx4PEOFf4vgRSVCP9vM5AucRvI40
local Config = require("module.utils.config")

Colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

WorkerType = "Evaluate"

local json = require("json")

ModelID = ModelID or Config.Llama.DefaultModel
Llama = Llama or nil
RouterID = RouterID or Config.Process.LlamaHerder

InferenceAllowList = {
    [RouterID] = true,
    [ao.id] = true
}

DefaultMaxResponse = DefaultMaxResponse or 40

-- 用于生成答案的系统提示词
SystemPrompt_GenerateAnswer = [[You are a helpful assistant.

Instructions:

- Based on the "question" and the "context", provide an answer.
- Use only the information from the "context".
- Do not use any external knowledge or make assumptions.

Input JSON format:
{"question": "...","context": "..."}

Provide your answer.

Output format:
{"answer": "<your_answer>"}
]]

-- 用于比较答案和预期响应的系统提示词
SystemPrompt_ScoreAnswer = [[You are a robot evaluating the correctness of an answer.

Instructions:

- Compare the provided "answer" to the "expected_response".
- Determine if the "answer" correctly answers the "question" based on the "context".
- Assign a score from 0 to 10 based on correctness (0 = completely incorrect, 10 = completely correct).
- Use only the information from the "context" to make your assessment.
- Do not use any external knowledge.

Input JSON format:
{"question": "...", "context": "...", "answer": "...", "expected_response": "..."}

Output format:
{"score": <integer_score_0_to_10>}
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
end

function CompletePromptText(userPrompt)
    return userPrompt .. [[<|end|>
<|assistant|>]]
end

DefaultResponse = {
    Score = -1,
}

function GenerateAnswer(question, context)
    -- 设置用于生成答案的提示词
    local initialPrompt = PrimePromptText(SystemPrompt_GenerateAnswer)
    Llama.setPrompt(initialPrompt)

    local userInput = json.encode({question = question, context = context})
    local additionalPrompt = CompletePromptText(userInput)
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

        -- 检查结束标记
        if string.match(responseBuilder, "<|end|>") or
           string.match(responseBuilder, "<|endoftext|>") or
           string.match(responseBuilder, "<|user|>") or
           string.match(responseBuilder, "<|assistant|>") or
           string.match(responseBuilder, "<|system|>") then
            break
        end
    end

    if not responseJson or not responseJson.answer then
        print("Unusable response: " .. responseBuilder)
        return nil
    end

    return responseJson.answer
end
function ScoreAnswer(question, context, answer, expected_response)
    -- 重置模型到初始状态
    Llama.loadState()

    -- 设置用于评分的提示词
    local initialPrompt = PrimePromptText(SystemPrompt_ScoreAnswer)
    Llama.setPrompt(initialPrompt)

    local userInput = json.encode({
        question = question,
        context = context,
        answer = answer,
        expected_response = expected_response
    })
    local additionalPrompt = CompletePromptText(userInput)
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

        -- 检查结束标记
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
        return DefaultResponse.Score
    end

    -- 解析得分
    local scoreNumber = tonumber(responseJson.score)
    if not scoreNumber then
        print("Invalid score: " .. responseJson.score)
        return DefaultResponse.Score
    end

    -- 限制得分范围
    scoreNumber = math.min(10, math.max(0, scoreNumber))

    return scoreNumber
end

function ProcessPetition(userPrompt)
    local inputJson = json.decode(userPrompt)
    if not inputJson or not inputJson.question or not inputJson.context or not inputJson.expected_response then
        print("Invalid input JSON")
        return DefaultResponse
    end

    local question = inputJson.question
    local context = inputJson.context
    local expected_response = inputJson.expected_response

    -- 第一步：生成答案
    local answer = GenerateAnswer(question, context)
    if not answer then
        print("Failed to generate answer")
        return DefaultResponse
    end

    print("Generated Answer: " .. answer)

    -- 第二步：比较答案和预期响应
    local score = ScoreAnswer(question, context, answer, expected_response)
    if score == DefaultResponse.Score then
        print("Failed to score similarity")
        return DefaultResponse
    end

    return {
        Score = score,
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
    "Inference",
    Handlers.utils.hasMatchingTag("Action", "Inference"),
    function (msg)
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
            ["X-Reference"] = msg["X-Reference"] or msg.Reference,
            Data = tostring(score)
        })
    end
)

function TestInference()
    local userPrompt = [[{"question": "What is the name of the car wash that Walter White buys to launder money?","context": "Question: What is Walter White's alias in 'Breaking Bad'? Answer: Walter White's alias in 'Breaking Bad' is Heisenberg, which he adopts as part of his drug lord persona.\nQuestion: How does Walter White initially start manufacturing methamphetamine? Answer: Walter White initially starts manufacturing methamphetamine using a mobile RV lab in the New Mexico desert, partnering with former student Jesse Pinkman.","expected_response": "A1A Car Wash."}]]
    local response = ProcessPetition(userPrompt)
    return response
end
