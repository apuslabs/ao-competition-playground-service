local json = require("json")
local ao = require('ao')

DataSets = DataSets or {}
Benchmarks = Benchmarks or {}

Handlers.add(
  "Create-Pool",
  Handlers.utils.hasMatchingTag("Action", "Create-Pool"),
  function(msg)
    -- TODO: check Balance
    local response = json.decode(msg.Data)
    local dataset = response.dataset
    Benchmarks[dataset] = {
      owner = msg.From,
      funds = msg.Token,
      models = {}
    }
  end
)

Handlers.add(
  "Join-Pool",
  Handlers.utils.hasMatchingTag("Action", "Join-Pool"),
  function(msg)
    local response = json.decode(msg.Data)
    local dataset = response.dataset
    local model = response.model
    Benchmarks[dataset].models[model] = {
      participant = msg.From,
      score = 0,
    }
    ao.send({
      Target = dataset,
      Tags = {
        { name = "Action", value = "Benchmark" },
      },
      Data = model
    })
  end
)

Handlers.add(
  "Benchmark-Response",
  Handlers.utils.hasMatchingTag("Action", "Benchmark-Response"),
  function(msg)
    assert(Benchmarks[msg.From] ~= nil, "Benchmark not found")
    local response = json.decode(msg.Data)
    Benchmarks[msg.From].models[response.model].score = response.score
  end
)

Handlers.add(
  "Leaderboard",
  Handlers.utils.hasMatchingTag("Action", "Leaderboard"),
  function(msg)
    local response = json.decode(msg.Data)
    local dataset = response.dataset
    local models = Benchmarks[dataset].models
    local leaderboard = {}
    for model, score in pairs(models) do
      leaderboard[model] = score
    end
    -- sort leaderboard by score
    table.sort(leaderboard, function(a, b) return a.score > b.score end)
    return json.encode(leaderboard)
  end
)