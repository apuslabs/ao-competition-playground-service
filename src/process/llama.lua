local ao = require(".ao")
local json = require("json")
local log = require("module.utils.log")
local datetime = require("module.utils.datetime")
local Config = require("module.utils.config")

Herder = Herder or { Evaluate = {}, Chat = {} }
Queue = Queue or { Evaluate = {}, Chat = {} }
InferenceAllowList = {
    [Config.Process.Competition] = true,
    [Config.Process.Chat] = true
}

local function nextWorker(msg)
    if msg.WorkerType == "Evaluate" then
        assert(#Herder.Evaluate > 0, "No worker available.")
        return table.remove(Herder.Evaluate, 1)
    else
        assert(#Herder.Chat > 0, "No worker available.")
        return table.remove(Herder.Chat, 1)
    end
end

function DispatchWork()
    while #Queue.Evaluate > 0 do
        if #Herder.Evaluate == 0 then
            break
        end
        local msg = table.remove(Queue.Evaluate, 1)
        local worker = nextWorker(msg)
        log.info("DISPATCH", msg.WorkerType, "TraceID", msg["X-TraceID"])
        msg.forward(worker)
    end
    while #Queue.Chat > 0 do
        if #Herder.Chat == 0 then
            break
        end
        local msg = table.remove(Queue.Chat, 1)
        local worker = nextWorker(msg)
        log.info("DISPATCH", msg.WorkerType, "TraceID", msg["X-TraceID"])
        msg.forward(worker)
    end
end

local function isAllowed(client)
    return InferenceAllowList[client] == true or client == ao.id or client == Owner
end

local function checkWorkerType(workerType)
    assert(workerType == "Evaluate" or workerType == "Chat", "WorkerType not allowed: " .. workerType)
end

local function InferenceHandler(msg)
    -- assert(isAllowed(msg.From), "Inference not allowed: " .. msg.From)
    checkWorkerType(msg["WorkerType"])
    assert(msg.Data, "Prompt not provided.")
    log.info("REQ", msg["WorkerType"], "TraceID", msg["X-TraceID"])
    table.insert(Queue[msg.WorkerType], msg)
    DispatchWork()
end

function WorkerInitResponse(msg)
    local workerType = msg.Tags["WorkerType"]
    checkWorkerType(workerType)
    table.insert(Herder[workerType], msg.From)
    log.info("Ready", workerType, msg.From)
    DispatchWork()
end

Handlers.add("Worker-Ready", "Worker-Ready", WorkerInitResponse)

Handlers.add("Inference", "Inference", InferenceHandler)