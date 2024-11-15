Stats = {}

Stats.CountHerder = function()
    local freeEvaluator = #Herder["Evaluate"]
    local freeChat = #Herder["Chat"]
    local busyEvaluator = 0
    local busyChat = 0
    for _, work in pairs(Busy) do
        if work.workerType == "Evaluate" then
            busyEvaluator = busyEvaluator + 1
        elseif work.workerType == "Chat" then
            busyChat = busyChat + 1
        end
    end
    return "Free evaluator: " ..
        freeEvaluator ..
        " | Busy evaluator: " .. busyEvaluator .. " | Free chat: " .. freeChat .. " | Busy chat: " .. busyChat
end
