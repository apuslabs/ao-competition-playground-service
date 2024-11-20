local DB = require("module.utils.db")
local Helper = require("module.utils.helper")
local datetime = require("module.utils.datetime")
local Lodash = require("module.utils.lodash")
local SQL = {}
HashInitDB = HashInitDB or false

local function escape_string(str)
    return str:gsub("'", "''")
end

SQL.DATABASE = [[
    INSERT INTO temp.lembed_models(name, model) 
        select 'all-MiniLM-L6-v2', lembed_model_from_file('/data/M-OzkyjxWhSvWYF87p0kvmkuAEEkvOzIj4nMNoSIydc');
    select lembed(
        'all-MiniLM-L6-v2',
        'The United States Postal Service is an independent agency...'
    );
    create table articles(
        headline text not null,
        dataset_hash text not null,
        created_at integer
    );

    -- Build a vector table with embeddings of article headlines
    create virtual table vec_articles using vec0(
        headline_embeddings float[1600]
    );
]]

SQL.init = function(client)
    DB:init(client)
    if not HashInitDB then
        HashInitDB = true
        DB:exec(SQL.DATABASE)
    end
end

SQL.BatchInsert = function(dataset_hash, articles)
    local insertList = {}
    for _, article in ipairs(articles) do
        table.insert(insertList, {
            headline = article,
            dataset_hash = dataset_hash,
            created_at = datetime.unix()
        })
    end
    local rc = DB:batchInsert("articles", insertList)
    assert(rc == 0, "Insert dataset failed")
    return DB:exec([[
    insert into vec_articles(rowid, headline_embeddings)
        select rowid, lembed('all-MiniLM-L6-v2', headline) from articles where dataset_hash = ']] .. dataset_hash .. "';")
end

SQL.TestLembed = function(dataset_hash)
    return DB:nrows("select rowid, dataset_hash, lembed('all-MiniLM-L6-v2', headline) from articles where dataset_hash = '" .. dataset_hash .. "';")
end

SQL.GetArticles = function(dataset_hash)
    Helper.assert_non_empty(dataset_hash, "dataset_hash")
    return DB:query("articles", { dataset_hash = dataset_hash })
end

SQL.Match = function(dataset_hash, prompt, limit)
    Helper.assert_non_empty(dataset_hash, prompt)
    assert(prompt, "prompt is required")
    assert(limit, "limit is required")
    local query = [[
    with matches as (
        select
            rowid,
            distance
        from vec_articles
        where rowid IN (
            select rowid from articles where dataset_hash = ']] .. dataset_hash .. [['
        ) and headline_embeddings match lembed('all-MiniLM-L6-v2', ']] .. escape_string(prompt) .. [[')
        order by distance
        limit ]] .. limit .. [[
    )
    select
        headline,
        distance
    from matches
        left join articles on articles.rowid = matches.rowid;
    ]]
        
    return Lodash.map(DB:nrows(query), function(row)
        return row.headline
    end)
end

function TestMatch()
    return require('json').encode(SQL.Match("ee17560c8b77385b5bb8d8687820f9b82f3fdcdf", "What is the ultimate legacy of Walter White's actions by the series' end?", 3))
end

return SQL