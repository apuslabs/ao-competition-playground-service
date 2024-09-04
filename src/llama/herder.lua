local ao = require(".ao")
local log = require("utils.log")
local datetime = require('utils.datetime')

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

local function isAllowed(client)
    return InferenceAllowList[client] == true or client == ao.id or client == Owner
end

local function DispatchWork()
    -- check Busy table for if worker is over 1 hour
    for worker, work in pairs(Busy) do
        if (datetime.unix() - work.timestamp) > 3600000 then
            local wType = work.workerType
            if not TimeoutHerder[wType][worker] then
                log.warn("TIMEOUT", wType, string.sub(worker, 1, 6))
                TimeoutHerder[wType][worker] = true
                table.insert(Herder[wType], worker)
            else
                log.warn("REMOVE", wType, string.sub(worker, 1, 6))
                TimeoutHerder[wType][worker] = nil
            end
            work.rawMsg.reply(wType == "Chat" and "" or "0")
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

            log.trace("DISPATCHING WORK", workerType, "Client:", string.sub(job.client, 1, 6), "Worker:",
                string.sub(Herd[i], 1, 6), "Queue:", #Queue)

            -- TODO: use forward in future
            Send({
                Target = Herd[i],
                Action = "Inference",
                Data = job.prompt
            }).onReply(function(replyMsg)
                log.info("RES", workerType, string.sub(replyMsg.From, 1, 6), datetime.unix() - job.timestamp)
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

    log.trace("REQ", msg.Tags["WorkerType"], string.sub(msg.From, 1, 6), #Queue)

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
