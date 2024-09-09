local json = require("json")
local sqlite3 = require("lsqlite3")
SQL = require("module.sqls.chat")
local RAGClient = require("module.embedding.client")
Log = require("module.utils.log")

DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

Handlers.add("Chat-Question", { Action = "Chat-Question" }, function(msg)
    local data = json.decode(msg.Data)
    local reference = RAGClient.Chat(data, function(response, ref)
        SQL.SetResponse(ref, response)
    end)
    SQL.CreateChat(reference, data.dataset_hash, data.question)
    msg.reply({ Status = 200, Data = reference })
end)

function GetChatAnswer(reference)
    local chat = SQL.GetChat(reference)
    Log.debug("GetChatAnswer", reference, chat)
    if not chat then
        return nil
    elseif not chat.response then
        return "__NULL"
    else
        return chat.response
    end
end

Handlers.add("Get-Chat-Answer", { Action = "Get-Chat-Answer" }, function(msg)
    local reference = msg.Data
    local response = GetChatAnswer(reference)
    if not response then
        msg.reply({ Status = 404, Data = "Not Found" })
    elseif response == "__NULL" then
        msg.reply({ Status = 102, Data = "Processing" })
    else
        msg.reply({ Status = 200, Data = response })
    end
end)

function GetAllChats()
    return SQL.GetAllChats()
end

function DANGEROUS_CLEAR()
    return SQL.ClearChats()
end
