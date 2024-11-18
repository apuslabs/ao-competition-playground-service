-- sqlite

local json = require("json")
local crypto = require(".crypto");
local base64 = require(".base64")
Log = require("module.utils.log")
local Helper = require("module.utils.helper")
Config = require("module.utils.config")
local Datetime = require("module.utils.datetime")
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
    local listStr = base64.decode(list)
    return crypto.digest.md5(listStr).asHex()
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
        return false
    end
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
        Log.trace("Receive reply from the pool " .. replyMsg.From)
        local replySwitch = {
            ["403"] = {
                status = "JOIN_POOL_FAILED",
                message = replyMsg,
                func = function ()
                    Log.warn(string.format("%s Join pool failed: %s", msg.From, replyMsg.Data))
                end
            },
            ["200"] = {
                status = "JOIN_SUCCEED",
                message = "Successfully join the pool.",
                func = function ()
                    local dataList = json.decode(base64.decode(data.list))
                    local rc = SQL.BatchInsert(data.hash, dataList)
                    if rc == 0 then
                        Log.info(string.format("%s Dataset %s created successfully", msg.From, data.hash))
                        local listHash = GetDatasetHash(data.list)
                        UploadedUserList[msg.From] = true
                        UploadedDatasetList[data.hash] = msg.From
                        UploadedDatasetHashList[listHash] = msg.From
                        msg.reply({ Status = "200", Data = "Dataset created successfully" })
                    else
                        Log.warn(string.format("%s Dataset %s created failed", msg.From, data.hash))
                        msg.reply({ Status = "403", Data = "Dataset created failed" })
                    end
                end
            },
            ["default"] = {
                status = "JOIN_POOL_FAILED",
                message = "unknown error",
                func = function ()
                    Log.warn(string.format("%s Join pool failed due to unknown error", msg.From))
                end
            },
        }

        local replyMatch = replySwitch[replyMsg.Status] or replySwitch["default"]
        if replyMatch.func then
            replyMatch.func() -- pay attention to return value to decide if we should continue in the future
        end
    end)
end

function SearchPromptHandler(msg)
    local data = json.decode(msg.Data)
    Helper.assert_non_empty(data.dataset_hash, data.prompt)
    local result = SQL.Match(data.dataset_hash, data.prompt, data.limit)
    msg.reply({ Status = "200", Data = json.encode(result) })
end

Handlers.add("Create-Dataset", "Create-Dataset", CreateDatasetHandler)

Handlers.add("Search-Prompt", "Search-Prompt", SearchPromptHandler)


function DANGEROUS_CLEAR()
    WhiteList = {}
    UploadedUserList = {}
    UploadDatasetQueue = {}
    UploadedDatasetHashList = {}
end