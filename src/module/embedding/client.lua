local json = require("json")
local Config = require("module.utils.config")
local Helper = require("module.utils.helper")
local Log = require("module.utils.log")

local RAGClient = {}

RAGClient.Reference = function()
    return string.format("%s-%s", ao.id:sub(1, 6), ao.reference)
end

RAGClient.RAG = function(workerType, data)
    if workerType == "Evaluate" then
        Helper.assert_non_empty(data.dataset_hash, data.question, data.expected_response)
    elseif workerType == "Chat" then
        Helper.assert_non_empty(data.dataset_hash, data.question)
    end
    local traceid = RAGClient.Reference()
    Log.info("RAG", workerType, traceid)
    Send({
        Target = Config.Process.Embedding,
        Action = "Retrieve",
        ["X-TraceID"] = traceid,
        WorkerType = workerType,
        Data = json.encode(data)
    })
    return traceid
end

return RAGClient
