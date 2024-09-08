local DB = require("module.utils.db")
local Helper = require("module.utils.helper")
local datetime = require("module.utils.datetime")
local SQL = {}

SQL.DATABASE = [[
    CREATE TABLE IF NOT EXISTS questions (
    	id INTEGER PRIMARY KEY,
    	question TEXT,
    	expected_response TEXT
    );
    CREATE TABLE IF NOT EXISTS evaluations (
		id INTEGER PRIMARY KEY,
		participant_dataset_hash TEXT NOT NULL,
		question_id INTEGER NOT NULL,
		sas_score INTEGER,
		created_at INTEGER NOT NULL,
		response_at INTEGER,
		reference TEXT UNIQUE
	);
	CREATE INDEX IF NOT EXISTS idx_evaluations_participant_dataset_hash ON evaluations(participant_dataset_hash);
]]

SQL.init = function(client)
    DB:init(client)
    DB:exec(SQL.DATABASE)
end

SQL.BatchCreateQuestion = function(questions)
    Helper.assert_non_empty_array(questions)
    local values = {}
    for _, question in ipairs(questions) do
        Helper.assert_non_empty(question.question, question.expected_response)
        table.insert(values, {
            question = question.question,
            expected_response = question.expected_response,
        })
    end
    return DB:batchInsert("questions", values)
end

SQL.GetQuestions = function()
    return DB:query("questions")
end


SQL.BatchCreateEvaluation = function(evaluations)
    Helper.assert_non_empty_array(evaluations)
    local values = {}
    for _, evaluation in ipairs(evaluations) do
        Helper.assert_non_empty(evaluation.participant_dataset_hash, evaluation.question_id)
        table.insert(values, {
            participant_dataset_hash = evaluation.participant_dataset_hash,
            question_id = evaluation.question_id,
            created_at = datetime.unix(),
        })
    end
    return DB:batchInsert("evaluations", values)
end

SQL.CreateEvaluationSet = function(participant_dataset_hash)
    local questions = SQL.GetQuestions()
    local evaluations = {}
    for _, question in ipairs(questions) do
        table.insert(evaluations, {
            participant_dataset_hash = participant_dataset_hash,
            question_id = question.id,
        })
    end
    return SQL.BatchCreateEvaluation(evaluations)
end

SQL.GetUnEvaluated = function(limit)
    limit = limit or 1
    return DB:nrows(string.format([[
        SELECT
            e.id,
            e.participant_dataset_hash AS dataset_hash,
            q.question,
            q.expected_response
        FROM evaluations e
        JOIN questions q ON e.question_id = q.id
        WHERE e.reference IS NULL
        ORDER BY e.created_at
        LIMIT %d
    ]], limit))
end

SQL.UpdateEvaluationReference = function(id, reference)
    Helper.assert_non_empty(id, reference)
    return DB:update("evaluations", { reference = reference }, {
        id = id,
    })
end

SQL.SetEvaluationResponse = function(reference, sas_score)
    Helper.assert_non_empty(reference, sas_score)
    return DB:update("evaluations", {
        sas_score = tonumber(sas_score),
        response_at = datetime.unix(),
    }, {
        reference = reference,
    })
end

SQL.GetRank = function()
    return DB:nrows([=[
        WITH RankedScores AS (
            SELECT
				participant_dataset_hash,
				SUM(sas_score) AS total_score,
                ROW_NUMBER() OVER (ORDER BY SUM(sas_score) DESC, MIN(created_at)) AS rank,
				COUNT(id) AS total_evaluations,
				SUM(CASE WHEN sas_score IS NULL THEN 0 ELSE 1 END) AS completed_evaluations
            FROM
                evaluations
            GROUP BY
                participant_dataset_hash
        )
        SELECT
            rank,
            participant_dataset_hash AS dataset_hash,
            total_score AS score,
			1.0 * completed_evaluations / total_evaluations AS progress
        FROM
            RankedScores
        ORDER BY
            rank;
    ]=])
end

SQL.GetVersion = function()
    return DB:nrows("SELECT sqlite_version();")
end

return SQL
