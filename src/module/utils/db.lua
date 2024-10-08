local json = require("json")
local log = require("module.utils.log")
local DB = { Client = nil }

DB.init = function(self, client)
    self.Client = client
end

DB.exec = function(self, sql)
    assert(self.Client, "Database client is not initialized")
    log.trace("Executing query\n", sql)
    return self.Client:exec(sql)
end

DB.nrows = function(self, sql)
    assert(self.Client, "Database client is not initialized")
    local result = {}
    log.trace("Executing query\n", sql)
    for row in self.Client:nrows(sql) do
        table.insert(result, row)
    end
    return result
end

DB.nrow = function(self, sql)
    assert(self.Client, "Database client is not initialized")
    local result = {}
    log.trace("Executing query: ", sql)
    for row in self.Client:nrows(sql) do
        result = row
        break
    end
    return result
end

local function escape_string(str)
    return str:gsub("'", "''")
end

local function prepare_arg(arg)
    if type(arg) == "table" then
        return string.format("'%s'", json.encode(arg))
    elseif type(arg) == "string" then
        return string.format("'%s'", escape_string(arg))
    end
    return tostring(arg)
end

local function prepare_columns_values_for_insert(data)
    local columns = {}
    local values = {}
    for k, v in pairs(data) do
        table.insert(columns, k)
        table.insert(values, prepare_arg(v))
    end
    return table.concat(columns, ","), table.concat(values, ",")
end

DB.insert = function(self, tableName, data)
    assert(self.Client, "Database client is not initialized")
    local columns, values = prepare_columns_values_for_insert(data)
    local query = string.format("INSERT INTO %s (%s) VALUES (%s);", tableName, columns, values)
    return self:exec(query)
end

DB.batchInsert = function(self, tableName, data)
    assert(self.Client, "Database client is not initialized")
    assert(#data > 0, "Data should be a non-empty table")
    local columns = ""
    local values = {}
    for _, row in ipairs(data) do
        local columns_string, values_string = prepare_columns_values_for_insert(row)
        if columns == "" then
            columns = columns_string
        elseif columns ~= columns_string then
            error("Columns are not the same")
        end
        table.insert(values, string.format("(%s)", values_string))
    end
    local query = string.format("INSERT INTO %s (%s) VALUES %s;", tableName, columns,
        table.concat(values, ","))
    return self:exec(query)
end

DB.update = function(self, tableName, data, conditions)
    assert(self.Client, "Database client is not initialized")
    local set = ""
    for k, v in pairs(data) do
        if set ~= "" then
            set = set .. ", "
        end
        set = set .. string.format("%s = %s", k, prepare_arg(v))
    end
    local where = ""
    for k, v in pairs(conditions or {}) do
        if where ~= "" then
            where = where .. " AND "
        end
        if v == "__NULL" then
            where = where .. string.format("%s IS NULL", k)
        else
            where = where .. string.format("%s = %s", k, prepare_arg(v))
        end
    end
    local query = string.format("UPDATE %s SET %s WHERE %s;", tableName, set, where == "" and "1" or where)
    return self:exec(query)
end

DB.query = function(self, tableName, conditions, options)
    options = options or {}
    assert(self.Client, "Database client is not initialized")
    local where = ""
    for k, v in pairs(conditions or {}) do
        if where ~= "" then
            where = where .. " AND "
        end
        if v == "__NULL" then
            where = where .. string.format("%s IS NULL", k)
        else
            where = where .. string.format("%s = %s", k, prepare_arg(v))
        end
    end
    local query = string.format(
        "SELECT %s FROM %s WHERE %s %s %s %s;",
        options.fields or "*",
        tableName,
        where == "" and "1" or where,
        options.order ~= nil and string.format("ORDER BY %s", options.order) or "",
        options.limit ~= nil and string.format("LIMIT %s", options.limit) or "",
        options.offset ~= nil and string.format("OFFSET %s", options.offset) or ""
    )
    return self:nrows(query)
end

DB.queryOne = function(self, tableName, conditions, options)
    local result = self:query(tableName, conditions, options)
    if #result > 0 then
        return result[1]
    end
    return nil
end

DB.queryTables = function(self)
    local tables = self:nrows("SELECT name FROM sqlite_master WHERE type='table';")
    local result = {}
    for _, t in ipairs(tables) do
        t = t.name
        local columns = self:nrows(string.format("PRAGMA table_info(%s);", t))
        local columns_result = {}
        for _, column in ipairs(columns) do
            table.insert(columns_result, column.name)
        end
        result[t] = columns_result
    end
    return result
end

return DB
