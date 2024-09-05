local config = require("utils.config")
local RAGClient = {
    ProcessID = config.Process.Embedding,
    ClinetID = ao.id,
}
local json = require("json")
local Helper = require("utils.helper")
local LlamaClient = require("llama.client")

RAGClient.Reference = function()
    return string.format("%-6s%s", RAGClient.ClinetID, ao.reference)
end

RAGClient.Chat = function(data, onReply, reference)
    Helper.assert_non_empty(data.dataset_hash, data.question)
    reference = reference or RAGClient.Reference()
    Send({
        Target = RAGClient.ProcessID,
        Action = "Search-Prompt",
        ["X-Reference"] = reference or RAGClient.Reference(),
        Data = json.encode({
            dataset_hash = data.dataset_hash,
            prompt = data.question
        })
    }).onReply(function(replyMsg)
        LlamaClient.Chat({
            question = data.question,
            context = replyMsg.Data
        }, function(resultMsg)
            onReply(resultMsg.Data, reference)
        end, reference)
    end)
    return reference
end

RAGClient.Evaluate = function(data, onReply, reference)
    Helper.assert_non_empty(data.dataset_hash, data.question, data.expected_response)
    reference = reference or RAGClient.Reference()
    Send({
        Target = RAGClient.ProcessID,
        Action = "Search-Prompt",
        ["X-Reference"] = reference,
        Data = json.encode({
            dataset_hash = data.dataset_hash,
            prompt = data.question
        })
    }).onReply(function(replyMsg)
        LlamaClient.Evaluate({
            question = data.question,
            expected_response = data.expected_response,
            context = replyMsg.Data
        }, function(resultMsg)
            onReply(resultMsg.Data, reference)
        end, reference)
    end)
    return reference
end

return RAGClient
