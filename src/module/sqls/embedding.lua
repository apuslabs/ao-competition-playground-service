local DB = require("module.utils.db")
local Helper = require("module.utils.helper")
local SQL = {}

SQL.DATABASE = [[
    CREATE TABLE IF NOT EXISTS contents (
        id INTEGER PRIMARY KEY,
        dataset_hash TEXT NOT NULL,
        content TEXT NOT NULL,
        embeded INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS prompts (
        id INTEGER PRIMARY KEY,
        reference TEXT NOT NULL,
        dataset_hash TEXT NOT NULL,
        sender TEXT NOT NULL,
        prompt_text TEXT NOT NULL,
        retrieve_result TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_prompts_retrieve_result ON prompts(retrieve_result);
]]

SQL.init = function(client)
    DB:init(client)
    DB:exec(SQL.DATABASE)
end

SQL.CreateDocuments = function(dataset_hash, documents)
    assert(documents and #documents > 0, "Missing documents")
    local data = {}
    for _, document in ipairs(documents) do
        table.insert(data, {
            dataset_hash = dataset_hash,
            content = document,
        })
    end
    return DB:batchInsert("contents", data)
end

SQL.GetUnembededDocuments = function()
    return DB:query("contents", {
        embeded = 0
    }, {
        limit = 20
    })
end

SQL.BatchSetDocumentsEmbebed = function(ids)
    assert(ids and #ids > 0, "Missing ids")
    return DB:exec(string.format("UPDATE contents SET embeded = 1 WHERE id IN (%s);", table.concat(ids, ",")))
end

SQL.AddPrompt = function(reference, sender, dataset_hash, prompt_text)
    Helper.assert_non_empty(reference, sender, dataset_hash, prompt_text)
    return DB:insert("prompts", {
        reference = reference,
        sender = sender,
        dataset_hash = dataset_hash,
        prompt_text = prompt_text,
    })
end

SQL.GetToRetrievePrompt = function()
    return DB:query("prompts", {
        retrieve_result = "__NULL"
    }, {
        limit = 10
    })
end

SQL.SetRetrieveResult = function(reference, sender, result)
    Helper.assert_non_empty(reference, sender, result)
    return DB:update("prompts", {
        retrieve_result = result
    }, {
        reference = reference,
        sender = sender
    })
end

SQL.GetRetrievePrompt = function(sender, reference)
    Helper.assert_non_empty(sender, reference)
    return DB:query("prompts", {
        sender = sender,
        reference = reference
    })
end

SQL.ClearContents = function()
    return DB:exec("DELETE FROM contents;")
end

SQL.ClearPrompts = function()
    return DB:exec("DELETE FROM prompts;")
end

return SQL
