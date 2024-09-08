local json = require("json")
local config = require("module.utils.config")
local Helper = require("module.utils.helper")
local LlamaClient = {
    ProcessID = config.Process.LlamaHerder,
    ClinetID = ao.id,
}

LlamaClient.Reference = function()
    return string.format("%s-%s", LlamaClient.ClinetID:sub(1, 6), ao.reference)
end

LlamaClient.Evaluate = function(data, onReply)
    Helper.assert_non_empty(data.question, data.expected_response, data.context)
    Send({
        Target = LlamaClient.ProcessID,
        Action = "Inference",
        WorkerType = "Evaluate",
        Data = json.encode(data),
    }).onReply(function(replyMsg)
        onReply(replyMsg.Data)
    end)
end

LlamaClient.Chat = function(data, onReply)
    Helper.assert_non_empty(data.question, data.context)
    Send({
        Target = LlamaClient.ProcessID,
        Action = "Inference",
        WorkerType = "Chat",
        Data = json.encode(data),
    }).onReply(function(replyMsg)
        onReply(replyMsg.Data)
    end)
end

return LlamaClient
