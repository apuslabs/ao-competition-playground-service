-- Module: XcWULRSWWv_bmaEyx4PEOFf4vgRSVCP9vM5AucRvI40
local Config = require("module.utils.config")

Colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

WorkerType = "Evaluate"

local json = require("json")

RouterID = RouterID or Config.Process.LlamaHerder

InferenceAllowList = {
    [RouterID] = true,
    [ao.id] = true
}

local function replyMsg(msg, replyMsg)
    replyMsg.Target = msg["Reply-To"] or (replyMsg.Target or msg.From)
    replyMsg["X-Reference"] = msg["X-Reference"] or msg.Reference
    replyMsg["X-Origin"] = msg["X-Origin"] or nil

    return ao.send(replyMsg)
end

Handlers.add(
    "Init",
    Handlers.utils.hasMatchingTag("Action", "Init"),
    function(msg)
        if msg.From ~= ao.id then
            return print("Init not allowed: " .. msg.From)
        end

        ModelID = msg.Tags["Model-ID"] or ModelID
        DefaultMaxResponse = msg.Tags["Max-Response"] or DefaultMaxResponse
        Init()
        ao.send({
            Target = RouterID,
            Tags = {
                Action = "Init-Response",
                WorkerType = WorkerType,
            },
        })
    end
)

Handlers.add(
    "Inference",
    Handlers.utils.hasMatchingTag("Action", "Inference"),
    function(msg)
        if not InferenceAllowList[msg.From] then
            print("Inference not allowed: " .. msg.From)
            return
        end
        local userPrompt = msg.Data
        print("[" .. Colors.gray .. "INFERENCE" .. Colors.reset .. " ]" ..
            " From: " .. Colors.blue .. msg.From .. Colors.reset ..
            " | Reference: " .. Colors.blue .. msg.Tags["Reference"] .. Colors.reset ..
            " | Score: " .. Colors.blue .. score .. Colors.reset)

        replyMsg(msg, { Data = 80 })
    end
)