local json = require("json")

function TestCreateData()
    Send({
        Target = ao.id,
        Tags = {
            Action = "Create-Dataset"
        },
        Data = json.encode({
            hash = "123456",
            list = { {
                content = "What's MMBNTVO? It's a test for rag.",
            } }
        })
    })
end

function TestSearch()
    Send({
        Target = ao.id,
        Tags = {
            Action = "Search-Prompt",
            Reference = "123456"
        },
        Data = json.encode({
            dataset_hash = "123456",
            prompt = "What's MMBNTVO?"
        })
    })
end
