local json = require("json")
local sqlite3 = require("lsqlite3")

Handlers.add(
    "Init",
    { Action = "Init" },
    function()
        DB = sqlite3.open_memory()

        DB:exec [[
            CREATE TABLE IF NOT EXISTS chatGroundEvaluations (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				dataset_hash TEXT,
				token INTEGER,
				question TEXT,
				prompt TEXT,
				response TEXT,
				inference_start_time DATETIME,
				inference_end_time DATETIME,
				inference_reference TEXT,
				client_reference TEXT
            );
            CREATE INDEX IF NOT EXISTS chatGroundEvaluations_reference ON chatGroundEvaluations (inference_reference);
            CREATE INDEX IF NOT EXISTS chatGroundEvaluations_client_reference ON chatGroundEvaluations (client_reference);
        ]]

        print("DB init")
    end
)

local SQL = {
    INSERT_CHAT_GROUND_EVALUATION = [[
      	INSERT INTO chatGroundEvaluations(dataset_hash, question, token, client_reference) VALUES('%s', '%s', '%d', '%s');
    ]],
    FIND_CHAT_GROUND_EVALUATION_BY_CLIENT_REFERENCE = [[
      	SELECT * FROM  chatGroundEvaluations WHERE client_reference = '%s';
    ]],
    FIND_CHAT_GROUND_EVALUATION_BY_INFER_REFERENCE = [[
      	SELECT * FROM  chatGroundEvaluations WHERE inference_reference = '%s';
    ]],
    UPDATE_CHAT_GROUND_EVALUATION_INFERENCE = [[
      	UPDATE chatGroundEvaluations SET inference_reference = '%s' WHERE client_reference = '%s'
    ]],
    UPDATE_CHAT_GROUND_EVALUATION_PROMPT = [[
      	UPDATE chatGroundEvaluations SET prompt = '%s' WHERE inference_reference = '%s'
    ]],
    UPDATE_CHAT_GROUND_EVALUATION_ANSWER = [[
      	UPDATE chatGroundEvaluations SET response = '%s' WHERE inference_reference = '%s'
    ]],
}

function UserChat(msg)
    local from = msg.From
    local timestamp = msg.Timestamp
    if UserChatStatistics[from] == nil then
        UserChatStatistics[from] = {}
    end
    if UserChatStatistics[from] then
        table.insert(UserChatStatistics[from], timestamp)
    end
end

function DatasetChat(hash, msg)
    local timestamp = msg.Timestamp
    if DatasetChatStatistics[hash] == nil then
        DatasetChatStatistics[hash] = {}
    end
    if DatasetChatStatistics[hash] then
        table.insert(DatasetChatStatistics[hash], timestamp)
    end
end

Handlers.add(
    "Chat-Statistics",
    { Action = "Chat-Statistics" },
    function(msg)
        if (msg.From ~= ao.id and msg.From ~= Owner) then
            assert(false, "Permission denied")
            return
        end
        ao.send({
            Target = msg.From,
            Tags = {
                { name = "Action", value = "Chat-Statistics-Response" },
                { name = "status", value = "200" }
            },
            Data = json.encode({
                UserChatStatistics = UserChatStatistics,
                DatasetChatStatistics = DatasetChatStatistics
            })
        })
    end
)

Handlers.add(
    "Chat-Question",
    { Action = "Chat-Question" },
    function(msg)
        local data = json.decode(msg.Data)
        local hash = data.dataset_hash
        local question = data.question
        local token = tonumber(data.token)

        ChatQuestionReference = ChatQuestionReference + 1
        DB:exec(string.format(SQL.INSERT_CHAT_GROUND_EVALUATION, hash, FixTextBeforeSaveDB(question), token,
            tostring(ChatQuestionReference)))
        local inferReference = SendEmeddingRequest(hash, question)
        DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_INFERENCE, inferReference, ChatQuestionReference))
        ao.send({
            Target = msg.From,
            Tags = {
                { name = "Action",      value = "Chat-Question-Response" },
                { name = "X-Reference", value = tostring(ChatQuestionReference) },
                { name = "status",      value = "200" }
            }
        })
        UserChat(msg)
        DatasetChat(hash, msg)
    end
)


SearchPromptReference = SearchPromptReference or 0
function SendEmeddingRequest(datasetHash, question)
    SearchPromptReference = SearchPromptReference + 1
    -- local ragData = string.format('{"dataset_hash": "%s","prompt":"%s"}', datasetHash, question)
    local ragData = json.encode({
        dataset_hash = datasetHash,
        prompt = question
    })
    print("SendEmeddingRequest: " .. "v2" .. tostring(SearchPromptReference))
    ao.send({
        Target = EmbeddingProcessId,
        Data = ragData,
        Tags = {
            --https://github.com/apuslabs/ao-rag-embedding
            { name = "Action",      value = "Search-Prompt" },
            { name = "X-Reference", value = "v2" .. tostring(SearchPromptReference) }
        }
    })
    return "v2" .. tostring(SearchPromptReference)
end

Handlers.add(
    "Get-Chat-Answer",
    { Action = "Get-Chat-Answer" },
    function(msg)
        local clientReference = msg.Data
        local statuCode, rsp
        for row in DB:nrows(string.format(SQL.FIND_CHAT_GROUND_EVALUATION_BY_CLIENT_REFERENCE, clientReference)) do
            if row.response == nil then
                statuCode = 100
                rsp = "PROCESSING"
            else
                statuCode = 200
                rsp = row.response
            end
        end
        ao.send({
            Target = msg.From,
            Tags = {
                { name = "Action", value = "Get-Chat-Answer-Response" },
                { name = "status", value = tostring(statuCode) } },
            Data = rsp
        })
    end
)


function SendUserChatGroundRequest(prompt, evaluationReference)
    -- print("SendUserChatGroundRequest(" .. evaluationReference .. ")")
    -- DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_PROMPT, prompt))
end

Handlers.add(
    "Search-Prompt-Response",
    { Action = "Search-Prompt-Response" },
    function(msg)
        local evaluationReference = msg.Tags["X-Reference"]

        local promptFromEmdedding = 'Null'
        if (msg.Data ~= nil and msg.Data ~= 'Null') then
            promptFromEmdedding = msg.Data
        end
        for row in DB:nrows(string.format(SQL.FIND_CHAT_GROUND_EVALUATION_BY_INFER_REFERENCE, evaluationReference)) do
            local body = {
                question = row.question,
                context = promptFromEmdedding
            }

            -- print("InferenceMessage(" .. evaluationReference .. "): " .. json.encode(body))
            Send({
                Target = LLMProcessId,
                Tags = {
                    Action = "Inference",
                    WorkerType = "Chat",
                    Reference = evaluationReference,
                },
                Data = json.encode(body),
            })
        end
    end
)

Handlers.add(
    "Inference-Response",
    { Action = "Inference-Response", WorkerType = "Chat" },
    function(msg)
        local workType = msg.Tags.WorkerType or ""
        local reference = msg.Tags["X-Reference"] or ""
        print("Inference-Response: " .. workType .. " " .. reference .. " " .. Dump(msg.Data))

        DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_ANSWER, FixTextBeforeSaveDB(msg.Data), reference))
    end
)
