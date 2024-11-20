local json = require("json")
local ao = require(".ao")
local sqlite3 = require("lsqlite3")
SQL = require("module.sqls.pool")
Log = require("module.utils.log")
Lodash = require("module.utils.lodash")
Config = require("module.utils.config")
local Helper = require("module.utils.helper")
local Datetime = require("module.utils.datetime")

DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

Handlers.add("Get-Competitions", "Get-Competitions", function (msg)
    local competitions = SQL.GetCompetitions()
    for i, v in ipairs(competitions) do
        v.metadata = json.decode(v.metadata)
    end
    msg.reply({ Status = "200", Data = json.encode(competitions) })
end)

Handlers.add("Get-Competition", "Get-Competition", function (msg)
    local competition = SQL.GetCompetition(msg.Data)
    assert(competition, "Competition not found")
    competition.metadata = json.decode(competition.metadata)
    msg.reply({ Status = "200", Data = json.encode(competition) })
end)

Handlers.add("Get-Participants", "Get-Datasets", function (msg)
    msg.reply({ Status = "200", Data = json.encode(SQL.GetParticipants(msg.Data)) })
end)

Handlers.add("Get-Leaderboard", { Action = "Get-Leaderboard" }, function (msg)
    msg.reply({ Status = "200", Data = json.encode(SQL.GetLeaderboard(msg.Data)) })
end)

Handlers.add("Get-Dashboard", "Get-Dashboard", function (msg)
    local From = msg.FromAddress or msg.From
    local poolID = tonumber(msg.Data)
    local rank = 0
    local rewarded_tokens = 0
    if (From ~= "" and From ~= "1234") then
        rank = SQL.GetUserRank(poolID, From)
        rewarded_tokens = SQL.GetUserReward(poolID, From)
    end
    msg.reply({
        Status = "200",
        Data = json.encode({
            participants = SQL.GetTotalParticipants(poolID),
            granted_reward = SQL.GetTotalRewards(poolID),
            rank = rank,
            rewarded_tokens = rewarded_tokens
        })
    })
end)

LatestPoolID = LatestPoolID or 1000

function CreatePool(pool_id, title, reward_pool, process_id, start_time, end_time, metadata)
    LatestPoolID = LatestPoolID + 1
    local execResult = SQL.CreateCompetition(pool_id, ao.id, title, reward_pool, process_id, start_time, end_time, metadata)
    assert(execResult == 0, "Create competition failed")
end

local poolTimeCheck = function (competition)
    assert(competition, "Competition not found")
    local now = Datetime.unix()
    return now >= tonumber(competition.start_time) and now <= tonumber(competition.end_time)
end
UploadedUserList = UploadedUserList or {}
function RemoveUserFromUploadedList(address)
    if UploadedUserList[address] then
        UploadedUserList[address] = nil
        Log.warn(string.format("Removed %s from uploaded list", address))
    end
end

function CheckJoinPool(msg)
    if not poolTimeCheck(tonumber(msg.PoolID)) then
        msg.reply({ Status = "403", Data = "The event has ended, can't join in." })
        return false
    end
    if not Lodash.Contain(Config.WhiteList, msg.User) then
        msg.reply({ Status = "403", Data = "User " .. msg.User .. " is not allowed to join the event." })
        return
    end
    if UploadedUserList[msg.User] then
        msg.reply({ Status = "403", Data = "User " .. msg.User .. " has already called join pool." })
        return
    end
    msg.reply({ Status = "200", Data = "User is OK" })
end

function JoinPoolHandler(msg)
    Log.trace("Receive creation request from embedding process " .. msg.From)
    local competition = SQL.GetCompetition(msg.PoolID)
    if not poolTimeCheck(competition) then
        msg.reply({ Status = "403", Data = "The event has ended, can't join in." })
        return
    end
    
    local data = json.decode(msg.Data)
    SQL.CreateParticipant(msg.PoolID, msg.User, data.dataset_hash, data.dataset_name)
    UploadedUserList[msg.User] = true
    Log.info("Join Pool " .. msg.From .. " : ", data.dataset_hash)
    msg.reply({ Status = "200" })
end

Handlers.add("Join-Pool", { Action = "Join-Pool", From = Config.Process.Embedding }, JoinPoolHandler)

Reward = { 35000, 20000, 10000, 5000, 5000, 5000, 5000, 5000, 5000, 5000 }
local function allocateReward(rank)
    if rank <= 10 then
        return Reward[rank] * 6
    elseif rank <= 300 then
        return 300 * 6
    else
        return 0
    end
end

function OnGetRank(poolID, ranks)
    Log.info("Update Rank ", poolID, ranks)
    for i in ipairs(ranks) do
        ranks[i].reward = allocateReward(i)
    end
    SQL.UpdateRank(poolID, ranks)
end

function GetRank(poolID)
    local competition = SQL.GetCompetition(poolID)
    assert(competition, "Competition not found")
    Send({
        Target = competition.process_id,
        Action = "Get-Rank"
    }).onReply(function(msg)
        OnGetRank(poolID, json.decode(msg.Data))
    end)
end

CircleTimes = CircleTimes or 0
function AutoUpdateLeaderboard()
    if CircleTimes >= Config.Pool.LeaderboardInterval then
        local ongoingCompetitions = SQL.GetOngoingCompetitions()

        for id, pool in pairs(ongoingCompetitions) do
            Log.trace("Auto Update Leaderboard ", pool.title)
            GetRank(pool.pool_id)
        end
        CircleTimes = 0
    else
        CircleTimes = CircleTimes + 1
    end
end

Handlers.add("CronTick", "Cron", function ()
    Log.trace("Cron Tick")
    AutoUpdateLeaderboard()
end)
