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

function RESET_ALL_DATASET()
    local rank = SQL.GetRank()
    for _, row in ipairs(rank) do
        SQL.CleanDatasetReference(row.dataset_hash)
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