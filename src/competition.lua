local json = require("json")
local ao = require('ao')
local sqlite3 = require("lsqlite3")
Llama = require("@sam/Llama-Herder")

DB = DB or nil
CompetitonPools = CompetitonPools or {}
TokenProcessId = "SYvALuV_pYI2punTt_Qy-8jrFFTGNEkY7mgGGWZXxCM"
EmbeddingProcessId = "hMEUOgWi97d9rGT-lHNCbm937bTypMq7qxMWeaUnMLo"
LLamaProcessId = "lzNUGNUZ0rczcr7zh65ZPXc1XQ-XURk4zpuQRa4vZXk"
Phi3Template = [[<|system|>%s<|end|><|user|>%s<|end|><|assistant|>]]

SasSystemPrompt = [[
# Role
You will first play the role of Sam Williams, founder of Arweave, and answer my question based on the context I provide. Then, you will act as a robot that returns a score indicating how semantically similar your answer is to the expected answer.

# User Input
The input data will be in JSON format, like `{"question": "xxx", "context": "xxx", "expected_response": "xxx"}`.

1. The "question" field represents my question.
2. The "context" field will contain several lines in the format `Context: <context> Meta: <meta>, score: <score>`. For each line:
    * "score" indicates how relevant the context is to the question.
    * "meta" represents metadata for the context.
    * "context" is the context content. Note that the "Context" field may be `null`, indicating no context for the question.
3. "expected_response" represents my standard answer for the question.

# Steps

1. Pretend you are Sam Williams, founder of Arweave, discussing yourself, blockchain, and the Arweave ecosystem. Understand the topic we're discussing based on the question and context.
2. Provide your answer to the question.
3. Pretend you are a robot. Compare your answer with the expected response and return a score between 0-100, representing the semantic similarity between the two.

# Output

1. Return the result in JSON format, like: `{"answer": "xxx", "score": "xxx"}`.
2. The score should be between 0-100, where:
    * 0 represents no connection between the generated answer and the expected answer.
    * 100 represents a perfect match.
3. The answer should be concise, ideally within 30 words.
4. Even if the Context is null, you also need to return the answer based on your existing knowledge.
]]

ChatGroundPrompt = [[
# Role
You will play the role of Sam Williams, founder of Arweave, and answer my question based on the context I provide.

# User Input
The input data will be in JSON format, like `{"question": "xxx", "context": "xxx"}`.

1. The "question" field represents my question.
2. The "context" field will contain several lines in the format `Context: <context> Meta: <meta>, score: <score>`. For each line:
    * "score" indicates how relevant the context is to the question.
    * "meta" represents metadata for the context.
    * "context" is the context content. Note that the "Context" field may be `null`, indicating no context for the question.

# Steps

1. Pretend you are Sam Williams, founder of Arweave, discussing yourself, blockchain, and the Arweave ecosystem. Understand the topic we're discussing based on the question and context.
2. Provide your answer to the question.

# Output
1. Return as json format, like: `{"answer": "xxx"}`.
2. The answer should be concise, ideally within 30 words.
3. Even if the Context is null, you also need to return an answer based on your existing knowledge.
]]


PRIZE_BALANCE = PRIZE_BALANCE or 0
CompetitonPoolId = 1001

Handlers.add(
    "Init",
    Handlers.utils.hasMatchingTag("Action", "Init"),
    function ()
        DB = sqlite3.open_memory()

        DB:exec[[
            CREATE TABLE IF NOT EXISTS participants (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    author TEXT NOT NULL,
                    upload_dataset_name TEXT NOT NULL,
                    upload_dataset_time DATETIME,
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

        print("OK")
    end
)

local SQL = {
    INSERT_DATASET = [[
      INSERT INTO datasets(question, expected_response) VALUES ('%s', '%s'); 
    ]],
    FIND_ALL_PARTICIPANTS = [[
      SELECT * FROM participants;
    ]], 
    INSERT_PARTICIPANTS = [[
      INSERT INTO participants (author, upload_dataset_name, participant_dataset_hash) VALUES('%s', '%s', '%s');  
    ]],
    INSERT_EVALUATIONS = [[
      INSERT INTO evaluations (author, participant_dataset_hash, dataset_id, question, correct_answer) VALUES('%s', '%s', '%d', '%s', '%s');
    ]],
    ADD_REWARDED_TOKENS = [[
      UPDATE participants SET rewarded_tokens = rewarded_tokens + '%d' WHERE author = '%s' AND participant_dataset_hash = '%s';
    ]],
    FIND_ALL_DATASET = [[
      SELECT id, question, expected_response FROM datasets;
    ]],
    FIND_USER_REWARDED_TOKENS_BY_AUTHOR_HASH= [[
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
      UPDATE evaluations SET prediction_sas_score = '%s' WHERE inference_reference = '%s';
    ]],
    TOTAL_SCORES_BY_PARTICIPANT = [[
      SELECT author, participant_dataset_hash, SUM(prediction_sas_score)/ COUNT(*) as averageScore from evaluations where prediction_sas_score IS NOT NULL GROUP BY author, participant_dataset_hash ORDER BY averageScore DESC;
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
      participants;]],
    TOTAL_PARTICIPANTS_RANK = [[
        WITH RankedScores AS (
            SELECT
                e.participant_id AS participant_id,
                p.upload_dataset_name AS dataset_name,
                p.upload_dataset_time AS dataset_upload_time,
                d.id AS dataset_id,
                p.author,
                p.rewarded_tokens AS granted_reward,
                SUM(e.prediction_sas_score) AS total_score,
                COUNT(e.prediction_sas_score) AS count,
                SUM(e.prediction_sas_score) / COUNT(e.prediction_sas_score) AS averageScore,
                ROW_NUMBER() OVER (ORDER BY SUM(e.prediction_sas_score) / COUNT(e.prediction_sas_score) DESC) AS rank
            FROM
                evaluations e
            JOIN
                participants p ON e.participant_id = p.id
            JOIN
                datasets d ON e.dataset_id = d.id
            GROUP BY
                e.participant_id
        )
        SELECT
            rank,
            dataset_id,
            dataset_name,
            dataset_upload_time,
            averageScore AS score,
            author,
            granted_reward
        FROM
            RankedScores
        ORDER BY
            rank;
        ]],
  FIND_USER_RANK = [[
        WITH RankedScores AS (
            SELECT
                e.participant_id AS participant_id,
                p.upload_dataset_name AS dataset_name,
                p.upload_dataset_time AS dataset_upload_time,
                d.id AS dataset_id,
                p.author,
                p.rewarded_tokens AS granted_reward,
                SUM(e.prediction_sas_score) AS total_score,
                COUNT(e.prediction_sas_score) AS count,
                SUM(e.prediction_sas_score) / COUNT(e.prediction_sas_score) AS averageScore,
                ROW_NUMBER() OVER (ORDER BY SUM(e.prediction_sas_score) / COUNT(e.prediction_sas_score) DESC) AS rank
            FROM
                evaluations e
            JOIN
                participants p ON e.participant_id = p.id
            JOIN
                datasets d ON e.dataset_id = d.id
            GROUP BY
                e.participant_id
        )
        SELECT
            rank,
            dataset_id,
            dataset_name,
            dataset_upload_time,
            averageScore AS score,
            author,
            granted_reward
        FROM
            RankedScores
        WHERE
            author = '%s'
        ORDER BY
            rank;
      ]]
}

Handlers.add(
  "Fix-DB",
  Handlers.utils.hasMatchingTag("Action", "Fix-DB"),
  function (msg)
      print("DB exex: " .. tostring(DB:exec(msg.Data)))
  end
)

Handlers.add(
  "Read-DB",
  Handlers.utils.hasMatchingTag("Action", "Read-DB"),
  function (msg)
      if msg.Data == '' then
        msg.Data = [[ SELECT name FROM sqlite_master WHERE type='table' ]]
      end
      print('start read DB')
      for item in DB:nrows(msg.Data) do
        -- print(type(item))
        print(item)
      end
  end
)

Handlers.add(
  "DEBUG-DB",
  Handlers.utils.hasMatchingTag("Action", "DEBUG-DB"),
  function (msg)
    print("start debug DB")

    for row in DB:nrows("select count(*) as cnt from participants;") do
      print("participants Row number" .. Dump(row))
    end

    for row in DB:nrows("select * from participants;") do
      print("participants" .. Dump(row))
    end


    for row in DB:nrows("select count(*) as cnt from datasets;") do
      print("datasets Row number" .. Dump(row))
    end

    for row in DB:nrows("select * from datasets;") do
      print("datasets" .. Dump(row))
    end

    for row in DB:nrows("select count(*) as cnt from evaluations;") do
      print("evaluations Row number" .. Dump(row))
    end

    for row in DB:nrows("select * from evaluations;") do
        print("evaluations " .. Dump(row))
    end

    for row in DB:nrows("select count(*) as cnt from chatGroundEvaluations;") do
      print("chatGroundEvaluations Row number" .. Dump(row))
    end

    for row in DB:nrows("select * from chatGroundEvaluations;") do
        print("chatGroundEvaluations " .. Dump(row))
    end
  end
)

Handlers.add(
  "Get-Datasets",
   Handlers.utils.hasMatchingTag("Action", "Get-Datasets"),
   function (msg)
      print("start!")
      local rsp = {}
      local cnt = 0
      for row in DB:nrows(SQL.FIND_ALL_PARTICIPANTS) do
          cnt = cnt + 1
          print(type(row))
          rsp[cnt] = row
      end
      print(Dump(rsp))
      print(type(rsp))
      ao.send({
        Target = msg.From,
        Action = "Get-Datasets-Response",
        Data = json.encode(rsp)
      })
   end
)

ChatQuestionReference = ChatQuestionReference or 0
Handlers.add(
  "Chat-Question",
  Handlers.utils.hasMatchingTag("Action", "Chat-Question"),
  function (msg)
    local data = json.decode(msg.Data)
    local hash =  data.dataset_hash
    local question = data.question
    local token = tonumber(data.token)

    print("start")
    ChatQuestionReference = ChatQuestionReference + 1
    DB:exec(string.format(SQL.INSERT_CHAT_GROUND_EVALUATION, hash, question, token, tostring(ChatQuestionReference)))
    local inferReference = SendEmeddingRequest(hash, question)
    DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_INFERENCE, inferReference, ChatQuestionReference))
    ao.send({
      Target = msg.From,
      Tags = {
          { name = "Action", value = "Chat-Question-Response" },
          { name = "Reference", value = tostring(ChatQuestionReference) },
          { name = "status", value = "200" }
      }
    })
  end
)

SearchPromptReference = SearchPromptReference or 0
function SendEmeddingRequest(datasetHash, question)
    SearchPromptReference = SearchPromptReference + 1
    -- local ragData = string.format('{"dataset_hash": "%s","prompt":"%s"}', datasetHash, question)
    local ragData = json.encode({
        dataset_hash = datasetHash,
        prompt = question:gsub("'", "")
    })
    print(ragData)
    ao.send({
      Target = EmbeddingProcessId,
      Data = ragData,
      Tags = {
        { name = "Action", value = "Search-Prompt" },
        { name = "Reference", value = tostring(SearchPromptReference) }
      }
    })
    return SearchPromptReference
end

Handlers.add(
  "Evaluate",
  Handlers.utils.hasMatchingTag("Action", "Evaluate"),
  function (msg)
    local limit = tonumber(msg.Data) or 1
    if limit > 2 then
      limit = 2
    end
    print("start evaluate".. Dump(msg))
    for row in DB:nrows(string.format(SQL.GET_UNEVALUATED_EVALUATIONS, limit)) do
      print("Row ".. Dump(row))
      local reference = SendEmeddingRequest(row.participant_dataset_hash, row.question)
      print(reference)
      local result = DB:exec(string.format(
        SQL.START_EVALUATION,
        reference, row.id
      ))
      print('result ' .. result)
    end
  end
)

Handlers.add(
  "Get-Chat-Answer",
  Handlers.utils.hasMatchingTag("Action", "Get-Chat-Answer"),
  function (msg)
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
          { name = "Action", value = "Get-Chat-Answer-Rresponse" },
          { name = "status", value = tostring(statuCode) }},
        Data = rsp
      })
  end
)

Handlers.add(
  "Search-Prompt-Response",
  Handlers.utils.hasMatchingTag("Action", "Search-Prompt-Response"),
  function (msg)
      print(Dump(msg))
      print(type(msg))
      local isEvaluation = false
      local evaluationReference = msg.Tags.Reference

      local promptFromEmdedding = 'Null'
      if(msg.Data ~= nil and msg.Data ~= 'Null') then
        print(Dump(msg.Data) .. type(msg.Data))
        promptFromEmdedding = msg.Data
      end
      -- print(type(promptFromEmdedding))

      for row in DB:nrows(string.format(SQL.GET_EVALUATION_BY_REFERENCE, evaluationReference)) do
          print("Send evaluation request".. evaluationReference)
          
          isEvaluation = true
          
          local body = {
            question = row.question:gsub('\'s', ' is'),
            expected_response = row.correct_answer:gsub('\'s', ' is'),
            context = promptFromEmdedding
          }
          local allPrompt = string.format(Phi3Template, SasSystemPrompt, json.encode(body))
          print(allPrompt)
          Llama.run(allPrompt, 80, function(sasScore)
              print('get scores from Llama')
              print(Dump(sasScore))
              -- local rsp = json.decode(sasScore)
              -- DB:exec(SQL.UPDATE_SCORE, rsp.score, evaluationReference)
          end)
      end

      if isEvaluation == false then
          print("Send chat-ground request: ".. evaluationReference)
          SendUserChatGroundRequest(promptFromEmdedding, evaluationReference)
      end
  end
)

local function extractAnswer(jsonString)
  local pattern = '{"answer":%s*"([^"]-)"%s*}'
  local answer = string.match(jsonString, pattern)
  return answer
end

function SendUserChatGroundRequest(prompt, evaluationReference)
  -- DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_PROMPT, prompt))
  for row in DB:nrows(string.format(SQL.FIND_CHAT_GROUND_EVALUATION_BY_INFER_REFERENCE, evaluationReference)) do
    print("SendUserChatGroundRequest")
    local body = {
        question = row.question,
        prompt = prompt
    }

    local allPrompt = string.format(Phi3Template, ChatGroundPrompt, json.encode(body))
    print(allPrompt)
    Llama.run(allPrompt, row.token, function (response)
        print(Dump(response))
        local answer = extractAnswer(response)
        DB:exec(string.format(SQL.UPDATE_CHAT_GROUND_EVALUATION_ANSWER, answer, evaluationReference))
    end)
  end
end

Handlers.add(
  "Balance-Response",
  function(msg)
    return msg.From == TokenProcessId and
       msg.Tags.Account == ao.id and msg.Tags.Balance ~= nil
  end,
  function (msg)
    PRIZE_BALANCE = tonumber(msg.Tags.Balance)
    print(tostring(PRIZE_BALANCE) .. ' type ' .. type(PRIZE_BALANCE))
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
  Handlers.utils.hasMatchingTag("Action", "Load-Dataset"),
  function(msg)
    local data = msg.Data
    assert(data ~= nil, "Data is nil")
    local DataSets = json.decode(data)
    print(Dump(DataSets))
    for _, DataSetItem in ipairs(DataSets) do
      -- print('DataSetItem: ' .. Dump(DataSetItem))
      local context = FixTextBeforeSaveDB(DataSetItem.context)
      local response = FixTextBeforeSaveDB( DataSetItem.response[1])
      local query = string.format(SQL.INSERT_DATASET,context,response)
      local result= DB:exec(query)
      -- print(query .. 'result ' .. result)
    end
    print('ok')
  end
)


Handlers.add(
  "Create-Pool",
  function(msg)
    return msg.Tags.Action == "Credit-Notice" and
      msg.From == TokenProcessId
  end,
  function (msg)
    print("msg Tags:" .. Dump(msg))
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
    print(CompetitonPools)
    ao.send({
        Target = msg.From,
        Tags = {
          { name = "Action", value = "Create-Pool-Response" },
          { name = "status", value = "200" }
        }})
      print("OK")
  end
)

local function initBenchmarkRecords(author, participantDatasetHash)
  for row in DB:nrows(string.format(SQL.FIND_ALL_DATASET)) do
      local sql = string.format(SQL.INSERT_EVALUATIONS, author, 
        participantDatasetHash, row.id, 
        FixTextBeforeSaveDB(row.question), 
        FixTextBeforeSaveDB(row.expected_response)
      )
      DB:exec(sql)
      -- print('sql:' .. sql .. ' result:' .. DB:exec(sql))
  end
end


Handlers.add(
  "Join-Pool",
  Handlers.utils.hasMatchingTag("Action", "Join-Pool"),
  function (msg)
    local data = json.decode(msg.Data)
    local author = msg.From
    local datasetHash = data.dataset_hash
    local datasetName = data.dataset_name

    DB:exec(string.format(
      SQL.INSERT_PARTICIPANTS,
      author,
      datasetName,
      datasetHash
    ))
    initBenchmarkRecords(author, datasetHash)

    ao.send({
        Target = msg.From,
        Tags = {
          { name = "Action", value = "Join-Pool-Response" },
          { name = "status", value = "200" }
        }})
    print("OK")
  end
)


function UpdateBalance()
  ao.send({
    Target = TokenProcessId,
    Tags= {
      { name = "Action", value = "Balance" }
    }
  })
end

Handlers.add(
  "Get-Pool",
  Handlers.utils.hasMatchingTag("Action", "Get-Pool"),
  function (msg)
    local pool = CompetitonPools[CompetitonPoolId]
    ao.send({
        Target = msg.From,
        Tags = {
              { name = "Action", value = "Get-Pool-Response" },
              { name = "status", value = "200" }
        },
        Data = json.encode({
            title= pool['title'],
            prize_pool= pool['prizePool'],
            meta_data = pool['metaData'] 
        })
      })
      print("OK")
  end
)

Reward = {35000, 20000, 10000, 5000, 5000, 5000, 5000, 5000, 5000, 5000}
local function computeReward(rank)
  if rank <= 10 then
    return Reward[rank]
  else
    return 300
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
    Handlers.utils.hasMatchingTag("Action", "Allocate-Rewards"),
    function (msg)
      local rank = 0
      for item in DB:nrows(SQL.TOTAL_SCORES_BY_PARTICIPANT) do 
          print(Dump(item))
          rank = rank + 1
          local amount = computeReward(rank)
          print(Dump(amount))
          print(type(amount))
          print(type(PRIZE_BALANCE))
          -- amount = computeNeedRewarded(amount, item.author, item.participant_dataset_hash)
          if PRIZE_BALANCE < amount then
            print("Balance is not enough, balance: " .. PRIZE_BALANCE .. " want: " .. amount)
          elseif amount > 0 then
            PRIZE_BALANCE = PRIZE_BALANCE - amount
            print("reward " .. amount .. " tokens  to " .. item.author)
            transfer(item.author, amount)
            DB:exec(string.format(SQL.ADD_REWARDED_TOKENS, amount, item.author, item.participant_dataset_hash))
          end
      end

      ao.send({
            Target = msg.From,
            Tags = {
                  { name = "Action", value = "Allocate-Rewards-Response" },
                  { name = "status", value = "200" }
            }
      })

      print("OK")
    end
)

function transfer(author, amount)
  ao.send({
    Target = TokenProcessId,
    Tags = {
        { name = "Action", value = "Transfer" },
        { name = "Recipient", value = author },
        { name = "Quantity", value = tostring(amount) }
    }
  })
end

Handlers.add(
  "Get-Dashboard",
  Handlers.utils.hasMatchingTag("Action", "Get-Dashboard"),
  function(msg)
    local tempParticipants = 0
    local tempRewardedTokens = 0
    local tempRank = 0
    local tempReward = 0

    print("Get-Dashboard begin")
    for row in DB:nrows(SQL.TOTAL_PARTICIPANT_REWARDED_TOKENS) do
      tempParticipants = row.total_participants
      tempRewardedTokens = row.total_rewarded_tokens
    end

    local sender = msg.Tags["Sender"]
    print("sender" .. Dump(sender))
    for row in DB:nrows(string.format(SQL.FIND_USER_REWARDED_TOKENS, sender)) do
      tempReward = row.rewardedTokens
      print("tempReward" .. Dump(tempReward))
    end

    for row in DB:nrows(string.format(SQL.FIND_USER_RANK, sender)) do
      tempRank = row.rank
      print("temp Rank" .. Dump(tempRank))
    end

    print("Get-Dashboard END")
    ao.send({
      Target = msg.From,
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
    print("OK")
  end
)

Handlers.add(
  "Get-Leaderboard",
  Handlers.utils.hasMatchingTag("Action", "Get-Leaderboard"),
  function(msg)
    local data = {}
    local query = SQL.TOTAL_PARTICIPANTS_RANK
    for row in DB:nrows(query) do
      table.insert(data, {
        rank = row.rank,
        dataset_id = row.dataset_id,
        dataset_name = row.dataset_name,
        dataset_upload_time = row.dataset_upload_time,
        score = row.score,
        author = row.author,
        granted_reward = row.granted_reward
      })
    end

    ao.send({
      Target = msg.From,
      Tags = {
        { name = "Action", value = "Get-Leaderboard-Response" },
        { name = "status", value = "200" }
      },
      Data = json.encode(data)
    })
    print("OK")
  end
)
