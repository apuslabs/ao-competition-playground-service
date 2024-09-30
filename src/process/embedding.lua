local json = require("json")
Log = require("module.utils.log")
local Helper = require("module.utils.helper")
Config = require("module.utils.config")
local Datetime = require("module.utils.datetime")
local Lodash = require("module.utils.lodash")

local throttleCheck = Helper.throttleCheckWrapper(Config.Pool.JoinThrottle)

UploadedUserList = UploadedUserList or {}
WhiteList = WhiteList or {}
function RemoveUserFromUploadedList(address)
    if UploadedUserList[address] then
        UploadedUserList[address] = nil
        Log.warn(string.format("Removed %s from uploaded list", address))
    end
end

function CheckUserStatus(address)
    if not Lodash.Contain(WhiteList, address) then -- WhiteList
        return "User " .. address .. " is not allowed to join the event."
    end
    if SQL.GetUserRank(1002, address) ~= -1 then
        return "User " .. address .. " has already joined the event."
    end
    if UploadedUserList[address] then
        return "User " .. address .. " has already called join pool."
    end
    return "User is OK"
end

function BatchAddWhiteList(list)
    for _, v in ipairs(list) do
        Lodash.InsertUnique(WhiteList, v)
    end
end

function BatchRemoveWhiteList(list)
    for _, v in ipairs(list) do
        Lodash.Remove(WhiteList, v)
    end
end
DatasetQueue = DatasetQueue or {}
CreatePending = CreatePending or {}
LastCreation = LastCreation or {}
function CreateDatasetHandler(msg)
    if UploadedUserList[msg.From] then
        Log.warn(string.format("%s has uploaded dataset before", msg.From))
        msg.reply({ Status = "403", Data = "You have uploaded dataset before." })
        return
    end

    if not Lodash.Contain(WhiteList, msg.From) then -- WhiteList
        Log.warn("User " .. msg.From .. " is not allowed to join the event.")
        msg.reply({ Status = "403", Data = "You are not allowed to join this event." })
        return
    end

    if not throttleCheck(msg) then
        return
    end

    if CreatePending[msg.From] then
        Log.warn(string.format("%s has pending creation", msg.From))
        msg.reply({ Status = 403, Data = "You have pending creation, please wait for it." })
        return
    end
    local data = json.decode(msg.Data)
    assert(data and data.hash and data.list and data.name and msg.PoolID, "Invalid data")
    
    CreatePending[msg.From] = true


    Log.info(string.format("%s Creation pending, waiting for syncronizations in Pool", msg.From))
    msg.reply({ Status = 200, Data = "Creation pending, waiting for syncronizations in Pool" })

    LastCreation[msg.From] = {created_at=Datetime.unix(), updated_at = Datetime.unix(), status="WAIT_FOR_SYNC"}

    Send({
        Target = Config.Process.Pool,
        Action = "Embedding-Join-Pool",
        User = msg.From,
        PoolID = msg.PoolID,
        Data = json.encode({ dataset_hash=data.hash, dataset_name=data.name})
    }).onReply(function(replyMsg)
        Log.trace("Receive reply from the pool " .. replyMsg.From)

        -- because once the data created, the timer will automaticly process the data, so
        -- it is hard to revert, we just ensure it will definately succeed.
        if not CreatePending[msg.From] then
            -- cancel by user.
            Log.trace("Reply message dropped because user canceld the uploading")

            LastCreation[msg.From] = { created_at = LastCreation[msg.From].created_at, updated_at = Datetime.unix(), status = "CANCELED" }
            return
        end

        if replyMsg.Status == "403" then
            Log.warn(string.format("%s Join pool failed: %s", msg.From, replyMsg.Data))
            LastCreation[msg.From] = { created_at = LastCreation[msg.From].created_at, updated_at = Datetime.unix(), status = "JOIN_POOL_FAILED", message = replyMsg
            .Data }
            return
        end
        
        if replyMsg.Status ~= "200" then
            Log.warn(string.format("%s Join pool failed due to unknown error", msg.From))
            LastCreation[msg.From] = { created_at = LastCreation[msg.From].created_at, updated_at = Datetime.unix(), status = "JOIN_POOL_FAILED", message = "Unknown error."}
            return
        end

        if replyMsg.Status == "200" then
            DatasetQueue[data.hash] = {
                created_at = Datetime.unix(),
                list = data.list,
                embedding = false,
            }
            Log.info(string.format("%s Create Dataset %s (%s)", msg.From, data.hash, #data.list))
            LastCreation[msg.From] = { created_at = LastCreation[msg.From].created_at, updated_at = Datetime.unix(), status = "JOIN_SUCCEED", message = "Successfully join the pool."}

            if not UploadedUserList[msg.From] then
                UploadedUserList[msg.From] = true
            end
        end
        CreatePending[msg.From] = false
    end)
end

function FetchCreationStatus(msg)
    local user = msg.Data
    msg.reply({Status="200", Data=json.encode(LastCreation[user])})
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

Handlers.add("Fetch-Creation-Status", "Fetch-Creation-Status", FetchCreationStatus)

Handlers.add("Check-Permission", "Check-Permission", function(msg)
    local From = msg.FromAddress or msg.From
    msg.reply({ Status = 200, Data = Lodash.Contain(WhiteList, From) })
end)

function DANGEROUS_CLEAR()
    SQL.ClearPrompts()
    SQL.ClearContents()
end
