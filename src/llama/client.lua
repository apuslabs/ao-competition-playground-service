local json = require("json")
local config = require("utils.config")
local Helper = require("utils.helper")
local LlamaClient = {
    ProcessID = config.Process.LlamaHerder,
    ClinetID = ao.id,
}

LlamaClient.Reference = function()
    return string.format("%-6s%s", LlamaClient.ClinetID, ao.reference)
end

LlamaClient.Evaluate = function(data, onReply, reference)
    Helper.assert_non_empty(data.question, data.expected_response, data.context)
    reference = reference or LlamaClient.Reference()
    Send({
        Target = LlamaClient.ProcessID,
        ["X-Reference"] = reference,
        Action = "Inference",
        WorkerType = "Evaluate",
        Data = json.encode(data),
    }).onReply(function(replyMsg)
        onReply(replyMsg.Data)
    end)
end

LlamaClient.Chat = function(data, onReply, reference)
    Helper.assert_non_empty(data.question, data.context)
    reference = reference or LlamaClient.Reference()
    Send({
        Target = LlamaClient.ProcessID,
        ["X-Reference"] = reference,
        Action = "Inference",
        WorkerType = "Chat",
        Data = json.encode(data),
    }).onReply(function(replyMsg)
        onReply(replyMsg.Data)
    end)
end

return LlamaClient
