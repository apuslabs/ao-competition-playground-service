local datetime = {}

datetime.unix = function()
    local timeValue = os.time()
    return math.floor(timeValue / 1000)
end

datetime.nowISO = function()
    local unixtime = datetime.unix()
    return os.date("%Y-%m-%dT%H:%M:%S", unixtime)
end

return datetime
