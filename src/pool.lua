local json = require("json")
local ao = require('.ao')
local sqlite3 = require("lsqlite3")
local SQL = require("sqls.pool")
local log = require("utils.log")
local Lodash = require("utils.lodash")
local Config = require("utils.config")
local Helper = require("utils.helper")
local datetime = require("utils.datetime")

DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

CompetitonPools = CompetitonPools or {}
local function getOngoingCompetitions()
    local pools = {}
    for _, pool in pairs(CompetitonPools) do
        local metadata = json.decode(pool.metadata)
        local startTime = metadata.competition_time["start"]
        local endTime = metadata.competition_time["end"]
        local now = datetime.unix()
        if now >= startTime and now <= endTime then
            table.insert(pools, pool)
        end
    end
    return pools
end

APUS_BALANCE = APUS_BALANCE or 0

Handlers.add("Get-Competitions", "Get-Competitions", function(msg)
    msg.reply({ Status = "200", Data = json.encode(Lodash.keys(CompetitonPools)) })
end)

Handlers.add("Get-Competition", "Get-Competition", function(msg)
    local poolId = tonumber(msg.Data)
    msg.reply({ Status = "200", Data = json.encode(CompetitonPools[poolId]) })
end)

Handlers.add("Get-Participants", "Get-Datasets", function(msg)
    local poolId = tonumber(msg.Data)
    msg.reply({ Status = "200", Data = json.encode(SQL.GetParticipants(poolId)) })
end)

Handlers.add("Get-Leaderboard", "Get-Leaderboard", function(msg)
    local poolId = tonumber(msg.Data)
    msg.reply({ Status = "200", Data = json.encode(SQL.GetLeaderboard(poolId)) })
end)

function UpdateBalance()
    Send({ Target = Config.Process.Token, Action = "Balance" })
end

Handlers.add("Update-Balance", { From = Config.Process.Token, Account = ao.id }, function(msg)
    APUS_BALANCE = tonumber(msg.Balance)
end)
function Transfer(receipent, quantity)
    ao.send({
        Target = Config.Process.Token,
        Tags = {
            { name = "Action",    value = "Transfer" },
            { name = "Recipient", value = receipent },
            { name = "Quantity",  value = tostring(quantity) }
        }
    })
end

LatestPoolID = LatestPoolID or 1001

function CreatePoolHandler(msg)
    -- TODO: semantic params
    Helper.assert_non_empty(msg["X-Title"], msg["X-Description"], msg["X-Prize-Pool"], msg["X-Process-ID"],
        msg["X-MetaData"])

    LatestPoolID = LatestPoolID + 1
    CompetitonPools[LatestPoolID] = {
        owner = msg.Sender,
        title = msg["X-Title"],
        description = msg["X-Description"],
        reward_pool = ao.Quantity,
        process_id = msg["X-Process-ID"],
        metadata = msg["X-MetaData"]
    }
    Send({
        Target = msg.Sender,
        Action = "Create-Pool-Notice",
        Status = 200,
        Data = LatestPoolID
    })
end

Handlers.add("Create-Pool", { Action = "Credit-Notice", From = Config.Process.Token }, CreatePoolHandler)

local poolTimeCheck = function(poolID)
    local metadata = json.decode(CompetitonPools[poolID].metadata)
    local startTime = metadata.competition_time["start"]
    local endTime = metadata.competition_time["end"]
    local now = datetime.now()
    return now >= startTime and now <= endTime
end
local throttleCheck = Helper.throttleCheckWrapper(Config.Pool.JoinThrottle)
function JoinPoolHandler(msg)
    local data = json.decode(msg.Data)
    Helper.assert_non_empty(msg.PoolID, data.dataset_hash, data.dataset_name)
    if not poolTimeCheck(msg.PoolID) then
        msg.reply({ Status = 403, Data = "The event has ended, can't join in." })
    end
    if not throttleCheck(msg) then
        return
    end

    SQL.CreateParticipant(msg.PoolID, msg.From, data.dataset_hash, data.dataset_name)
    Send({
        Target = CompetitonPools[msg.PoolID].process_id,
        Action = "Join-Competition",
        Data = data.dataset_hash
    }).receive()
    msg.reply({ Status = 200, Data = "Join success" })
end

Handlers.add("Join-Pool", "Join-Pool", JoinPoolHandler)

Reward = { 35000, 20000, 10000, 5000, 5000, 5000, 5000, 5000, 5000, 5000 }
local function allocateReward(rank)
    if rank <= 10 then
        return Reward[rank]
    elseif rank <= 200 then
        return 300
    else
        return 0
    end
end
function GetRank(poolID)
    local ranks = Send({
        Target = CompetitonPools[poolID].process_id,
        Action = "Get-Rank"
    }).receive().Data
    for i in ipairs(ranks) do
        ranks[i].reward = allocateReward(i)
    end
    SQL.UpdateRank(poolID, ranks)
end

CircleTimes = CircleTimes or 0
function AutoUpdateLeaderboard()
    if CircleTimes >= Config.Pool.LeaderboardInterval then
        local ongoingCompetitions = getOngoingCompetitions()

        for _, pool in ipairs(ongoingCompetitions) do
            log.trace("Auto Update Leaderboard ", pool.title)
            GetRank(pool.id)
        end
        CircleTimes = 0
    else
        CircleTimes = CircleTimes + 1
    end
end

Handlers.add(
    "CronTick",
    "Cron",
    function()
        log.trace("CronTick at " .. datetime.now())
        AutoUpdateLeaderboard()
    end
)

Handlers.add("Get-Dashboard", "Get-Dashboard", function(msg)
    local From = msg.FromAddress or msg.From
    local poolID = tonumber(msg.Data)
    msg.reply({
        Status = 200,
        Data = json.encode({
            participants = SQL.GetTotalParticipants(poolID),
            granted_reward = SQL.GetTotalRewards(poolID),
            rank = SQL.GetUserRank(poolID, From),
            rewarded_tokens = SQL.GetUserReward(poolID, From)
        })
    })
end)
