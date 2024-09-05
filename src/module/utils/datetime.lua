local Datetime = {}

Datetime.unix = function()
    local timeValue = os.time()
    return math.floor(timeValue / 1000)
end

Datetime.nowISO = function()
    local unixtime = Datetime.unix()
    return os.date("%Y-%m-%dT%H:%M:%S", unixtime)
end

return Datetime
