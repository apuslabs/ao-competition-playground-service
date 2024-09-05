local json = require("json")
local sqlite3 = require("lsqlite3")
local SQL = require("sqls.sas_competition")
local Config = require("utils.config")
local RAGClient = require("embedding.client")

DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

CircleTimes = CircleTimes or 0
Handlers.add("CronTick", "Cron", function()
    if (CircleTimes >= Config.Evaluate.Interval) then
        Evaluate()
        CircleTimes = 0
    else
        CircleTimes = CircleTimes + 1
    end
end)

function Evaluate()
    local unevaluated = SQL.GetUnEvaluated(Config.Evaluate.BatchSize)
    for _, row in ipairs(unevaluated) do
        local reference = RAGClient.Evaluate(row, function(response, ref)
            SQL.SetEvaluationResponse(ref, response)
        end)
        SQL.UpdateEvaluationReference(row.id, reference)
    end
end

function LoadQuestion(dataStr)
    SQL.BatchCreateQuestion(json.decode(dataStr))
end

Handlers.add("Join-Competition", "Join-Competition", function(msg)
    return SQL.CreateEvaluationSet(msg.Data)
end)

Handlers.add("Get-Rank", "Get-Rank", function(msg)
    return json.encode(SQL.GetRank())
end)
