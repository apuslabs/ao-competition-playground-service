local config = require("utils.config")
local Client = {
    ProcessID = config.Process.Embedding
}
local json = require("json")
local Helper = require("utils.helper")
local LlamaClient = require("llama.client")

Client.Chat = function(dataset_hash, question, onReply)
    Helper.assert_non_empty(dataset_hash, question)
    Send({
        Target = Client.ProcessID,
        Action = "Search-Prompt",
        Data = json.encode({
            dataset_hash = dataset_hash,
            prompt = question
        })
    }).onReply(function(replyMsg)
        LlamaClient.Chat({
            question = question,
            context = replyMsg.Data
        }, onReply)
    end)
end

Client.Evaluate = function(dataset_hash, question, expected_response, onReply)
    Helper.assert_non_empty(dataset_hash, question, expected_response)
    Send({
        Target = Client.ProcessID,
        Action = "Search-Prompt",
        Data = json.encode({
            dataset_hash = dataset_hash,
            prompt = question
        })
    }).onReply(function(replyMsg)
        LlamaClient.Evaluate({
            question = question,
            expected_response = expected_response,
            context = replyMsg.Data
        }, onReply)
    end)
end

return Client
