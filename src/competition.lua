local json = require("json")
local ao = require('.ao')
local sqlite3 = require("lsqlite3")
--Llama = require("@sam/Llama-Herder")

DB = DB or nil
CompetitonPools = CompetitonPools or {}
TokenProcessId = "al1xXXnWnfJD8qyZJvttVGq60z1VPGn4M5y6uCcMBUM"
EmbeddingProcessId = "9VLokL76v41BIAbDOvN5cpVm1OGkKIi5aVw1BaelPFM"
LLMProcessId = 'tgSFV4I0LvTmGw6RPjY4WZi1mDZ5r_2nt_7SDEjS9Hs'
LLamaProcessId = "lzNUGNUZ0rczcr7zh65ZPXc1XQ-XURk4zpuQRa4vZXk"
Phi3Template = [[<|system|>%s<|end|><|user|>%s<|end|><|assistant|>]]

PRIZE_BALANCE = PRIZE_BALANCE or 0
CompetitonPoolId = 1001

Handlers.add(
	"Init",
	{ Action = "Init" },
	function()
		DB = sqlite3.open_memory()

		DB:exec [[
            CREATE TABLE IF NOT EXISTS participants (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				author TEXT NOT NULL,
				upload_dataset_name TEXT NOT NULL,
				upload_dataset_time INTEGER,
				participant_dataset_hash TEXT,
				rewarded_tokens INTEGER DEFAULT 0,
				UNIQUE(participant_dataset_hash)
			);


            CREATE TABLE IF NOT EXISTS datasets (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				question TEXT,
				expected_response TEXT
            );

            CREATE TABLE IF NOT EXISTS chatGroundEvaluations (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				dataset_hash TEXT,
				token INTEGER,
				question TEXT,
				prompt TEXT,
				response TEXT,
				inference_start_time DATETIME,
				inference_end_time DATETIME,
				inference_reference TEXT,
				client_reference TEXT
            );
            CREATE INDEX IF NOT EXISTS chatGroundEvaluations_reference ON chatGroundEvaluations (inference_reference);
            CREATE INDEX IF NOT EXISTS chatGroundEvaluations_client_reference ON chatGroundEvaluations (client_reference);

            CREATE TABLE IF NOT EXISTS evaluations (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				author TEXT,
				participant_id INTEGER NOT NULL,
				participant_dataset_hash TEXT,
				dataset_id INTEGER NOT NULL,
				question TEXT NOT NULL,
				correct_answer TEXT NOT NULL,
				prediction TEXT,
				prediction_sas_score INTEGER,
				inference_start_time DATETIME,
				inference_end_time DATETIME,
				inference_reference TEXT,
				FOREIGN KEY (participant_id) REFERENCES participants(id),
				FOREIGN KEY (dataset_id) REFERENCES datasets(id)
			);
            CREATE INDEX IF NOT EXISTS evaluations_reference ON evaluations (inference_reference);
        ]]

		print("DB init")
	end
)

local SQL = {
	INSERT_DATASET = [[
      	INSERT INTO datasets(question, expected_response) VALUES ('%s', '%s');
    ]],
	FIND_ALL_PARTICIPANTS = [[
      	SELECT * FROM participants;
    ]],
	FIND_PARTICIPANT_BY_HASH = [[
     	SELECT * FROM participants WHERE participant_dataset_hash = '%s';
    ]],
	INSERT_PARTICIPANTS = [[
    	INSERT INTO participants (author, upload_dataset_name, participant_dataset_hash, upload_dataset_time) VALUES('%s', '%s', '%s', %d);
    ]],
	INSERT_EVALUATIONS = [[
      	INSERT INTO evaluations (participant_id, author, participant_dataset_hash, dataset_id, question, correct_answer) VALUES('%d', '%s', '%s', '%d', '%s', '%s');
    ]],
	ADD_REWARDED_TOKENS = [[
      	UPDATE participants SET rewarded_tokens = '%d' WHERE author = '%s' AND participant_dataset_hash = '%s';
    ]],
	FIND_ALL_DATASET = [[
      	SELECT id, question, expected_response FROM datasets;
    ]],
	FIND_USER_REWARDED_TOKENS_BY_AUTHOR_HASH = [[
      	SELECT rewarded_tokens as rewardedTokens from participants WHERE author = '%s' and participant_dataset_hash = '%s';
    ]],
	FIND_USER_REWARDED_TOKENS = [[
      	SELECT rewarded_tokens as rewardedTokens from participants WHERE author = '%s';
    ]],
	GET_UNEVALUATED_EVALUATIONS = [[
      	SELECT * FROM evaluations WHERE inference_start_time IS NULL LIMIT '%d';
    ]],
	START_EVALUATION = [[
      	UPDATE evaluations SET inference_start_time = datetime('now', 'utc'), inference_reference = '%s' WHERE id = '%d';
    ]],
	END_EVALUATION = [[
      	UPDATE evaluations SET inference_end_time = datetime('now', 'utc'), prediction = '%s' WHERE inference_reference = '%s';
    ]],
	GET_EVALUATION_BY_REFERENCE = [[
      	SELECT * FROM evaluations WHERE inference_reference = '%s';
    ]],
	UPDATE_SCORE = [[
      	UPDATE evaluations SET prediction_sas_score = '%d' WHERE inference_reference = '%s';
    ]],
	INSERT_CHAT_GROUND_EVALUATION = [[
      	INSERT INTO chatGroundEvaluations(dataset_hash, question, token, client_reference) VALUES('%s', '%s', '%d', '%s');
    ]],
	FIND_CHAT_GROUND_EVALUATION_BY_CLIENT_REFERENCE = [[
      	SELECT * FROM  chatGroundEvaluations WHERE client_reference = '%s';
    ]],
	FIND_CHAT_GROUND_EVALUATION_BY_INFER_REFERENCE = [[
      	SELECT * FROM  chatGroundEvaluations WHERE inference_reference = '%s';
    ]],
	UPDATE_CHAT_GROUND_EVALUATION_INFERENCE = [[
      	UPDATE chatGroundEvaluations SET inference_reference = '%s' WHERE client_reference = '%s'
    ]],
	UPDATE_CHAT_GROUND_EVALUATION_PROMPT = [[
      	UPDATE chatGroundEvaluations SET prompt = '%s' WHERE inference_reference = '%s'
    ]],
	UPDATE_CHAT_GROUND_EVALUATION_ANSWER = [[
      	UPDATE chatGroundEvaluations SET response = '%s' WHERE inference_reference = '%s'
    ]],
	TOTAL_PARTICIPANT_REWARDED_TOKENS = [[
      SELECT
		COUNT(*) AS total_participants,
		SUM(rewarded_tokens) AS total_rewarded_tokens
      FROM
      	participants;
	]],
	TOTAL_PARTICIPANTS_RANK = [[
        WITH RankedScores AS (
            SELECT
				p.author,
				p.upload_dataset_name AS dataset_name,
				p.upload_dataset_time AS upload_time,
				p.participant_dataset_hash AS dataset_id,
				p.rewarded_tokens AS granted_reward,
				SUM(e.prediction_sas_score) AS total_score,
                ROW_NUMBER() OVER (ORDER BY SUM(e.prediction_sas_score) DESC, p.upload_dataset_time) AS rank,
				COUNT(e.id) AS total_evaluations,
				SUM(CASE WHEN e.prediction_sas_score IS NOT NULL THEN 1 ELSE 0 END) AS completed_evaluations
            FROM
                participants p
            JOIN
                evaluations e ON e.participant_id = p.id
            GROUP BY
                p.id
        )
        SELECT
            rank,
            dataset_id,
            dataset_name,
			upload_time,
            total_score AS score,
            author,
            granted_reward,
			(CAST(completed_evaluations AS FLOAT) / total_evaluations) AS completion_progress
        FROM
            RankedScores
        ORDER BY
            rank;
	]],
	FIND_USER_RANK = [[
		WITH RankedScores AS (
            SELECT
				p.author,
                ROW_NUMBER() OVER (ORDER BY SUM(e.prediction_sas_score) DESC, p.upload_dataset_time) AS rank
            FROM
                participants p
            JOIN
                evaluations e ON e.participant_id = p.id
            GROUP BY
                p.id
        )
        SELECT
            rank
        FROM
            RankedScores
        WHERE
            author = '%s'
        ORDER BY
            rank;
	]]
}

--Handlers.add(
--	"Fix-DB",
--	Handlers.utils.hasMatchingTag("Action", "Fix-DB"),
--	function(msg)
--		print("DB exex: " .. tostring(DB:exec(msg.Data)))
--	end
--)

-- Handlers.add(
-- 	"Read-DB",
-- 	Handlers.utils.hasMatchingTag("Action", "Read-DB"),
-- 	function(msg)
-- 		if msg.Data == '' then
-- 			msg.Data = [[ SELECT name FROM sqlite_master WHERE type='table' ]]
-- 		end
-- 		for item in DB:nrows(msg.Data) do
-- 			-- print(type(item))
-- 			print(item)
-- 		end
-- 	end
-- )

Handlers.add(
	"DEBUG-DB",
	{ Action = "DEBUG-DB" },
	function(msg)
		print("DEBUG-DB")

		-- print("participants")
		-- for row in DB:nrows("select count(*) as cnt from participants;") do
		-- 	print("rows: " .. Dump(row))
		-- end
		-- for row in DB:nrows("select * from participants;") do
		-- 	print(Dump(row))
		-- end

		-- print("datasets")
		-- for row in DB:nrows("select count(*) as cnt from datasets;") do
		-- 	print("rows: " .. Dump(row))
		-- end
		-- for row in DB:nrows("select * from datasets;") do
		-- 	print(Dump(row))
		-- end

		--print("evaluations")
		--for row in DB:nrows("select count(*) as cnt from evaluations;") do
		--	print("rows: " .. Dump(row))
		--end
		--for row in DB:nrows("select * from evaluations;") do
		--	print(Dump(row))
		--end

		-- print("chatGroundEvaluations")
		-- for row in DB:nrows("select count(*) as cnt from chatGroundEvaluations;") do
		-- 	print("rows: " .. Dump(row))
		-- end
		-- for row in DB:nrows("select * from chatGroundEvaluations;") do
		-- 	print(Dump(row))
		-- end
	end
)

Handlers.add(
	"Get-Datasets",
	{ Action = "Get-Datasets" },
	function(msg)
		local rsp = {}
		local cnt = 0
		for row in DB:nrows(SQL.FIND_ALL_PARTICIPANTS) do
			cnt = cnt + 1
			rsp[cnt] = row
		end
		ao.send({
			Target = msg.From,
			Action = "Get-Datasets-Response",
			Data = json.encode(rsp)
		})
	end
)

ChatQuestionReference = ChatQuestionReference or 0
UserChatStatistics = UserChatStatistics or {}
DatasetChatStatistics = DatasetChatStatistics or {}

function UserChat(msg)
	local from = msg.From
	local timestamp = msg.Timestamp
	if UserChatStatistics[from] == nil then
		UserChatStatistics[from] = {}
	end
	if UserChatStatistics[from] then
		table.insert(UserChatStatistics[from], timestamp)
	end
end

function DatasetChat(hash, msg)
	local timestamp = msg.Timestamp
	if DatasetChatStatistics[hash] == nil then
		DatasetChatStatistics[hash] = {}
	end
	if DatasetChatStatistics[hash] then
		table.insert(DatasetChatStatistics[hash], timestamp)
	end
end

Handlers.add(
	"Chat-Statistics",
	{ Action = "Chat-Statistics" },
	function (msg)
		if (msg.From ~= ao.id and msg.From ~= Owner) then
			assert(false, "Permission denied")
			return
		end
		ao.send({
			Target = msg.From,
			Tags = {
				{ name = "Action", value = "Chat-Statistics-Response" },
				{ name = "status", value = "200" }
			},
			Data = json.encode({
				UserChatStatistics = UserChatStatistics,
				DatasetChatStatistics = DatasetChatStatistics
			})
		})
	end
)

Handlers.add(
	"Chat-Question",
	{ Action = "Chat-Question" },
	function(msg)
		local data = json.decode(msg.Data)
		local hash = data.dataset_hash
		local question = data.question
		local token = tonumber(data.token)

		ChatQuestionReference = ChatQuestionReference + 1
		DB:exec(string.format(SQL.INSERT_CHAT_GROUND_EVALUATION, hash, FixTextBeforeSaveDB(question), token,
			tostring(ChatQuestionReference)))
		local inferReference = SendEmeddingRequest(hash, question)
		DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_INFERENCE, inferReference, ChatQuestionReference))
		ao.send({
			Target = msg.From,
			Tags = {
				{ name = "Action",    value = "Chat-Question-Response" },
				{ name = "Reference", value = tostring(ChatQuestionReference) },
				{ name = "status",    value = "200" }
			}
		})
		UserChat(msg)
		DatasetChat(hash, msg)
	end
)

SearchPromptReference = SearchPromptReference or 0
function SendEmeddingRequest(datasetHash, question)
	SearchPromptReference = SearchPromptReference + 1
	-- local ragData = string.format('{"dataset_hash": "%s","prompt":"%s"}', datasetHash, question)
	local ragData = json.encode({
		dataset_hash = datasetHash,
		prompt = question
	})
	-- print("SendEmeddingRequest: " .. ragData)
	ao.send({
		Target = EmbeddingProcessId,
		Data = ragData,
		Tags = {
			--https://github.com/apuslabs/ao-rag-embedding
			{ name = "Action",    value = "Search-Prompt" },
			{ name = "Reference", value = tostring(SearchPromptReference) }
		}
	})
	return SearchPromptReference
end


Handlers.add(
	"Evaluate",
	{ Action = "Evaluate" },
	function(msg)
		-- print("Start Evaluate")
		-- print("Msg: " .. Dump(msg.Tags) .. Dump(msg.Data))
		local limit = tonumber(msg.Data) or 1
		-- if limit > 2 then
		-- 	limit = 2
		-- end
		for row in DB:nrows(string.format(SQL.GET_UNEVALUATED_EVALUATIONS, limit)) do
			-- print("Row: " .. Dump(row))
			local reference = SendEmeddingRequest(row.participant_dataset_hash, row.question)
			-- print("Reference: " .. reference)
			local result = DB:exec(string.format(
				SQL.START_EVALUATION,
				reference, row.id
			))
			-- print("DB exec result: " .. result)
		end
	end
)

Handlers.add(
	"Get-Chat-Answer",
	{ Action = "Get-Chat-Answer" },
	function(msg)
		local clientReference = msg.Data
		local statuCode, rsp
		for row in DB:nrows(string.format(SQL.FIND_CHAT_GROUND_EVALUATION_BY_CLIENT_REFERENCE, clientReference)) do
			if row.response == nil then
				statuCode = 100
				rsp = "PROCESSING"
			else
				statuCode = 200
				rsp = row.response
			end
		end
		ao.send({
			Target = msg.From,
			Tags = {
				{ name = "Action", value = "Get-Chat-Answer-Response" },
				{ name = "status", value = tostring(statuCode) } },
			Data = rsp
		})
	end
)

Handlers.add(
	"Search-Prompt-Response",
	{ Action = "Search-Prompt-Response" },
	function(msg)
		-- print("Search-Prompt-Response")
		-- print("Msg: " .. Dump(msg.Tags) .. Dump(msg.Data))
		local isEvaluation = false
		local evaluationReference = msg.Tags.Reference

		local promptFromEmdedding = 'Null'
		if (msg.Data ~= nil and msg.Data ~= 'Null') then
			promptFromEmdedding = msg.Data
		end
		-- print(type(promptFromEmdedding))

		for row in DB:nrows(string.format(SQL.GET_EVALUATION_BY_REFERENCE, evaluationReference)) do
			-- print("Send evaluation request" .. evaluationReference)
			isEvaluation = true
			local body = {
				question = row.question:gsub('\'s', ' is'),
				expected_response = row.correct_answer:gsub('\'s', ' is'),
				context = promptFromEmdedding
			}
			-- local allPrompt = string.format(Phi3Template, SasSystemPrompt, json.encode(body))
			-- print(allPrompt)

			Send({
				Target = LLMProcessId,
				Tags = {
					Action = "Inference",
					WorkerType = "Evaluate",
					Reference = evaluationReference,
				},
				Data = json.encode(body),
			})
		end

		if isEvaluation == false then
			SendUserChatGroundRequest(promptFromEmdedding, evaluationReference)
		end
	end
)

Handlers.add(
	"Inference-Response",
	{ Action = "Inference-Response" },
	function(msg)
		local workType = msg.Tags.WorkerType or ""
		local reference = msg.Tags.Reference or ""
		print("Inference-Response: " .. workType .. " " .. reference .. " " .. Dump(msg.Data))

		if workType == 'Evaluate' then
			local data = msg.Data or "-1"
			local score = tonumber(data)
			DB:exec(string.format(SQL.UPDATE_SCORE, score, FixTextBeforeSaveDB(reference)))
		elseif workType == 'Chat' then
			DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_ANSWER, FixTextBeforeSaveDB(msg.Data), reference))
		end
	end
)

function SendUserChatGroundRequest(prompt, evaluationReference)
	-- print("SendUserChatGroundRequest(" .. evaluationReference .. ")")
	-- DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_PROMPT, prompt))
	for row in DB:nrows(string.format(SQL.FIND_CHAT_GROUND_EVALUATION_BY_INFER_REFERENCE, evaluationReference)) do
		local body = {
			question = row.question,
			context = prompt
		}

		-- print("InferenceMessage(" .. evaluationReference .. "): " .. json.encode(body))
		Send({
			Target = LLMProcessId,
			Tags = {
				Action = "Inference",
				WorkerType = "Chat",
				Reference = evaluationReference,
			},
			Data = json.encode(body),
		})
	end
end

Handlers.add(
	"Balance-Response",
	function(msg)
		return msg.From == TokenProcessId and
			msg.Tags.Account == ao.id and msg.Tags.Balance ~= nil
	end,
	function(msg)
		PRIZE_BALANCE = tonumber(msg.Tags.Balance)
		-- print("Balance-Response: " .. PRIZE_BALANCE)
	end
)

function FixTextBeforeSaveDB(text)
	return text:gsub("'", "''")
end

function FixTextBeforeReadDB(text)
	return text:gsub("''", "'")
end

Handlers.add(
	"Load-Dataset",
	{ Action = "Load-Dataset" },
	function(msg)
		-- print("Load-Dataset")
		local data = msg.Data
		assert(data ~= nil, "Data is nil")
		local DataSets = json.decode(data)
		-- print("DataSets: " .. Dump(DataSets))
		for _, DataSetItem in ipairs(DataSets) do
			-- print('DataSetItem: ' .. Dump(DataSetItem))
			local context = FixTextBeforeSaveDB(DataSetItem.context)
			local response = FixTextBeforeSaveDB(DataSetItem.response[1])
			local query = string.format(SQL.INSERT_DATASET, context, response)
			local result = DB:exec(query)
			-- print(query .. 'result ' .. result)
		end
		-- print("Load-Dataset END")
	end
)


Handlers.add(
	"Create-Pool",
	function(msg)
		return msg.Tags.Action == "Credit-Notice" and
			msg.From == TokenProcessId
	end,
	function(msg)
		-- print("Create-Pool")
		-- print("Msg: " .. Dump(msg.Tags) .. Dump(msg.Data))
		local title = msg.Tags["X-Title"]
		local description = msg.Tags["X-Description"]
		local prizePool = msg.Tags["X-Prize-Pool"]
		local metaData = msg.Tags["X-MetaData"]

		CompetitonPools[CompetitonPoolId] = {
			title = title,
			description = description,
			prizePool = prizePool,
			metaData = metaData
		}
		-- print("CompetitonPools: " .. Dump(CompetitonPools))
		ao.send({
			Target = msg.From,
			Tags = {
				{ name = "Action", value = "Create-Pool-Response" },
				{ name = "status", value = "200" }
			}
		})
		-- print("Create-Pool END")
	end
)

local function initBenchmarkRecords(author, participantDatasetHash)
	local participantId
	for row in DB:nrows(string.format(SQL.FIND_PARTICIPANT_BY_HASH, participantDatasetHash)) do
		participantId = tonumber(row.id)
	end
	for row in DB:nrows(string.format(SQL.FIND_ALL_DATASET)) do
		local sql = string.format(SQL.INSERT_EVALUATIONS, participantId, author,
			participantDatasetHash, row.id,
			FixTextBeforeSaveDB(row.question),
			FixTextBeforeSaveDB(row.expected_response)
		)
		DB:exec(sql)
		-- print('sql:' .. sql .. ' result:' .. DB:exec(sql))
	end
end

local lastSubmissionTime = 0
local oneMinutes = 1 * 60

Handlers.add(
	"Join-Pool",
	{ Action = "Join-Pool" },
	function(msg)
		
		local metaDataTable = json.decode(CompetitonPools[1001].metaData)
		local endTime = tonumber(metaDataTable.competition_time["end"]) * 1000
		if msg.Timestamp > endTime then
			ao.send({
                Target = msg.From,
                Tags = {
                    { name = "Action", value = "Join-Pool-Response" },
                    { name = "status", value = "403" }
                },
				Data = "The event has ended, and joining is no longer allowed."
            })
            return
		  end

		local currentTime = math.floor(msg.Timestamp / 1000)
        if (currentTime - lastSubmissionTime) < oneMinutes then
            ao.send({
                Target = msg.From,
                Tags = {
                    { name = "Action", value = "Join-Pool-Response" },
                    { name = "status", value = "429" }
                },
				Data = "Processing data. Try again in one minutes."
            })
            return
        end

		lastSubmissionTime = currentTime

		local data = json.decode(msg.Data)
		local author = msg.From
		local datasetHash = FixTextBeforeSaveDB(data.dataset_hash)
		local datasetName = FixTextBeforeSaveDB(data.dataset_name)

		DB:exec(string.format(
			SQL.INSERT_PARTICIPANTS,
			author,
			datasetName,
			datasetHash,
			msg.Timestamp
		))
		initBenchmarkRecords(author, datasetHash)

		ao.send({
			Target = msg.From,
			Tags = {
				{ name = "Action", value = "Join-Pool-Response" },
				{ name = "status", value = "200" }
			}
		})
	end
)


function UpdateBalance()
	ao.send({
		Target = TokenProcessId,
		Tags = {
			{ name = "Action", value = "Balance" }
		}
	})
end

Handlers.add(
	"Get-Pool",
	{ Action = "Get-Pool" },
	function(msg)
		local pool = CompetitonPools[CompetitonPoolId]
		local meta_data = pool['metaData']

		-- delete below line after testing
		meta_data = string.gsub(meta_data, "1722554056", "1726096456")

		ao.send({
			Target = msg.From,
			Tags = {
				{ name = "Action", value = "Get-Pool-Response" },
				{ name = "status", value = "200" }
			},
			Data = json.encode({
				title = pool['title'],
				prize_pool = pool['prizePool'],
				meta_data = meta_data
			})
		})
		print("Get-Pool END")
	end
)

Reward = { 35000, 20000, 10000, 5000, 5000, 5000, 5000, 5000, 5000, 5000 }
local function computeReward(rank)
	if rank <= 10 then
		return Reward[rank]
	elseif rank <=200 then
		return 300
	else
		return 0
	end
end

-- local function computeNeedRewarded(amount, author, datasetHash)
--   for item in DB:nrows(string.format(SQL.FIND_USER_REWARDED_TOKENS_BY_AUTHOR_HASH, author, datasetHash)) do
--     return amount - tonumber(item.rewardedTokens)
--   end
--   return amount
-- end

Handlers.add(
	"Allocate-Rewards",
	{ Action = "Allocate-Rewards" },
	function(msg)
		for item in DB:nrows(SQL.TOTAL_PARTICIPANTS_RANK) do
			local amount = computeReward(item.rank)
			-- if PRIZE_BALANCE < amount then
			-- 	print("Balance is not enough, balance: " .. PRIZE_BALANCE .. " want: " .. amount)
			-- elseif amount > 0 then
			-- 	PRIZE_BALANCE = PRIZE_BALANCE - amount
			DB:exec(string.format(SQL.ADD_REWARDED_TOKENS, amount, item.author, item.dataset_id))
				-- TODO: transfer after competition ended
				-- transfer(item.author, amount)
			-- end
		end

		ao.send({
			Target = msg.From,
			Tags = {
				{ name = "Action", value = "Allocate-Rewards-Response" },
				{ name = "status", value = "200" }
			}
		})
	end
)

function transfer(author, amount)
	ao.send({
		Target = TokenProcessId,
		Tags = {
			{ name = "Action",    value = "Transfer" },
			{ name = "Recipient", value = author },
			{ name = "Quantity",  value = tostring(amount) }
		}
	})
end

Handlers.add(
	"Get-Dashboard",
	{ Action = "Get-Dashboard" },
	function(msg)
		local tempParticipants = 0
		local tempRewardedTokens = 0
		local tempRank = 0
		local tempReward = 0

		local from = ParseMsgFrom(msg)

		for row in DB:nrows(SQL.TOTAL_PARTICIPANT_REWARDED_TOKENS) do
			tempParticipants = row.total_participants
			tempRewardedTokens = row.total_rewarded_tokens
		end

		for row in DB:nrows(string.format(SQL.FIND_USER_REWARDED_TOKENS, from)) do
			tempReward = row.rewardedTokens
		end

		for row in DB:nrows(string.format(SQL.FIND_USER_RANK, from)) do
			tempRank = row.rank
		end

		-- print("Get-Dashboard(" .. from .. "): " .. Dump(row))
		ao.send({
			Target = from,
			Tags = {
				{ name = "Action", value = "Get-Dashboard-Response" },
				{ name = "status", value = "200" }
			},
			Data = json.encode({
				participants = tempParticipants,
				granted_reward = tempRewardedTokens,
				my_rank = tempRank,
				my_reward = tempReward
			})
		})
	end
)

Handlers.add(
	"Get-Leaderboard",
	{ Action = "Get-Leaderboard" },
	function(msg)
		local from = ParseMsgFrom(msg)

		local data = {}
		local query = SQL.TOTAL_PARTICIPANTS_RANK
		for row in DB:nrows(query) do
			table.insert(data, row)
		end

		ao.send({
			Target = from,
			Tags = {
				{ name = "Action", value = "Get-Leaderboard-Response" },
				{ name = "status", value = "200" }
			},
			Data = json.encode(data)
		})
	end
)

function ParseMsgFrom(msg)
	if msg.Tags.FromAddress ~= nil then
		return msg.Tags.FromAddress
	end
	return msg.From
end
