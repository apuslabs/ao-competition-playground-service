local json = require("json")
local Config = require("module.utils.config")

function TestCreateData()
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Create-Dataset"
        },
        Data = json.encode({
            hash = "123456",
            list = { {
                content = "What's MMBNTVO? It's a test for rag.",
            }, {
                content = "What's BHBGGNN? It's a test for rag.",
            }, {
                content = "Apple: a fruit.",
            }, {
                content = "Banana: a fruit.",
            } }
        })
    })
end

function TestMultiCreateDataset()
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Create-Dataset"
        },
        Data = json.encode({
            hash = "123456",
            list = { {
                content = "What's MMBNTVO? It's a test for rag.",
            }, {
                content = "What's BHBGGNN? It's a test for rag.",
            }, {
                content = "Apple: a fruit.",
            }, {
                content = "Banana: a fruit.",
            } }
        })
    })
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Create-Dataset"
        },
        Data = json.encode({
            hash = "234567",
            list = { {
                content = "What's MMBNTVO? It's a test for rag.",
            }, {
                content = "What's BHBGGNN? It's a test for rag.",
            }, {
                content = "Apple: a fruit.",
            }, {
                content = "Banana: a fruit.",
            } }
        })
    })
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Create-Dataset"
        },
        Data = json.encode({
            hash = "345678",
            list = { {
                content = "What's MMBNTVO? It's a test for rag.",
            }, {
                content = "What's BHBGGNN? It's a test for rag.",
            }, {
                content = "Apple: a fruit.",
            }, {
                content = "Banana: a fruit.",
            } }
        })
    })
end

function TestSearch()
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Search-Prompt",
            Reference = "123456",
        },
        Data = json.encode({
            dataset_hash = "123456",
            prompt = "fruit"
        })
    })
end

function TestMultiSearch()
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Search-Prompt",
            Reference = "1"
        },
        Data = json.encode({
            dataset_hash = "123456",
            prompt = "fruit"
        })
    })
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Search-Prompt",
            Reference = "2"
        },
        Data = json.encode({
            dataset_hash = "123456",
            prompt = "BHBGGNN"
        })
    })
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Search-Prompt",
            Reference = "3"
        },
        Data = json.encode({
            dataset_hash = "123456",
            prompt = "Apple"
        })
    })
    Send({
        Target = Config.Process.Embedding,
        Tags = {
            Action = "Search-Prompt",
            Reference = "4"
        },
        Data = json.encode({
            dataset_hash = "123456",
            prompt = "MMBNTVO"
        })
    })
end
