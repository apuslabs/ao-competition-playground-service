local config = require("module.utils.config")
local json = require("json")
local Helper = require("module.utils.helper")
local LlamaClient = require("module.llama.client")
local log = require("module.utils.log")

local RAGClient = {
    ProcessID = config.Process.Embedding,
    ClinetID = ao.id,
}

RAGClient.Reference = function()
    return string.format("%s-%s", RAGClient.ClinetID:sub(1, 6), ao.reference + 1)
end

RAGClient.Chat = function(data, onReply)
    Helper.assert_non_empty(data.dataset_hash, data.question)
    local reference = RAGClient.Reference()
    Send({
        Target = RAGClient.ProcessID,
        Action = "Search-Prompt",
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
        end)
    end)
    return reference
end

RAGClient.Evaluate = function(data, onReply, reference)
    Helper.assert_non_empty(data.dataset_hash, data.question, data.expected_response)
    local ref = reference or RAGClient.Reference()
    Send({
        Target = RAGClient.ProcessID,
        Action = "Search-Prompt",
        Data = json.encode({
            dataset_hash = data.dataset_hash,
            prompt = data.question
        })
    }).onReply(function(replyMsg)
        Log.debug("Evaluate Retrieved", ref)
        LlamaClient.Evaluate({
            question = data.question,
            expected_response = data.expected_response,
            context = replyMsg.Data
        }, function(resultMsg)
            onReply(resultMsg.Data, ref)
        end)
    end)
    return ref
end

return RAGClient
