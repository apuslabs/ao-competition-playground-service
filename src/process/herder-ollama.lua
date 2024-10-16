local ao = require(".ao")
local json = require("json")
local log = require("module.utils.log")
local datetime = require("module.utils.datetime")
local Config = require("module.utils.config")

Queue = Queue or {}
InferenceAllowList = InferenceAllowList or {}

InferenceAllowList[Config.Process.Competition] = true
InferenceAllowList[Config.Process.Chat] = true

local function isAllowed(client)
    return InferenceAllowList[client] == true or client == ao.id or client == Owner
end

local function checkWorkerType(workerType)
    assert(workerType == "Evaluate" or workerType == "Chat", "WorkerType not allowed: " .. workerType)
end

Index = Index or 1

local function InferenceHandler(msg)
    assert(isAllowed(msg.From), "Inference not allowed: " .. msg.From)
    local msgType = msg.Tags["WorkerType"]
    checkWorkerType(msgType)
    assert(msg.Data, "Prompt not provided.")
    table.insert(Queue, {
        idx = Index,
        timestamp = datetime.unix(),
        workerType = msg.Tags["WorkerType"],
        client = msg.From,
        prompt = msg.Data,
        rawMsg = msg
    })
    log.info("REQ", msg.Tags["WorkerType"], "IDX", Index)
    Index = Index + 1
end

local function ResponseHandler(msg)
    local data = json.decode(msg.Data)
    assert(data.idx and data.response, "Invalid response")
    for i, v in ipairs(Queue) do
        if v.idx == data.idx then
            v.response = data.response
            v.responseAt = datetime.unix()
            log.info("RES", v.workerType, "IDX", v.idx, "DATA", data.response)
            v.rawMsg.reply({ Data = tostring(data.response) })
            table.remove(Queue, i)
            break
        end
    end
end

Handlers.add("Inference", "Inference", InferenceHandler)

Handlers.add("Get-Inference", "Get-Inference", function(msg)
    if #Queue == 0 then
        return
    end
    local item = Queue[1]
    msg.reply({ Data = json.encode({
        idx = item.idx,
        workerType = item.workerType,
        prompt = item.prompt,
    }) })
end)

Handlers.add("Inference-Response", "Inference-Response", ResponseHandler)

