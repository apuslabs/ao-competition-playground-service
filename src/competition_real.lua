local json = require("json")
local ao = require('ao')
local sqlite3 = require("lsqlite3")
Llama = require("@sam/Llama-Herder")

DB = DB or nil
CompetitonPools = CompetitonPools or {}
TokenProcessId = "SYvALuV_pYI2punTt_Qy-8jrFFTGNEkY7mgGGWZXxCM"
EmbeddingProcessId = "hMEUOgWi97d9rGT-lHNCbm937bTypMq7qxMWeaUnMLo"
Phi3Template = [[<|system|>
                %s<|end|>
                <|user|>
                %s<|end|>]]

SasSystemPrompt =  [[You are a helpful assistant that can compute the SAS(semantic answer similarity) score.
                    You can compute a score between 0~100 based on the SAS, 0 means totally different, 100 means almost the same.
                    Now the user will send you: 
                    1. one Question
                    2. the Context for the question
                    3. an ExpectedResponse
                    pls:
                    1. generate a Response for the Question based on the provided Context.
                    2. compute the SAS score between the provided ExpectedResponse with the Response generated.
                    **Important**You must return as this format: {<the-sas-score>}]]
PRIZE_BALANCE = PRIZE_BALANCE or 0
CompetitonPoolId = 1001

Handlers.add(
    "Init",
    Handlers.utils.hasMatchingTag("Action", "Init"),
    function ()
        DB = sqlite3.open_memory()

        DB:exec[[
            CREATE TABLE participants (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    author TEXT NOT NULL,
                    upload_dataset_name TEXT NOT NULL,
                    upload_dataset_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    participant_dataset_hash TEXT,
                    rewarded_tokens INTEGER DEFAULT 0
                );
            
            CREATE TABLE datasets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    context TEXT,
                    question TEXT,
                    expected_response TEXT
            );

            CREATE TABLE evaluations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
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
                    FOREIGN KEY (participant_id) REFERENCES participants(id)
                    FOREIGN KEY (dataset_id) REFERENCES datasets(id)
                );

            CREATE TABLE chatGroundEvaluations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    dataset_hash TEXT,
                    prompt TEXT,
                    token INTEGER,
                    response TEXT,
                    inference_start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
                    inference_end_time DATETIME,
                    inference_reference TEXT,
                    client_reference TEXT
            );
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
      INSERT INTO evaluations (participant_id, participant_dataset_hash, dataset_id, question, correct_answer) VALUES('%s', '%s', '%s','%s', '%s');
    ]],
    ADD_REWARDED_TOKENS = [[
      UPDATE participants SET rewarded_tokens = rewarded_tokens + '%d'
    ]],
    FIND_ALL_DATASET = [[
      SELECT id, question, expected_response FROM datasets;
    ]],
    FIND_USER_REWARDED_TOKENS= [[
      SELECT rewarded_tokens as rewardedTokens from participants WHERE author = '%s';
    ]],
    GET_UNEVALUATED_EVALUATIONS = [[
      SELECT * FROM evaluations WHERE inference_start_time IS NULL LIMIT %d;
    ]],
    START_EVALUATION = [[
      UPDATE evaluations SET inference_start_time = CURRENT_TIMESTAMP, inference_reference = '%d' WHERE id = '%d';
    ]],
    END_EVALUATION = [[
      UPDATE evaluations SET inference_end_time = CURRENT_TIMESTAMP, prediction = '%s' WHERE inference_reference = '%s';
    ]],
    GET_EVALUATION_BY_REFERENCE = [[
      SELECT * FROM evaluations WHERE inference_reference = '%s';
    ]],
    UPDATE_SCORE = [[
      UPDATE evaluations SET prediction_sas_score = '%s' WHERE inference_reference = '%s';
    ]],
    TOTAL_SCORES_BY_PARTICIPANT = [[
      SELECT participant_id as author, SUM(prediction_sas_score) as score, COUNT(*) as count
      , SUM(prediction_sas_score) /  COUNT(*) as averageScore FROM evaluations 
      GROUP BY participant_id
      ORDER BY averageScore DESC
    ]],
    INSERT_CHAT_GROUND_EVALUATION = [[
      INSERT INTO chatGroundEvaluations(dataset_hash, prompt, token, inference_reference) VALUES('%s', '%s', '%d', '%s');
    ]]
}

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
        print("row start" .. Dump(row))
        evaluations_cnt = evaluations_cnt + 1
        -- evaluations[evaluations_cnt] = Dump(row)
    end
  end
)

Handlers.add(
  "Get-Participants",
   Handlers.utils.hasMatchingTag("Action", "Get-Participants"),
   function (msg)
      Handlers.utils.reply("start participants")
      local rsp = {}
      for row in DB:nrows(SQL.FIND_ALL_PARTICIPANTS) do
          Handlers.utils.reply(type(row))
          rsp[#rsp+1] = row
      end
      ao.Send({
        Target = msg.From,
        Action = "Get-Participants-Response",
        Data = json.encode(rsp)
      })
   end
)

ChatQuestionReference = 0

Handlers.add(
  "Chat-Question",
  Handlers.utils.hasMatchingTag("Action", "Chat-Question"),
  function (msg)
    local data = json.decode(msg.Data)
    local hash =  data.dataset_hash
    local prompt = data.prompt
    local token = data.token

    ChatQuestionReference = ChatQuestionReference + 1
    DB:exec(string.format(SQL.INSERT_CHAT_GROUND_EVALUATION, hash, prompt, token, ChatQuestionReference))

    -- TODO

    ao.Send({
      Target = msg.From,
      Tags = {
          { name = "Action", value = "Chat-Question-Response" },
          { name = "Reference", value = tostring(ChatQuestionReference) },
          { name = "status", value = "200" }
      }
    })
  end
)

SearchPromptReference = 0
function SendEmeddingRequest(ragData)
    ChatQuestionReference = ChatQuestionReference + 1
    ao.Send({
      Target = EmbeddingProcessId,
      Data = ragData,
      Tags = {
        { name = "Action", value = "Search-Prompt" },
        { name = "Reference", value = ChatQuestionReference }
      },
    })
    return ChatQuestionReference
end


Handlers.add(
  "Evaluate",
  Handlers.utils.hasMatchingTag("Action", "Evaluate"),
  function (msg)
    local limit = tonumber(msg.Data) or 2
    print("start evaluate".. Dump(msg) .. tostring(limit))
    for row in DB:nrows(string.format(SQL.GET_UNEVALUATED_EVALUATIONS, limit)) do
      print("Row ".. Dump(row))
      local ragData = string.format('{"dataset_hash": "%s","prompt":"%s"}', row.participant_dataset_hash, row.question)
      local reference = SendEmeddingRequest(ragData)
      print(reference)
      DB:exec(string.format(
        SQL.START_EVALUATION,
        reference, row.id
      ))
      end
  end
)

Handlers.add(
  "Search-Prompt-Response",
  Handlers.utils.hasMatchingTag("Action", "Search-Prompt-Response"),
  function (msg)
      local evaluationReference = msg.Tags.Reference
      for row in DB:nrows(string.format(SQL.GET_EVALUATION_BY_REFERENCE, evaluationReference)) do
          local data = json.decode(msg.Data)

          local sentences = " Question: " ..  row.question .. ", Context: " .. data.prompt .. ", ExpectedResponse: " .. row.correct_answer
          local prompt = string.format(Phi3Template, SasSystemPrompt, sentences)
          Llama.run(prompt, 3, function(sasScore)
              print("Sas score:" .. sasScore .. "\n")
              DB:exec(SQL.UPDATE_SCORE, extractSasScore(sasScore), evaluationReference)
          end)
        -- end)
      end
  end
)

Handlers.add(
  "Balance-Response",
  function(msg)
    return msg.From == TokenProcessId and
       msg.Tags.Account == ao.id and msg.Tags.Balance ~= nil
  end,
  function (msg)
    print("Updated Balance:" .. msg.Tags.Balance)
    PRIZE_BALANCE = msg.Tags.Balance
  end
)

Handlers.add(
  "Load-Dataset",
  Handlers.utils.hasMatchingTag("Action", "Load-Dataset"),
  function(msg)
    local data = msg.Data
    assert(data ~= nil, "Data is nil")
    local DataSets = json.decode(data)
    for _, DataSetItem in ipairs(DataSets) do
      local query = string.format(
        SQL.INSERT_DATASET,
        DataSetItem.context,
        DataSetItem.response[1]
      )
      DB:exec(query)
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
    -- TODO
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

local function initBenchmarkRecords(participantId, participantDatasetHash)
  for row in DB:nrows(string.format(SQL.FIND_ALL_DATASET)) do
      DB:exec(string.format(SQL.INSERT_EVALUATIONS, 
                participantId, participantDatasetHash, row.id, row.question, row.expected_response))
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

local reward = {35, 20, 10, 5, 5, 5, 5, 5, 5, 5}
local function computeReward(rank)
  if rank <= 10 then
    return reward[rank] * PRIZE_BALANCE / 100
  else
    return 300
  end
end

local function computeNeedRewarded(author, amount)
  for rewardTokens in DB:nrows(string.format(SQL.FIND_USER_REWARDED_TOKENS, author)) do
    return amount - rewardTokens
  end
  return amount
end

Handlers.add(
    "Allocate-Rewards",
    Handlers.utils.hasMatchingTag("Action", "Allocate-Rewards-Response"),
    function (msg)
      local rank = 0
      for item in DB:nrows(SQL.TOTAL_SCORES_BY_PARTICIPANT) do 
          rank = rank + 1
          local amount = computeReward(rank)
          amount = computeNeedRewarded(item.participant_id)
          if PRIZE_BALANCE < amount then
            print("Balance is not enough, balance: " .. PRIZE_BALANCE .. " want: " .. amount)
          elseif amount > 0 then
            PRIZE_BALANCE = PRIZE_BALANCE - amount
            transfer(item.participant_id, amount)
            DB:exec(SQL.ADD_REWARDED_TOKENS, amount)
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
        { name = "Quantity", value = amount }
    }
  })
end

Handlers.add(
    "Get-Dashboard",
    Handlers.utils.hasMatchingTag("Action", "Get-Dashboard"),
    function (msg)
        -- TODO @Json
        ao.send({
            Target = msg.From,
            Tags = {
                  { name = "Action", value = "Get-Dashboard-Response" },
                  { name = "status", value = "200" }
            },
            Data = json.encode({
                participants = 1500,
                granted_reward = 5000,
                my_rank = 3,
                my_reward = 300
            })
      })
      print("OK")
    end
)

Handlers.add(
    "Get-Leaderboard",
    Handlers.utils.hasMatchingTag("Action", "Get-Leaderboard"),
    function (msg)
        -- TODO @Json
        local data = json.encode({
            {
                rank = 1,
                dataset_id = 10,
                dataset_name = "a good dataset",
                dataset_upload_time = 1722254056,
                score = 65,
                author = "ewewrerr",
                granted_reward = 0
            },
            {
                rank = 2,
                dataset_id = 12,
                dataset_name = "a bad dataset",
                dataset_upload_time = 1722254059,
                score = 60,
                author = "ewewrerreewdddd",
                granted_reward = 0
            }
        });
        ao.send({
            Target = msg.From,
            Tags = {
                  { name = "Action", value = "Get-Leaderboard-Response" },
                  { name = "status", value = "200" }
            },
            Data = data
      })
      print("OK")
    end
)
