local DB = require("module.utils.db")
local Helper = require("module.utils.helper")
local datetime = require("module.utils.datetime")
local SQL = {}

SQL.DATABASE = [[
    CREATE TABLE IF NOT EXISTS chats (
    	reference TEXT PRIMARY KEY,
    	dataset_hash TEXT NOT NULL,
    	question TEXT NOT NULL,
    	response TEXT,
        created_at INTEGER,
    	response_at DATETIME,
    );
]]

SQL.init = function(client)
    DB:init(client)
    DB:exec(SQL.DATABASE)
end

SQL.CreateChat = function(reference, dataset_hash, question)
    Helper.assert_non_empty(dataset_hash, question)
    return DB:insert("chats", {
        reference = reference,
        dataset_hash = dataset_hash,
        question = question,
        inference_start_time = datetime.unix(),
    })
end

SQL.SetResponse = function(reference, response)
    Helper.assert_non_empty(reference, response)
    return DB:update("chats", {
        response = response,
        response_at = datetime.unix(),
    }, {
        reference = reference,
    })
end

SQL.GetChat = function(reference)
    Helper.assert_non_empty(reference)
    return DB:queryOne("chats", {
        reference = reference,
    })
end

return SQL
