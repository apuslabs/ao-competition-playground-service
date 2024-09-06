local Helper = {}
local datetime = require("module.utils.datetime")
local log = require("module.utils.log")

Helper.assert_non_empty = function(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        assert(value ~= nil, "Expected non-empty value but got " .. tostring(value))
    end
end

Helper.assert_type = function(value, expected_type)
    assert(type(value) == expected_type, "Expected " .. expected_type .. " but got " .. type(value))
end

Helper.assert_non_empty_array = function(value)
    assert(value and type(value) == "table" and #value > 0, "Expected array but got " .. type(value))
end

Helper.throttleCheckWrapper = function(throttle)
    local lastTime = 0
    return function(msg)
        local now = datetime.unix()
        if (now - lastTime) < throttle then
            msg.reply({ Status = "429", Data = "Processing data. Try again in five minutes." })
            log.warn(string.format("Req from %s blocked due to rate limit", msg.From))
            return false
        end
        lastTime = now
        return true
    end
end

return Helper
