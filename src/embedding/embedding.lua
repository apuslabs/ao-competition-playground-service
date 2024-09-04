local sqlite3 = require("lsqlite3")
local json = require("json")
local SQL = require("sql")
local log = require("utils.log")
local datetime = require("utils.datetime")
local Helper = require("utils.helper")

DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

local lastSubmissionTime = 0
local function throttleCheck(msg)
    local now = datetime.unix()
    if (now - lastSubmissionTime) < 5 * 60 then
        msg.reply({ Status = "429", Data = "Processing data. Try again in five minutes." })
        log.warn(string.format("Req from %s blocked due to rate limit", msg.From))
        return false
    end
    lastSubmissionTime = now
    return true
end

function CreateDatasetHandler(msg)
    if not throttleCheck(msg) then
        return
    end
    local data = json.decode(msg.Data)
    assert(data and data.hash and data.list, "Invalid data")
    SQL.CreateDocuments(data.hash, data.list)
    msg.reply({ Status = "200", Data = "Dataset created " .. #data.list .. " successfully" })
    log.info(string.format("%s Create Dataset %s (%s)", msg.From, data.hash, #data.list))
end

function EmbeddingDataHandler(msg)
    local ids = json.decode(msg.Data)
    assert(ids and #ids > 0, "Invalid data")
    SQL.BatchSetDocumentsEmbebed(ids)
    log.info(string.format("Embeded %d documents", #ids))
    msg.reply({ Status = "200", Data = "Embeded " .. #ids .. " successfully" })
end

function SearchPromptHandler(msg)
    local PromptReference = msg["X-Reference"] or msg.Reference
    local data = json.decode(msg.Data)
    Helper.assert_non_empty(data.dataset_hash, data.prompt)
    SQL.AddPrompt(PromptReference, msg.From, data.dataset_hash, data.prompt)
    log.info(string.format("%s Prompt %s added successfully", msg.From, PromptReference))
    msg.reply({ Status = "200", Data = "Prompt added successfully" })
end

Handlers.add("Create-Dataset", { Action = "Create-Dataset" }, CreateDatasetHandler)

Handlers.add("Get-Unembeded-Documents", { Action = "Get-Unembeded-Documents" }, function(msg)
    msg.reply({ Status = "200", Data = json.encode(SQL.GetUnembededDocuments()) })
end)

Handlers.add("Embedding-Data", { Action = "Embedding-Data" }, EmbeddingDataHandler)

Handlers.add("Search-Prompt", { Action = "Search-Prompt" }, SearchPromptHandler)

Handlers.add("GET-TORETRIEVE-PROMPT", { Action = "GET-TORETRIEVE-PROMPT" }, function(msg)
    msg.reply({ Status = "200", Data = json.encode(SQL.GetToRetrievePrompt()) })
end)

Handlers.add("Set-Retrieve-Result", { Action = "Set-Retrieve-Result" }, function(msg)
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
end)

Handlers.add("GET-Retrieve-Result", { Action = "GET-Retrieve-Result" }, function(msg)
    Helper.assert_non_empty(msg.Reference, msg.Sender)
    msg.reply({ Status = "200", Data = SQL.GetRetrievePrompt(msg.Sender, msg.Reference) })
end)
