local DB = require("module.utils.db")
local Helper = require("module.utils.helper")
local datetime = require("module.utils.datetime")
local SQL = {}

SQL.hasInit = false

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
        dataset_hash text not null,
        headline_embeddings float[1600]
    );

    -- Create a trigger to automatically generate embeddings
    create trigger after_insert_articles
    after insert on articles
    begin
        insert into vec_articles(rowid, dataset_hash, headline_embeddings)
            select new.rowid, new.dataset_hash, lembed('all-MiniLM-L6-v2', new.headline);
    end;
]]

SQL.init = function(client)
    if not SQL.hasInit then
        DB:init(client)
        DB:exec(SQL.DATABASE)
        SQL.hasInit = true
    end
end

SQL.BatchInsert = function(dataset_hash, articles)
    local insertList = {}
    for _, article in ipairs(articles) do
        table.insert(insertList, {
            headline = article,
            dataset_hash = dataset_hash,
            created_at = datetime.now()
        })
    end
    return DB:batchInsert("articles", articles)
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
        where dataset_hash = ']] .. dataset_hash .. [[' and
            headline_embeddings match lembed('all-MiniLM-L6-v2', ']] .. prompt .. [[')
        order by distance
        limit ]] .. limit .. [[
    )
    select
        headline,
        distance
    from matches
        left join articles on articles.rowid = matches.rowid;
    ]]
    local result = {}
    for row in DBClient:nrows(query) do
        table.insert(result, row)
    end
    return result
end

return SQL