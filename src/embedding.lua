local sqlite3 = require("lsqlite3")
local json = require("json")
DB = DB or nil


local function escape_string(str)
    return string.gsub(str, "'", "''")
end

Handlers.add(
    "Init",
    { Action = "Init" },
    function()
        -- DataSets = weave.getJsonData(DataTxID)
        DB = sqlite3.open_memory()

        DB:exec [[
      CREATE TABLE contents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dataset_hash TEXT NOT NULL,
          content TEXT NOT NULL,
          meta TEXT,
          embeded INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE prompts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reference TEXT NOT NULL,
          dataset_hash TEXT NOT NULL,
          sender TEXT NOT NULL,
          prompt_text TEXT NOT NULL,
          retrieve_result TEXT
      );
    ]]

        print("ok")
    end
)

local SQL = {
    INSERT_DOCUMENTS = [[
    INSERT INTO contents (dataset_hash, content, meta) VALUES ('%s', '%s', '%s');
  ]],
    GET_UNEMBEDED_DOCUMENTS = [[
    SELECT * FROM contents WHERE embeded = 0;
  ]],
    BATCH_SET_DOCUMENTS_EMBEDED = [[
    UPDATE contents SET embeded = 1 WHERE id IN (%s);
  ]],
    ADD_PROMPT = [[
    INSERT INTO prompts (reference, sender, dataset_hash, prompt_text) VALUES ('%s', '%s', '%s', '%s');
  ]],
    GET_TORETRIEVE_PROMPT = [[
    SELECT * FROM prompts WHERE retrieve_result IS NULL;
  ]],
    GET_RETRIEVE_PROMPT = [[
    SELECT * FROM prompts WHERE sender = '%s' AND reference = '%s';
  ]],
    SET_RETRIEVE_RESULT = [[
    UPDATE prompts SET retrieve_result = '%s' WHERE reference = '%s' and sender = '%s';
  ]]
}

local lastSubmissionTime = 0
local fiveMinutes = 1 * 60

Handlers.add("Create-Dataset", { Action = "Create-Dataset" }, function(msg)
    local currentTime = math.floor(msg.Timestamp / 1000)
    if (currentTime - lastSubmissionTime) < fiveMinutes then
        ao.send({
            Target = msg.From,
            Tags = {
                { name = "Action", value = "Join-Pool-Response" },
                { name = "status", value = "429" }
            },
            Data = "Processing data. Try again in five minutes."
        })
        print("Processing data. Try again in five minutes.")
        return
    end

    lastSubmissionTime = currentTime

    local data = json.decode(msg.Data)
    assert(data, "Invalid data")
    -- hash exists and not empty
    assert(data.hash and #data.hash > 0, "Invalid hash")
    assert(data.list, "Missing list in data")
    for _, DataSetItem in ipairs(data.list) do
        -- assert(DataSetItem.content, "Missing content in DataSetItem")
        -- local meta = DataSetItem.meta or {}
        local query = string.format(
            SQL.INSERT_DOCUMENTS,
            data.hash,
            escape_string(DataSetItem),
            ""
        )
        DB:exec(query)
    end
    Handlers.utils.reply("Dataset created " .. #data.list .. " successfully")(msg)
    print("Dataset created successfully")
end)

Handlers.add("Get-Unembeded-Documents", { Action = "Get-Unembeded-Documents" },
    function(msg)
        local docs = {}
        for row in DB:nrows(SQL.GET_UNEMBEDED_DOCUMENTS) do
            table.insert(docs, row)
        end
        Handlers.utils.reply(json.encode(docs))(msg)
    end)

Handlers.add("Embedding-Data", { Action = "Embedding-Data" }, function(msg)
    local ids = json.decode(msg.Data)
    assert(ids, "Invalid data")
    assert(type(ids) == "table", "Data should be a table of IDs")
    local id_list = {}
    for _, id in ipairs(ids) do
        table.insert(id_list, id)
    end
    local id_str = table.concat(id_list, ", ")
    local query = string.format(SQL.BATCH_SET_DOCUMENTS_EMBEDED, id_str)
    DB:exec(query)
    Handlers.utils.reply(json.encode(#id_list))(msg)
end)

Handlers.add("Search-Prompt", { Action = "Search-Prompt" }, function(msg)
    local data = json.decode(msg.Data)
    assert(msg.Tags.Reference and #msg.Tags.Reference ~= 0, "Missing reference in tags")
    local PromptReference = msg.Tags.Reference
    assert(data.dataset_hash, "Missing dataset hash in data")
    assert(data.prompt, "Missing search prompt")
    local query = string.format(SQL.ADD_PROMPT, escape_string(tostring(PromptReference)), msg.From or "anonymous",
        escape_string(data.dataset_hash), escape_string(data.prompt))
    DB:exec(query)
    print(msg.From .. " Prompt " .. PromptReference .. " added successfully")
end)

Handlers.add("GET-TORETRIEVE-PROMPT", { Action = "GET-TORETRIEVE-PROMPT" }, function(msg)
    local prompts = {}
    for row in DB:nrows(SQL.GET_TORETRIEVE_PROMPT) do
        table.insert(prompts, row)
    end
    Handlers.utils.reply(json.encode(prompts))(msg)
end)

Handlers.add("Set-Retrieve-Result",{ Action = "Set-Retrieve-Result" } , function(msg)
    local data = json.decode(msg.Data)
    for _, item in ipairs(data) do
        -- assert(item.id, "Missing id in item")
        assert(item.sender, "Missing sender in item")
        assert(item.reference, "Missing reference in item")
        assert(item.retrieve_result, "Missing result in item")
        print("Set Retrieve Result for" .. item.sender .. "  " .. item.reference)
        local query = string.format(SQL.SET_RETRIEVE_RESULT, escape_string(item.retrieve_result), item.reference, item.sender)
        DB:exec(query)
        if (item.sender == "anonymous") then
            return
        end
        Send({
            Target = item.sender,
            Tags = {
                Action = "Search-Prompt-Response",
                Reference = item.reference
            },
            Data = item.retrieve_result
        })
    end
end)

Handlers.add("GET-Retrieve-Result", { Action = "GET-Retrieve-Result" }, function(msg)
    assert(msg.Tags.Reference and #msg.Tags.Reference ~= 0, "Missing reference in tags")
    assert(msg.Tags.Sender and #msg.Tags.Sender ~= 0, "Missing sender in tags")
    local prompts = {}
    for row in DB:nrows(string.format(SQL.GET_RETRIEVE_PROMPT, msg.Tags.Sender, msg.Tags.Reference)) do
        table.insert(prompts, row)
    end
    Handlers.utils.reply(json.encode(prompts))(msg)
end)

function testCreateData()
    Send({
        Target = ao.id,
        Tags = {
            Action = "Create-Dataset"
        },
        Data = json.encode({
            hash = "123456",
            list = { {
                content = "What's MMBNTVO? It's a test for rag.",
            } }
        })
    })
end

function testSearch()
    Send({
        Target = ao.id,
        Tags = {
            Action = "Search-Prompt",
            Reference = "123456"
        },
        Data = json.encode({
            dataset_hash = "123456",
            prompt = "What's MMBNTVO?"
        })
    })
end
