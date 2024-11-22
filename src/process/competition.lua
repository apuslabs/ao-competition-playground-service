local json = require("json")
local crypto = require(".crypto");
local sqlite3 = require("lsqlite3")
SQL = require("module.sqls.sas_competition")
Config = require("module.utils.config")
local RAGClient = require("module.embedding.client")
local base64 = require(".base64")
Log = require("module.utils.log")
require("module.llama.client")
require("module.utils.helper")

DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

CircleTimes = CircleTimes or 0
Handlers.add("CronTick", "Cron", function ()
    Log.trace("Cron Tick")
    if (CircleTimes >= Config.Evaluate.Interval) then
        Log.trace("Auto Evaluate")
        Evaluate()
        Send({
            Target = Config.Process.Pool,
            Action = "Rank-Response",
            Data = GetRank()
        })
        CircleTimes = 0
    else
        CircleTimes = CircleTimes + 1
    end
end)

function Evaluate()
    local unevaluated = SQL.GetUnEvaluated(Config.Evaluate.BatchSize)
    for _, row in ipairs(unevaluated) do
        local traceid = RAGClient.RAG("Evaluate", row)
        SQL.UpdateEvaluationReference(row.id, traceid)
    end
end

Handlers.add("Inference-Response", "Inference-Response", function (msg)
    local data = json.decode(msg.Data)
    assert(data.score, "Score not provided.")
    Log.info("RAG-Response", msg["X-TraceID"])
    SQL.SetEvaluationResponse(msg["X-TraceID"], data.score)
end)

function LoadQuestion(dataStr)
    SQL.BatchCreateQuestion(json.decode(base64.decode(dataStr)))
end

function JoinCompetitionHandler(msg)
    SQL.CreateEvaluationSet(msg.Data)
end

Handlers.add("Join-Competition", "Join-Competition", JoinCompetitionHandler)

function GetRank()
    return json.encode(SQL.GetRank())
end

function GetQuestions()
    return SQL.GetQuestions()
end
