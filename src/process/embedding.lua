local sqlite3 = require("lsqlite3")
local json = require("json")
SQL = require("module.sqls.embedding")
Log = require("module.utils.log")
local Helper = require("module.utils.helper")
local Config = require("module.utils.config")

DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

local throttleCheck = Helper.throttleCheckWrapper(Config.Pool.JoinThrottle)

local UploadedUserList = {}

function CreateDatasetHandler(msg)
    if not throttleCheck(msg) then
        return
    end
    if UploadedUserList[msg.From] then
        msg.reply({ Status = "403", Data = "You have uploaded dataset before." })
        return
    end
    local data = json.decode(msg.Data)
    assert(data and data.hash and data.list, "Invalid data")
    SQL.CreateDocuments(data.hash, data.list)
    msg.reply({ Status = "200", Data = "Dataset created " .. #data.list .. " successfully" })
    Log.info(string.format("%s Create Dataset %s (%s)", msg.From, data.hash, #data.list))
    if not UploadedUserList[msg.From] then
        UploadedUserList[msg.From] = true
    end
end

function EmbeddingDataHandler(msg)
    local ids = json.decode(msg.Data)
    assert(ids and #ids > 0, "Invalid data")
    SQL.BatchSetDocumentsEmbebed(ids)
    Log.info(string.format("Embeded %d documents", #ids))
    msg.reply({ Status = "200", Data = "Embeded " .. #ids .. " successfully" })
end

function SearchPromptHandler(msg)
    local PromptReference = msg["X-Reference"] or msg.Reference
    local data = json.decode(msg.Data)
    Helper.assert_non_empty(data.dataset_hash, data.prompt)
    SQL.AddPrompt(PromptReference, msg.From, data.dataset_hash, data.prompt)
    Log.info(string.format("%s Prompt %s added successfully", msg.From, PromptReference))
end

function RecevicePromptResponseHandler(msg)
    local data = json.decode(msg.Data)
    for _, item in ipairs(data) do
        Helper.assert_non_empty(item.sender, item.reference, item.retrieve_result)
        SQL.SetRetrieveResult(item.reference, item.sender, item.retrieve_result)
        -- TODO: direct send to Llama
        Send({
            Target = item.sender,
            Action = "Search-Prompt-Response",
            ["X-Reference"] = item.reference,
            Data = item.retrieve_result
        })
    end
end

Handlers.add("Create-Dataset", "Create-Dataset", CreateDatasetHandler)

Handlers.add("Get-Unembeded-Documents", "Get-Unembeded-Documents", function(msg)
    msg.reply({ Status = "200", Data = json.encode(SQL.GetUnembededDocuments()) })
end)

Handlers.add("Embedding-Data", "Embedding-Data", EmbeddingDataHandler)

Handlers.add("Search-Prompt", "Search-Prompt", SearchPromptHandler)

function GetToRetrievePrompt()
    Log.debug(SQL.GetToRetrievePrompt())
end

Handlers.add("GET-TORETRIEVE-PROMPT", "GET-TORETRIEVE-PROMPT", function(msg)
    msg.reply({ Status = "200", Data = json.encode(SQL.GetToRetrievePrompt()) })
end)

Handlers.add("Set-Retrieve-Result", "Set-Retrieve-Result", RecevicePromptResponseHandler)

Handlers.add("GET-Retrieve-Result", "GET-Retrieve-Result", function(msg)
    Helper.assert_non_empty(msg.Reference, msg.Sender)
    msg.reply({ Status = "200", Data = SQL.GetRetrievePrompt(msg.Sender, msg.Reference) })
end)

function DANGEROUS_CLEAR()
    SQL.ClearPrompts()
    SQL.ClearContents()
end
