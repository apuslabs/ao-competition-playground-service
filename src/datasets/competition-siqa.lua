local sqlite3 = require("lsqlite3")
local json = require('json')
Llama = require("@sam/Llama-Herder")

DB = DB or nil

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
                    upload_dataset_time DATETIME,
                    dataset_file_hash TEXT
                );
            
            CREATE TABLE datasets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    context TEXT NOT NULL,
                    question TEXT NOT NULL,
                    answerA TEXT NOT NULL,
                    answerB TEXT NOT NULL,
                    answerC TEXT NOT NULL,
                    result TEXT NOT NULL
                );

            CREATE TABLE evaluations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    dataset_id INTEGER NOT NULL,
                    prompt TEXT NOT NULL,
                    correct_answer TEXT NOT NULL,
                    prediction TEXT,
                    prediction_sas_score INTEGER,
                    inference_start_time DATETIME,
                    inference_end_time DATETIME,
                    inference_reference TEXT,
                    FOREIGN KEY (dataset_id) REFERENCES datasets(id)
                );
        ]]
        print("OK")
    end
)

local SQL = {
    INSERT_DATASET = [[
      INSERT INTO datasets (context, question, answerA, answerB, answerC, result) VALUES ('%s', '%s', '%s', '%s', '%s', '%s');
    ]]
}

Handlers.add(
  "Load-Data",
  Handlers.utils.hasMatchingTag("Action", "Load-QA-Data"),
  function(msg)
    -- Handlers.utils.reply("start Load-Data!!!!!!")(msg)
    local data = msg.Data
    assert(data ~= nil, "Data is nil")
    local DataSets = json.decode(data)
    for _, DataSetItem in ipairs(DataSets) do
      local query = string.format(
        SQL.INSERT_DATASET,
        DataSetItem.context,
        DataSetItem.expected_response[1]
      )
      DB:exec(query)
    end
    print('ok')
  end
)
