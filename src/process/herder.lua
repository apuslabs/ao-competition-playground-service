local ao = require(".ao")
local json = require("json")
local log = require("module.utils.log")
local datetime = require('module.utils.datetime')
local Config = require("module.utils.config")

Herder = Herder or {
    Evaluate = {},
    Chat = {}
}
Busy = Busy or {}
Queue = Queue or {}
TimeoutHerder = TimeoutHerder or {
    Evaluate = {},
    Chat = {}
}

InferenceAllowList = {
    ["pNSXgR1gIp6zzoXZv4mfSLQfuWVzvPsLZHg8-oi_DZo"] = true,
    ["yq6x9mAh87H7-YcCOrYyR_wC1OLP3rsLzVNCc1SPTV8"] = true
}
InferenceAllowList[Config.Process.Competition] = true
InferenceAllowList[Config.Process.Chat] = true

local function isAllowed(client)
    return InferenceAllowList[client] == true or client == ao.id or client == Owner
end

function CheckBusyWorker()
    local t = {}
    for worker, work in pairs(Busy) do
        t[worker] = datetime.unix() - work.timestamp
    end
    return t
end

function DispatchWork()
    -- check Busy table for if worker is over 1 hour
    for worker, work in pairs(Busy) do
        if (datetime.unix() - work.timestamp) > 1200 then
            local wType = work.workerType
            if not TimeoutHerder[wType][worker] then
                log.warn("TIMEOUT", wType, string.sub(worker, 1, 6))
                TimeoutHerder[wType][worker] = true
                table.insert(Herder[wType], worker)
            else
                log.warn("REMOVE", wType, string.sub(worker, 1, 6))
                TimeoutHerder[wType][worker] = nil
            end
            work.rawMsg.reply({ Status = "408", Data = wType == "Chat" and "" or "0" })
            Busy[worker] = nil
        end
    end

    -- check every Herd, if there is work in queue, dispatch it
    for workerType, Herd in pairs(Herder) do
        for i in ipairs(Herd) do
            if #Queue == 0 then
                return
            end

            -- find a work from queue for this type of worker
            local job = nil
            for j, work in ipairs(Queue) do
                if work.workerType == workerType then
                    job = table.remove(Queue, j)
                    break
                end
            end

            -- if not job for this worker type, continue to next worker type
            if not job then
                goto next_worker_type
            end

            log.trace("DISPATCHING", workerType, "TO", string.sub(Herd[i], 1, 6), "REMAIN", #Queue)

            -- TODO: use forward in future
            Send({
                Target = Herd[i],
                Action = "Inference",
                Data = job.prompt
            }).onReply(function(replyMsg)
                log.info("RES", workerType, "FROM", string.sub(replyMsg.From, 1, 6), "COSTS",
                    (datetime.unix() - job.timestamp) .. 's')
                job.rawMsg.reply({ Data = replyMsg.Data })
                Busy[replyMsg.From] = nil
                table.insert(Herder[workerType], replyMsg.From)
                DispatchWork()
            end)

            Busy[Herd[i]] = {
                timestamp = datetime.unix(),
                workerType = job.workerType,
                rawMsg = job.rawMsg
            }
            table.remove(Herd, i)
        end
        ::next_worker_type::
    end
end

local function checkWorkerType(workerType)
    assert(workerType == "Evaluate" or workerType == "Chat", "WorkerType not allowed: " .. workerType)
end

local function InferenceHandler(msg)
    assert(isAllowed(msg.From), "Inference not allowed: " .. msg.From)
    local msgType = msg.Tags["WorkerType"]
    checkWorkerType(msgType)
    assert(msg.Data, "Prompt not provided.")
    table.insert(Queue, {
        timestamp = datetime.unix(),
        workerType = msg.Tags["WorkerType"],
        client = msg.From,
        prompt = msg.Data,
        rawMsg = msg
    })

    log.info("REQ", msg.Tags["WorkerType"], "FROM", string.sub(msg.From, 1, 6))

    DispatchWork()
end

function WorkerInitResponse(msg)
    local workerType = msg.Tags["WorkerType"]
    checkWorkerType(workerType)
    table.insert(Herder[workerType], msg.From)
    log.info("INIT", workerType, string.sub(msg.From, 1, 6))
end

Handlers.add("Worker-Init", "Init-Response", WorkerInitResponse)

Handlers.add("Inference", "Inference", InferenceHandler)

function StatisticWorker()
    local queueLength = #Queue
    local busyEvaluator = 0
    local busyChat = 0
    for _, work in pairs(Busy) do
        if work.workerType == "Evaluate" then
            busyEvaluator = busyEvaluator + 1
        else
            busyChat = busyChat + 1
        end
    end
    return {
        QueueLength = queueLength,
        BusyEvaluator = busyEvaluator,
        BusyChat = busyChat,
        FreeEvaluator = #Herder.Evaluate,
        FreeChat = #Herder.Chat
    }
end

Handlers.add("Worker-Statistic", "Worker-Statistic", function(msg)
    local statistic = StatisticWorker()
    msg.reply({ Data = json.encode(statistic) })
end)

function DANGEROUS_CLEAR()
    Queue = {}
end
