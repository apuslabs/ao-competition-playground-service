local Lodash = {}

Lodash.map = function(array, fn)
    local result = {}
    for i = 1, #array do
        table.insert(result, fn(array[i], i, array))
    end
    return result
end

Lodash.keys = function(object)
    local result = {}
    for key, _ in pairs(object) do
        table.insert(result, key)
    end
    return result
end

Lodash.InsertUnique = function(t, value)
    for _, v in ipairs(t) do
        if v == value then
            return
        end
    end
    table.insert(t, value)
end

Lodash.Remove = function(t, value)
    for i,  v in ipairs(t) do
        if v == value then
            table.remove(t, i)
        end
    end
end

Lodash.Contain = function(t, value)
    for _, v in ipairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

Lodash.Size = function(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

return Lodash
