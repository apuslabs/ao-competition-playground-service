local json = require("json")

DataSets = DataSets or {}
Models = Models or {}
Benchmarks = Benchmarks or {}

Handlers.add(
  "Register-DataSet",
  Handlers.utils.hasMatchingData("Register-DataSet"),
  function(msg)
    DataSets[msg.Data] = {}
  end
)

Handlers.add(
  "Register-Model",
  Handlers.utils.hasMatchingData("Register-Model"),
  function(msg)
    table.insert(Models, msg.Data)
  end
)

Handlers.add(
  "Create-Benchmark",
  Handlers.utils.hasMatchingData("Create-Benchmark"),
  function(msg)
    -- TODO: check Balance
    local response = json.decode(msg.Data)
    local dataset = response.dataset
    Benchmarks[id] = {
      dataset = dataset,
      models = {}
    }
  end
)

Handlers.add(
  "Join-Benchmark",
  Handlers.utils.hasMatchingData("Join-Benchmark"),
  function(msg)
    local response = json.decode(msg.Data)
    local benchmark = response.benchmark
    local model = response.model
    Benchmarks[benchmark].models[model] = {}
  end
)

Handlers.add(
  "Benchmark-Result",
  Handlers.utils.hasMatchingData("Benchmark-Result"),
  function(msg)
    ao.Send
  end
)