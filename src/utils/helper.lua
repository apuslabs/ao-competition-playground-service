local Helper = {}

Helper.assert_non_empty = function(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        assert(value and #value > 0, "Missing argument at position " .. i)
    end
end

Helper.assert_type = function(value, expected_type)
    assert(type(value) == expected_type, "Expected " .. expected_type .. " but got " .. type(value))
end

return Helper
