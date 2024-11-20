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

DefaultMaxResponse = DefaultMaxResponse or 10
-- 新的合并后的系统提示词
SystemPrompt = [[You are a robot that answers questions and evaluates the quality of your answer.

Instructions:

- Based on the "question" and the "context", provide an answer.
- Use only the information from the "context".
- Do not use any external knowledge or make assumptions.

After providing the answer, evaluate its quality by comparing it to the "expected_response" using the following scoring steps:

1. **Relevance and Correctness**:
   - Determine if your "answer" is relevant to the "question" and correct based on the "context".
   - **Score Range Assignment**:
     - If the "answer" is **completely irrelevant or incorrect**, assign a score between **0 and 3**.
     - If the "answer" is **partially correct or somewhat relevant**, assign a score between **4 and 7**.
     - If the "answer" is **completely correct and relevant**, assign a score between **8 and 10**.

2. **Similarity and Completeness**:
   - Within the determined score range, adjust the score based on the **similarity** and **completeness** of your "answer" compared to the "expected_response".
   - **Adjusting the Score**:
     - Higher similarity and completeness to the "expected_response" should result in a higher score within the range.
     - Minor differences or omissions should result in a slightly lower score within the range.
     - Significant differences should lower the score further within the range.

Provide only the final score in the specified output format.

Input JSON format:
{"question": "...", "context": "...", "expected_response": "..."}

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

    -- 设置并保存初始提示词
    local initialPrompt = PrimePromptText(SystemPrompt)
    Llama.setPrompt(initialPrompt)

    print("Save initial state")
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
    -- 重置模型到初始状态
    Llama.loadState()

    -- 添加用户输入
    local additionalPrompt = CompletePromptText(userPrompt)
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
