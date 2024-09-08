-- SHOULD ONLY BE REQUIRED BY AOS 1

local ao = require('ao')

local aos2 = {}

aos2.replyMsg = function(msg, replyMsg)
    replyMsg.Target = msg["Reply-To"] or (replyMsg.Target or msg.From)
    replyMsg["X-Reference"] = msg["X-Reference"] or msg.Reference
    replyMsg["X-Origin"] = msg["X-Origin"] or nil

    return ao.send(replyMsg)
end

return aos2
