local json = require("json")
local config = require("utils.config")
local LlamaClient = {
    ProcessID = config.Process.LlamaHerder,
}

LlamaClient.Evaluate = function(data, onReply)
    assert(data.question, "question is required")
    assert(data.expected_response, "expected_response is required")
    assert(data.context, "context is required")
    Send({
        Target = LlamaClient.ProcessID,
        Tags = {
            Action = "Inference",
            WorkerType = "Evaluate",
        },
        Data = json.encode(data),
    }).onReply(function(replyMsg)
        onReply(replyMsg.Data)
    end)
end

LlamaClient.Chat = function(data, onReply)
    assert(data.question, "question is required")
    assert(data.context, "context is required")
    Send({
        Target = LlamaClient.ProcessID,
        Tags = {
            Action = "Inference",
            WorkerType = "Chat",
        },
        Data = json.encode(data),
    }).onReply(function(replyMsg)
        onReply(replyMsg.Data)
    end)
end

return LlamaClient
