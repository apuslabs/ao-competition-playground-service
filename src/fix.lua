local json = require("json")

function getUnEvaluatedEvaluations(limit)
	local evaluations = {}
	for row in DB:nrows([[SELECT * FROM evaluations WHERE participant_dataset_hash = '760e7dab2836853c63805033e514668301fa9c47' and prediction_sas_score IS NULL;]]) do
		table.insert(evaluations, row)
	end
	return json.encode(evaluations)
end
-- 1ecf0d3b91a10748bf035efdc0fad552aefe2ade
function setNoScoreDataset(datasetId, score)
  DB:exec([[UPDATE evaluations SET prediction_sas_score = ]] .. score .. [[ WHERE participant_dataset_hash=']] .. datasetId .. [[' and prediction_sas_score IS NULL;]])
end