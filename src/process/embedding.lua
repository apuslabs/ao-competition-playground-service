local json = require("json")
Log = require("module.utils.log")
local Helper = require("module.utils.helper")
Config = require("module.utils.config")
local Datetime = require("module.utils.datetime")

local throttleCheck = Helper.throttleCheckWrapper(Config.Pool.JoinThrottle)

UploadedUserList = UploadedUserList or {}
function RemoveUserFromUploadedList(address)
    if UploadedUserList[address] then
        UploadedUserList[address] = nil
        Log.warn(string.format("Removed %s from uploaded list", address))
    end
end

DatasetQueue = DatasetQueue or {}
function CreateDatasetHandler(msg)
    if UploadedUserList[msg.From] then
        Log.warn(string.format("%s has uploaded dataset before", msg.From))
        msg.reply({ Status = 403, Data = "You have uploaded dataset before." })
        return
    end
    if not throttleCheck(msg) then
        return
    end
    local data = json.decode(msg.Data)
    assert(data and data.hash and data.list, "Invalid data")
    DatasetQueue[data.hash] = {
        created_at = Datetime.unix(),
        list = data.list,
        embedding = false,
    }
    Log.info(string.format("%s Create Dataset %s (%s)", msg.From, data.hash, #data.list))
    if not UploadedUserList[msg.From] then
        UploadedUserList[msg.From] = true
    end
    msg.reply({ Status = 200, Data = "Dataset created " .. #data.list .. " successfully" })
end

function CountDatasetQueue()
    local count = 0
    for k, v in pairs(DatasetQueue) do
        count = count + 1
    end
    return count
end

function GetUnembededDocumentsHandler(msg)
    for hash, data in pairs(DatasetQueue) do
        msg.reply({
            Status = 200,
            Data = json.encode({
                dataset_hash = hash,
                documents = data.list
            })
        })
        return
    end
    msg.reply({ Status = 200, Data = "{}" })
end

function EmbeddingDataHandler(msg)
    local hash = msg.Data
    local dataset = DatasetQueue[hash]
    if not dataset then
        Log.warn(string.format("Dataset %s not found", hash))
        msg.reply({ Status = 404, Data = "Dataset not found" })
        return
    end
    local now = Datetime.unix()
    Log.info(string.format("Embeded %s documents COSTS %d", hash, now - dataset.created_at))
    DatasetQueue[hash] = nil
    msg.reply({ Status = 200, Data = "Set  " .. hash .. " Embeded" })
end

PromptQueue = PromptQueue or {}
function SearchPromptHandler(msg)
    local PromptReference = msg["X-Reference"] or msg.Reference
    local data = json.decode(msg.Data)
    Helper.assert_non_empty(data.dataset_hash, data.prompt)
    PromptQueue[PromptReference] = {
        reference = PromptReference,
        dataset_hash = data.dataset_hash,
        prompt = data.prompt,
        sender = msg.From,
        created_at = Datetime.unix()
    }
    Log.info(string.format("%s Prompt %s added successfully", msg.From, PromptReference))
end

function GetToRetrievePromptHandler(msg)
    local prompts = {}
    for _, data in pairs(PromptQueue) do
        table.insert(prompts, data)
        if #prompts >= Config.Embedding.RetrieveSize then
            break
        end
    end
    msg.reply({ Status = 200, Data = json.encode(prompts) })
end

function RecevicePromptResponseHandler(msg)
    local data = json.decode(msg.Data)
    for _, item in ipairs(data) do
        Helper.assert_non_empty(item.reference, item.retrieve_result)
        local now = Datetime.unix()
        local prompt = PromptQueue[item.reference]
        if not prompt then
            Log.warn(string.format("Prompt %s not found", item.reference))
            return
        end
        Log.info(string.format("Prompt %s retrieved COSTS %d", item.reference, now - prompt.created_at))
        -- TODO: direct send to Llama
        Send({
            Target = prompt.sender,
            Action = "Search-Prompt-Response",
            ["X-Reference"] = item.reference,
            Data = item.retrieve_result
        })
        PromptQueue[item.reference] = nil
    end
end

Handlers.add("Create-Dataset", "Create-Dataset", CreateDatasetHandler)

Handlers.add("Get-Unembeded-Documents", "Get-Unembeded-Documents", GetUnembededDocumentsHandler)

Handlers.add("Embedding-Data", "Embedding-Data", EmbeddingDataHandler)

Handlers.add("Search-Prompt", "Search-Prompt", SearchPromptHandler)

Handlers.add("GET-TORETRIEVE-PROMPT", "GET-TORETRIEVE-PROMPT", GetToRetrievePromptHandler)

Handlers.add("Set-Retrieve-Result", "Set-Retrieve-Result", RecevicePromptResponseHandler)

function DANGEROUS_CLEAR()
    SQL.ClearPrompts()
    SQL.ClearContents()
end
