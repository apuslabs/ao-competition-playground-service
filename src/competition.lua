local json = require("json")
local ao = require('ao')

Handlers.add(
  "Create-Pool",
  Handlers.utils.hasMatchingTag("Action", "Create-Pool"),
  function (msg)
    -- TODO
    ao.send({
        Target = msg.From,
        Tags = {
          { name = "Action", value = "Create-Pool-Response" },
          { name = "status", value = "200" }
        }})
      print("OK")
  end
)

Handlers.add(
  "Join-Pool",
  Handlers.utils.hasMatchingTag("Action", "Join-Pool"),
  function (msg)
    -- TODO
    ao.send({
        Target = msg.From,
        Tags = {
          { name = "Action", value = "Join-Pool-Response" },
          { name = "status", value = "200" }
        }})
      print("OK")
  end
)

Handlers.add(
  "Get-Pool",
  Handlers.utils.hasMatchingTag("Action", "Get-Pool"),
  function (msg)
    -- TODO
    ao.send({
        Target = msg.From,
        Tags = {
              { name = "Action", value = "Create-Pool-Response" },
              { name = "status", value = "200" }
        },
        Data = json.encode({
            title= "2024 AI Challenge",
            prize_pool= 100000,
            competition_time = json.encode({
                startTime=1722254056,
                endTime=1722554056
            }),
            fine_tuning_tutorial_link= "",
            description= "",
            video= ""
        })
      })
      print("OK")
  end
)


Handlers.add(
    "Get-Dashboard",
    Handlers.utils.hasMatchingTag("Action", "Get-Dashboard"),
    function (msg)
        -- TODO @Json
        ao.send({
            Target = msg.From,
            Tags = {
                  { name = "Action", value = "Get-Dashboard-Response" },
                  { name = "status", value = "200" }
            },
            Data = json.encode({
                participants = 1500,
                granted_reward = 5000,
                my_rank = 3,
                my_reward = 300
            })
      })
      print("OK")
    end
)

Handlers.add(
    "Get-Leaderboard",
    Handlers.utils.hasMatchingTag("Action", "Get-Leaderboard"),
    function (msg)
        -- TODO @Json
        local data = json.encode({
            {
                rank = 1,
                dataset_id = 10,
                dataset_name = "a good dataset",
                dataset_upload_time = 1722254056,
                score = 65,
                author = "ewewrerr",
                granted_reward = 0
            },
            {
                rank = 2,
                dataset_id = 12,
                dataset_name = "a bad dataset",
                dataset_upload_time = 1722254059,
                score = 60,
                author = "ewewrerreewdddd",
                granted_reward = 0
            }
        });
        ao.send({
            Target = msg.From,
            Tags = {
                  { name = "Action", value = "Get-Leaderboard-Response" },
                  { name = "status", value = "200" }
            },
            Data = data
      })
      print("OK")
    end
)

Handlers.add(
    "Allocate-Rewards",
    Handlers.utils.hasMatchingTag("Action", "Allocate-Rewards-Response"),
    function (msg)
        ao.send({
            Target = msg.From,
            Tags = {
                  { name = "Action", value = "Allocate-Rewards-Response" },
                  { name = "status", value = "200" }
            }
      })
      print("OK")
    end
)

