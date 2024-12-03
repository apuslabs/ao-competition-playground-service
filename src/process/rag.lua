-- sqlite

local json = require("json")
local crypto = require(".crypto");
Log = require("module.utils.log")
local Helper = require("module.utils.helper")
Config = require("module.utils.config")
local Lodash = require("module.utils.lodash")

local throttleCheck = Helper.throttleCheckWrapper(Config.Pool.JoinThrottle)

UploadedUserList = UploadedUserList or {}
UploadedDatasetList = UploadedDatasetList or {}
UploadedDatasetHashList = UploadedDatasetHashList or {}

WhiteList = WhiteList or {}
Handlers.add("Check-Permission", "Check-Permission", function (msg)
    local From = msg.FromAddress or msg.From
    msg.reply({ Status = "200", Data = Lodash.Contain(WhiteList, From) })
end)

function GetDatasetHash(list)
    return crypto.digest.md5(crypto.utils.stream.fromString(list)).asHex()
end

function CheckDataset(msg)
    -- Cehck whiteList
    if not Lodash.Contain(WhiteList, msg.From) then
        Log.warn("User " .. msg.From .. " is not allowed to join the event.")
        msg.reply({ Status = "403", Data = "You are not allowed to join this event." })
        return false
    end
    -- Check if user has uploaded dataset before
    if UploadedUserList[msg.From] then
        Log.warn(string.format("%s has uploaded dataset before", msg.From))
        msg.reply({ Status = "403", Data = "You have uploaded dataset before." })
        return false
    end
    local data = json.decode(msg.Data)
    -- Check if dataset name has been taken
    if UploadedDatasetList[data.hash] then
        Log.warn(string.format("%s has been taken, uploaded by %s", data.hash, msg.From))
        msg.reply({ Status = "403", Data = "Your dataset hash has been taken." })
        return false
    end
    Helper.assert_non_empty(data, data.hash, data.list, data.name, msg.PoolID)
    -- check list dulplicate
    local listHash = GetDatasetHash(data.list)
    if UploadedDatasetHashList[listHash] then
        Log.warn(string.format("%s has been uploaded before, uploaded by %s", listHash, msg.From))
        msg.reply({ Status = "403", Data = "Your dataset has been uploaded before." })
        return false
    end
    -- check throttle
    if not throttleCheck(msg) then
        Log.warn(string.format("User %s is throttled", msg.From))
        msg.reply({ Status = "403", Data = "Too many requests, please try again later." })
        return false
    end
    return true
end

EmbeddingPorcesses = EmbeddingPorcesses or {}
DatasetProcessMap = DatasetProcessMap or {}
Queue = Queue or {}

function CreateDatasetHandler(msg)
    if not CheckDataset(msg) then
        return
    end
    local data = json.decode(msg.Data)
    Send({
        Target = Config.Process.Pool,
        Action = "Join-Pool",
        User = msg.From,
        PoolID = msg.PoolID,
        Data = json.encode({ dataset_hash = data.hash, dataset_name = data.name })
    }).onReply(function (replyMsg)
        if (replyMsg.Status ~= "200") then
            Log.warn(string.format("Join pool failed: %s %s", replyMsg.Status, replyMsg.Data))
            return
        end
        table.insert(Queue, msg)
        DispatchWork()
    end)
end

function RetrieveHandler(msg)
    local data = json.decode(msg.Data)
    Helper.assert_non_empty(data.dataset_hash, data.question)
    msg.forward(DatasetProcessMap[data.dataset_hash])
    Log.trace(string.format("Search prompt for %s, Redirect to %s", data.dataset_hash, DatasetProcessMap[data.dataset_hash]))
end

Handlers.add("Init-Response", "Init-Response", function (msg)
    local hasInited = Lodash.Contain(EmbeddingPorcesses, msg.From)
    if not hasInited then
        table.insert(EmbeddingPorcesses, msg.From)
        Log.info("Embedding process inited: " .. msg.From)
    end
end)

Handlers.add("Create-Dataset", "Create-Dataset", CreateDatasetHandler)

Handlers.add("Retrieve", "Retrieve", RetrieveHandler)

function DispatchWork()
    while #Queue > 0 and #EmbeddingPorcesses > 0 do
        local work = table.remove(Queue, 1)
        local process = table.remove(EmbeddingPorcesses, 1)
        local msg = work.msg
        local data = json.decode(msg.Data)
        UploadedUserList[msg.From] = true
        UploadedDatasetList[data.hash] = true
        UploadedDatasetHashList[GetDatasetHash(data.list)] = true
        Log.trace(string.format("Create dataset %s", data.name))
        msg.forward(process)
    end
end