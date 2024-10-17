local json = require("json")
local sqlite3 = require("lsqlite3")
SQL = require("module.sqls.sas_competition")
Config = require("module.utils.config")
local RAGClient = require("module.embedding.client")
Log = require("module.utils.log")
Log.level = "debug"
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
        -- SQL.RecoverTimeoutEvaluations(86400)
        CircleTimes = 0
    else
        CircleTimes = CircleTimes + 1
    end
end)

function Evaluate()
    local unevaluated = SQL.GetUnEvaluated(Config.Evaluate.BatchSize)
    for _, row in ipairs(unevaluated) do
        local reference = RAGClient.Evaluate(row, function (response, ref)
            SQL.SetEvaluationResponse(ref, response)
            Log.debug("Evaluate Result", ref, response)
        end)
        Log.debug("Evaluate", row.dataset_hash, row.question_id, reference)
        SQL.UpdateEvaluationReference(row.id, reference)
    end
end

function LoadQuestion(dataStr)
    SQL.BatchCreateQuestion(json.decode(dataStr))
end

function JoinCompetitionHandler(msg)
    SQL.CreateEvaluationSet(msg.Data)
end

Handlers.add("Join-Competition", "Join-Competition", JoinCompetitionHandler)

function GetRank()
    return json.encode(SQL.GetRank())
end

Handlers.add("Get-Rank", "Get-Rank", function(msg)
    -- msg.reply({ Status = "200", Data = GetRank() })
    Send({ Target = msg.From, Action = "Get-Rank-Response", Data = GetRank() })
end)

function GetQuestions()
    Log.debug(SQL.GetQuestions())
end

-- ops

function DANGEROUS_CLEAR()
    SQL.ClearEvaluation()
    SQL.ClearQuestion()
end

function SetUnEvaluatedDatasetFinished()
    local rank = SQL.GetRank()
    for _, row in ipairs(rank) do
        if row.progress > 0 and row.progress < 1 then
            SQL.SetUnEvaluatedDatasetFinished(row.dataset_hash)
        end
    end
end

function SetUnstartedDatasetReferenceNull()
    local rank = SQL.GetRank()
    for _, row in ipairs(rank) do
        if row.progress == 0 then
            Log.trace("SetUnstartedDatasetReferenceNull", row.dataset_hash)
            SQL.CleanDatasetReference(row.dataset_hash)
        end
    end
end

function EvaluateDataset(dataset_hash)
    local dataset = SQL.GetEvaluationByDatasetAndQuestion(dataset_hash)
    for _, row in ipairs(dataset) do
        local reference = RAGClient.Evaluate(row, function (response, ref)
            SQL.SetEvaluationResponse(ref, response)
            Log.debug("Evaluate Result", ref, response)
        end)
        Log.debug("Evaluate", row.dataset_hash, row.question_id, reference)
        SQL.UpdateEvaluationReference(row.id, reference)
    end
end

function EvaluateDatasetItem(dataset_hash, question_id)
    local item = SQL.GetEvaluationByDatasetAndQuestion(dataset_hash, question_id)
    if item ~= nil then
        local reference = RAGClient.Evaluate(item, function (response, ref)
            Log.debug(string.format("EvaluateDatasetItem Result: %s %s %s %s", dataset_hash, question_id, ref, response))
        end)
        Log.debug(string.format("EvaluateDatasetItem Start: %s %s %s", dataset_hash, question_id, reference))
        return item
    end
end

function CountEvaluations() 
    return json.encode({
        Evaluated = SQL.CountEvaluated(),
        Unevaluated = SQL.CountUnEvaluated(),
        Evaluating = SQL.CountEvaluating(),
    })
end