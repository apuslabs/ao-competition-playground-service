-- sqlite

local json = require("json")
local base64 = require(".base64")
Log = require("module.utils.log")
Config = require("module.utils.config")
local Lodash = require("module.utils.lodash")

local sqlite3 = require("lsqlite3")
SQL = require("module.sqls.embedding")
DBClient = DBClient or sqlite3.open_memory()
SQL.init(DBClient)

function Init()
    Send({
        Target = Config.Process.Embedding,
        Action = "Init-Response",
    })
end

function CreateDatasetHandler(msg)
    local data = json.decode(msg.Data)
    local articles = json.decode(base64.decode(data.list))
    local rc = SQL.BatchInsert(data.hash, articles)
    if rc ~= 0 then
        Log.error(string.format("Insert dataset failed: %s %s", data.hash))
        return
    end
    Send({
        Target = Config.Process.Competition,
        Action = "Join-Competition",
        Data = data.hash
    })
    Log.trace(string.format("Create dataset %s", data.name))
end

function SearchPromptHandler(msg)
    local data = json.decode(msg.Data)
    local result = SQL.Match(data.dataset_hash, data.prompt, 3)
    msg.reply({ Status = "200", Data = Lodash.join(result, "\n") })
    Log.trace(string.format("Search prompt %s %s", data.dataset_hash, data.prompt))
end

Handlers.add("Create-Dataset", "Create-Dataset", CreateDatasetHandler)

Handlers.add("Search-Prompt", "Search-Prompt", SearchPromptHandler)
