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

return Lodash
