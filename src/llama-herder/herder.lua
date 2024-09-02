Herder = Herder or {
    Evaluate = {
        "O4ftPNEwm6qGvS29bX9lgVsrvC4boW9FNfh8UcnTaFI",
        "SY6oajcujiovk_MNRnqrbgPBSI1NgDTbw5ZU7ZGwiyM",
        "bI49OxDTwF0wKATTrpMbPdT8Ol3HXVaGI5ZGw8kJVIA",
        "JX8_SjAm2YrQedDc6zVBwXmV1676bza4u-NnebXMf4w",
        "Za8eBnPuleGsp-Eg8yvdQHdqQNqiOzyLM27HfLuRpQY"
    },
    Chat = {
        "WzZMtjWpxfkSz2xFHDDauZR2KXxVs6VgqSFqn2bjkX8",
        "0G0YQ4PmJ-uEDj8Fl335yDwy8RsPcURHZg2UqDt348E",
        "E2fy7iYlGc-JMjfiSIUaTx0OmYTWBhjcoXFLRuKlkKY",
        "VtTkbsMIQBDbR-lEgrNuPxjqxcvY-FNoiNoGVPxjVHU",
        "x4EYi_Me5rMobVtJxQNzmZMg-CiapxRCha1NrijfN88"
    }
}
Busy = Busy or {}
Queue = Queue or {}
TimeoutHerder = TimeoutHerder or {
    Evaluate = {},
    Chat = {}
}

Colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

InferenceAllowList = {
    ["xLlcWNqzvVJHOYpgFP9QV-FSF4mcmPtk8xjverzRK3U"] = true,
    ["Zv4NMG3qYgCtLLd9UTp8c0lhUjAnok2bVJahSwe1CkM"] = true,
    ["pNSXgR1gIp6zzoXZv4mfSLQfuWVzvPsLZHg8-oi_DZo"] = true,
}

local function isAllowed(client)
    return InferenceAllowList[client] == true or client == ao.id or client == Owner
end

function countHerder()
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
    return "Free evaluator: " .. freeEvaluator .. " | Busy evaluator: " .. busyEvaluator .. " | Free chat: " .. freeChat .. " | Busy chat: " .. busyChat
end

function DispatchWork(msg)
    -- check Busy table for if worker is over 1 hour
    for worker, work in pairs(Busy) do
        if (msg.Timestamp - work.timestamp) > 3600000 then
            local wType = work.workerType
            print("[" .. Colors.gray .. "TIMEOUT" .. Colors.reset .. " ]" ..
                " Type: " .. Colors.green .. wType .. Colors.reset ..
                " | Client: " .. Colors.blue .. string.sub(work.client, 1, 6) .. Colors.reset ..
                " | Client ref: " .. Colors.blue .. string.sub(work.userReference, 1, 10) .. Colors.reset ..
                " | Worker: " .. Colors.green .. string.sub(worker, 1, 6) .. Colors.reset
            )
            TimeoutHerder[wType][worker] = TimeoutHerder[wType][worker] or 0
            if (TimeoutHerder[wType][worker] >= 3) then
                -- if more then twice, print and don't add back to Herder
                print("[" .. Colors.gray .. "REMOVING WORKER" .. Colors.reset .. " ]" ..
                    " Type: " .. Colors.green .. wType .. Colors.reset ..
                    " | Worker: " .. Colors.green .. string.sub(worker, 1, 6) .. Colors.reset
                )
                -- TimeoutHerder[wType][worker] = nil
            else
                -- if less then twice, record and add back to Herder
                TimeoutHerder[wType][worker] = TimeoutHerder[wType][worker] + 1
                table.insert(Herder[wType], worker)
            end

            resData = tostring(0)    
            if wType == 'Chat' then
                resData =""
            end
            ao.send({
                Target = work.client,
                Action = "Inference-Response",
                WorkerType = work.workerType,
                Reference = work.userReference,
                Data = resData
            })
            
            Busy[worker] = nil
        end
    end

    -- check every Herd, if there is work, dispatch it
    for workerType, Herd in pairs(Herder) do
        -- goto tag for next worker type
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

            if not job then
                goto next_worker_type
            end

            print("[" .. Colors.gray .. "DISPATCHING WORK" .. Colors.reset .. " ]" ..
                " Type: " .. Colors.blue .. workerType .. Colors.reset ..
                " | Client: " .. Colors.blue .. string.sub(job.client, 1, 6) .. Colors.reset ..
                " | Client ref: " .. Colors.blue .. string.sub(job.userReference, 1, 10) .. Colors.reset ..
                " | Worker: " .. Colors.green .. string.sub(Herd[i], 1, 6) .. Colors.reset ..
                " | In queue: " .. Colors.red .. #Queue .. Colors.reset
            )

            ao.send({
                Target = Herd[i],
                Action = "Inference",
                Reference = job.userReference,
                Data = job.prompt
            })

            Busy[Herd[i]] = {
                timestamp = msg.Timestamp,
                client = job.client,
                userReference = job.userReference,
                workerType = job.workerType
            }
            table.remove(Herd, i)
        end
        ::next_worker_type::
    end
end

Handlers.add(
    "Inference",
    Handlers.utils.hasMatchingTag("Action", "Inference"),
    function(msg)
        assert(isAllowed(msg.From), "Inference not allowed: " .. msg.From)
        local msgType = msg.Tags["WorkerType"]
        assert(msgType and (msgType == "Evaluate" or msgType == "Chat"), "Type not allowed: " .. msgType)
        assert(msg.Tags["Reference"], "Reference not provided.")
        assert(msg.Data, "Prompt not provided.")
        table.insert(Queue, {
            timestamp = msg.Timestamp,
            client = msg.From,
            prompt = msg.Data,
            workerType = msg.Tags["WorkerType"],
            userReference = msg.Tags["Reference"],
        })

        print("[" ..
            Colors.gray ..
            tostring(msg.Timestamp) .. Colors.reset .. ":" .. Colors.blue .. "REQ" .. Colors.reset .. "]" ..
            " Type: " .. Colors.blue .. msg.Tags["WorkerType"] .. Colors.reset ..
            " | Client: " .. Colors.blue .. string.sub(msg.From, 1, 6) .. Colors.reset ..
            " | Client ref: " .. Colors.blue .. msg.Tags["Reference"] .. Colors.reset ..
            " | In queue: " .. Colors.red .. #Queue .. Colors.reset
        )

        DispatchWork(msg)
    end
)

Handlers.add(
    "InferenceResponseHandler",
    Handlers.utils.hasMatchingTag("Action", "Inference-Response"),
    function(msg)
        if not Busy[msg.From] then
            print("[" ..
                Colors.gray ..
                tostring(msg.Timestamp) .. Colors.reset .. ":" .. Colors.red .. "ERR" .. Colors.reset .. "]" ..
                " Inference-Response not accept." ..
                " Type: " .. Colors.green .. msg.Tags["WorkerType"] .. Colors.reset ..
                " | Worker: " .. Colors.blue .. string.sub(msg.From, 1, 6) .. Colors.reset ..
                " | Reference: " .. Colors.blue .. msg.Tags["Reference"] .. Colors.reset
            )
            return
        end

        local work = Busy[msg.From]
        print("[" ..
            Colors.gray ..
            tostring(msg.Timestamp) .. Colors.reset .. ":" .. Colors.green .. "RES" .. Colors.reset .. "]" ..
            " Type: " .. Colors.green .. work.workerType .. Colors.reset ..
            " | Client: " .. Colors.blue .. string.sub(work.client, 1, 6) .. Colors.reset ..
            " | Client ref: " .. Colors.blue .. string.sub(work.userReference, 1, 10) .. Colors.reset ..
            " | Worker: " .. Colors.green .. string.sub(msg.From, 1, 6) .. Colors.reset ..
            " | Duration: " ..
            Colors.red .. tostring((math.floor(msg.Timestamp - work.timestamp) / 1000)) .. Colors.reset .. "s"
        )

        ao.send({
            Target = work.client,
            Action = "Inference-Response",
            WorkerType = work.workerType,
            Reference = work.userReference,
            Data = msg.Data
        })

        Busy[msg.From] = nil
        table.insert(Herder[work.workerType], msg.From)

        DispatchWork(msg)
    end
)

Handlers.add(
    "Worker-Init",
    Handlers.utils.hasMatchingTag("Action", "Init-Response"),
    function(msg)
        local workerType = msg.Tags["WorkerType"]
        assert(workerType, "WorkerType not provided.")
        if not Herder[workerType] then
            Herder[workerType] = {}
        end
        table.insert(Herder[workerType], msg.From)
        print("[" .. Colors.gray .. tostring(msg.Timestamp) .. Colors.reset .. ":" ..
            Colors.green .. "INIT" .. Colors.reset .. "]" ..
            " Type: " .. Colors.green .. workerType .. Colors.reset ..
            " | Worker: " .. Colors.blue .. string.sub(msg.From, 1, 6) .. Colors.reset
        )
    end
)

function testChatInference(times)
    local testChatPrompt =
    [[{"question":"What are the use cases for a decentralized podcasting app?","context":"Question: What is the UI preview for the upcoming social media platform? Answer: The UI preview shows a functional public prototype for a truly decentralized social media platform.\nQuestion: What is the importance of governance in cryptonetworks? Answer: Governance tokens represent the power to change the rules of the system, and their value increases as the cryptonetwork grows.\nQuestion: Why are content creation and distribution governed by anyone other than creators and end users? Answer: This is a core question driving many underlying issues in society, and the answer lies in the deficiency of the HTTP protocol.\n"}]]

    for i = 1, times do
        Send({
            Target = ao.id,
            Tags = {
                Action = "Inference",
                WorkerType = "Chat",
                Reference = "test" .. tostring(i)
            },
            Data = testChatPrompt,
        })
    end
end

function testEvaluateInference(times)
    local testEvaluatePrompt =
    [[{"question":"It is 2021-07-10 01:09:09 now. What are the use cases for a decentralized podcasting app?","expected_response":"It is 2021-07-10 03:33:07 now. Announcement of the next permaweb incubator, Open Web Foundry v4, is coming very soon! Anyone up for building a permaweb podcasting app? There are major opportunities in this area.","context":"Question: What is the UI preview for the upcoming social media platform? Answer: The UI preview shows a functional public prototype for a truly decentralized social media platform.\nQuestion: What is the importance of governance in cryptonetworks? Answer: Governance tokens represent the power to change the rules of the system, and their value increases as the cryptonetwork grows.\nQuestion: Why are content creation and distribution governed by anyone other than creators and end users? Answer: This is a core question driving many underlying issues in society, and the answer lies in the deficiency of the HTTP protocol.\n"}]]

    for i = 1, times do
        Send({
            Target = ao.id,
            Tags = {
                Action = "Inference",
                WorkerType = "Evaluate",
                Reference = "test" .. tostring(i)
            },
            Data = testEvaluatePrompt,
        })
    end
end
