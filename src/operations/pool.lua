local json = require("json")
local Datetime = require("module.utils.datetime")

Stats = {}
Stats.Participants = function (poolId)
    local now = Datetime.unix()
    local lastHour = now - 3600
    local lastDay = now - 86400

    local lastHourParticipants = 0
    local lastDayParticipants = 0
    local totalParticipants = 0
    for id, _ in pairs(SQL.GetOngoingCompetitions()) do
        lastHourParticipants = lastHourParticipants + SQL.CountParticipantsByCreatedTime(id, lastHour, now)
        lastDayParticipants = lastHourParticipants + SQL.CountParticipantsByCreatedTime(id, lastDay, now)
        totalParticipants = lastHourParticipants + SQL.GetTotalParticipants(id)
    end
    return json.encode({
        last_hour = lastHourParticipants,
        last_day = lastDayParticipants,
        total = totalParticipants
    })
end

Stats.Dataset = function (poolId)
    local res = {}
    for id, pool in pairs(SQL.GetOngoingCompetitions()) do
        table.insert(res, {
            PoolId = id,
            Process = pool.process_id,
            evaluated = SQL.CountEvaluatedDatasets(id),
            unEvaluated = SQL.CountUnEvaluatedDatasets(id),
        })
    end
    return json.encode(res)
end

Ops = {}

Ops.DANGEROUS_CLEAR = function(poolId)
    assert(poolId, "poolId is required")
    SQL.ClearParticipants(poolId)
end