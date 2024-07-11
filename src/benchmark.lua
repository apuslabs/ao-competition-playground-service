local json = require("json")
local ao = require('ao')

Benchmarks = Benchmarks or {}
WrappedAR = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10"

local Enum = {
  AllocationRules = {
    ArithmeticDecrease = "ArithmeticDecrease"
  }
}

function Allocation(rule, models) 
  if rule == Enum.AllocationRules.ArithmeticDecrease then
    local participantScores = {}
    for model, data in pairs(models) do
      table.insert(participantScores, {
        participant = model.participant,
        score = data.score * data.progress,
      })
    end
    -- sort by score * progress increasing
    table.sort(participantScores, function(a, b) return a.score < b.score end)
    -- first: 10 / 55, second: 9 / 55, third: 8 / 55, fourth: 7 / 55, fifth: 6 / 55 ...
    local rewards = {}
    if #participantScores > 10 then
      for i = 1, 10 do
        rewards[participantScores[i].participant] = rewards[participantScores[i].participant] or 0
        rewards[participantScores[i].participant] = rewards[participantScores[i].participant] + math.floor(i / 55)
      end
    else
      -- totalRewards, Arithmetic sum
      local totalRewards = 0
      for i = 1, #participantScores do
        totalRewards = totalRewards + i
      end
      for i = 1, #participantScores do
        rewards[participantScores[i].participant] = rewards[participantScores[i].participant] or 0
        rewards[participantScores[i].participant] = rewards[participantScores[i].participant] + math.floor(i / totalRewards)
      end
    end
    return rewards
  end
  print("Unknown allocation rule")
end

Handlers.add(
  "Create-Pool",
  function(msg)
    return msg.Tags.Action == "Credit-Notice" and
      msg.From == WrappedAR
  end,
  function(msg)
    -- TODO: check Balance
    local dataset = msg.Tags["X-Dataset"]
    local allocation = msg.Tags["X-Allocation"]
    local sender = msg.Tags["Sender"]
    local quantity = msg.Tags["Quantity"]
    Benchmarks[dataset] = {
      funder = sender,
      funds = tonumber(quantity),
      allocation = allocation,
      startTime = os.time(),
      endTime = os.time() + 60 * 60 * 24 * 30,
      models = {}
    }
    print("Pool " .. dataset .. " created")
  end
)

Handlers.add(
  "Join-Pool",
  Handlers.utils.hasMatchingTag("Action", "Join-Pool"),
  function(msg)
    local data = json.decode(msg.Data)
    local dataset = data.dataset
    local model = data.model
    Benchmarks[dataset].models[model] = {
      participant = msg.From,
      score = 0,
      progress = 0,
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
  "Get-Pools",
  Handlers.utils.hasMatchingTag("Action", "Get-Pools"),
  function()
    local pools = {}
    for dataset, benchmark in pairs(Benchmarks) do
      table.insert(pools, {
        dataset = dataset,
        allocation = benchmark.allocation,
        funder = benchmark.funder,
        funds = benchmark.funds,
        models = #benchmark.models
      })
    end
    print(pools)
  end
)

Handlers.add(
  "Update-Leaderboard",
  Handlers.utils.hasMatchingTag("Action", "Update-Leaderboard"),
  function(msg)
    local data = json.decode(msg.Data)
    local dataset = data.dataset
    local model = data.model
    ao.send({
      Target = dataset,
      Tags = {
        { name = "Action", value = "Score" },
      },
      Data = model
    })
  end
)

Handlers.add(
  "Allocate-Rewards",
  Handlers.utils.hasMatchingTag("Action", "Allocate-Rewards"),
  function(msg)
    local data = json.decode(msg.Data)
    local dataset = data.dataset
    local model = data.model
    -- check endTime
    if os.time() < Benchmarks[dataset].endTime then
      print("Not time to allocate rewards")
      return
    end
    local rewards = Allocation(Benchmarks[dataset].allocation, Benchmarks[dataset].models)
    for participant, reward in pairs(rewards) do
      if (reward > 0) then
        ao.send({
          Target = WrappedAR,
          Tags = {
            { name = "Action", value = "Transfer" },
            { name = "Recipient", value = participant },
            { name = "Quantity", value = reward },
          },
        })
      end
    end
  end
)

Handlers.add(
  "Score-Response",
  Handlers.utils.hasMatchingTag("Action", "Score-Response"),
  function(msg)
    local data = json.decode(msg.Data)
    local dataset = msg.From
    local model = msg.Tags['Model']
    Benchmarks[dataset].models[model].score = data.score
    Benchmarks[dataset].models[model].progress = data.progress
  end
)

Handlers.add(
  "Leaderboard",
  Handlers.utils.hasMatchingTag("Action", "Leaderboard"),
  function(msg)
    local dataset = msg.Data
    local models = Benchmarks[dataset].models
    local leaderboard = {}
    for model, modelData in pairs(models) do
      table.insert(leaderboard, {
        model = model,
        score = modelData.score * modelData.progress
      })
    end
    -- sort leaderboard by score
    table.sort(leaderboard, function(a, b) return a.score > b.score end)
    print(json.encode(leaderboard))
  end
)