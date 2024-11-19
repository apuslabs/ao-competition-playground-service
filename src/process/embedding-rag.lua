-- sqlite

local json = require("json")
local crypto = require(".crypto");
local base64 = require(".base64")
Log = require("module.utils.log")
local Helper = require("module.utils.helper")
Config = require("module.utils.config")
local Lodash = require("module.utils.lodash")

local sqlite3 = require("lsqlite3")
SQL = require("module.sqls.embedding")
DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

local throttleCheck = Helper.throttleCheckWrapper(Config.Pool.JoinThrottle)

UploadedUserList = UploadedUserList or {}
UploadedDatasetList = UploadedDatasetList or {}
UploadedDatasetHashList = UploadedDatasetHashList or {}

WhiteList = WhiteList or {}
Handlers.add("Check-Permission", "Check-Permission", function (msg)
    local From = msg.FromAddress or msg.From
    msg.reply({ Status = "200", Data = Lodash.Contain(WhiteList, From) })
end)

UploadDatasetQueue = UploadDatasetQueue or {}

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
    -- if not throttleCheck(msg) then
    --     return false
    -- end
    return true
end

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
        local articles = json.decode(base64.decode(data.list))
        local rc = SQL.BatchInsert(data.hash, articles)
        if rc ~= 0 then
            Log.error(string.format("Insert dataset failed: %s %s", data.hash))
            return
        end
        UploadedUserList[msg.From] = true
        UploadedDatasetList[data.hash] = true
        UploadedDatasetHashList[GetDatasetHash(data.list)] = true
        Send({
            Target = Config.Process.Competition,
            Action = "Join-Competition",
            Data = data.hash
        })
        Log.trace(string.format("Create dataset %s", data.name))
    end)
end

function SearchPromptHandler(msg)
    local data = json.decode(msg.Data)
    Helper.assert_non_empty(data.dataset_hash, data.prompt)
    local result = SQL.Match(data.dataset_hash, data.prompt, 3)
    msg.reply({ Status = "200", Data = Lodash.join(result, "\n") })
    Log.trace(string.format("Search prompt %s %s", data.dataset_hash, data.prompt))
end

Handlers.add("Create-Dataset", "Create-Dataset", CreateDatasetHandler)

Handlers.add("Search-Prompt", "Search-Prompt", SearchPromptHandler)
