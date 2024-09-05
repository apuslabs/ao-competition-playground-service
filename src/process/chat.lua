local json = require("json")
local sqlite3 = require("lsqlite3")
local SQL = require("sqls.chat")
local Helper = require("module.utils.helper")
local RAGClient = require("module.embedding.client")

DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

Handlers.add("Chat-Question", { Action = "Chat-Question" }, function(msg)
    local data = json.decode(msg.Data)
    Helper.assert_non_empty(data.dataset_hash, data.question)
    local reference = RAGClient.Chat(data.dataset_hash, data.question, function(response, ref)
        SQL.SetResponse(ref, response)
    end)
    SQL.CreateChat(reference, data.dataset_hash, data.question)
end)

Handlers.add("Get-Chat-Answer", { Action = "Get-Chat-Answer" }, function(msg)
    local reference = msg.Data
    local chat = SQL.GetChat(reference)
    if not chat then
        msg.reply({ Status = 404, Data = "Not Found" })
        return
    elseif not chat.response then
        msg.reply({ Status = 102, Data = "Processing" })
        return
    else
        msg.reply({ Status = 200, Data = chat.response })
    end
end)
