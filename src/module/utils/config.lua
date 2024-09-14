local Config = {}

Config.Process = {
    Chat = "K0zJBT9HQ4KOGE6gCDYFa0tldMB0jdppOyCNH9loe38",
    LlamaHerder = "ZO9tosDW3L5HT8MU3Xa6bUUoSLpJGblNM4Ef936clCU",
    Embedding = "jeALNYuYqPeYaiYsEq8vBfE0ebSceIAbLmeRe4PbtkU",
    Token = "al1xXXnWnfJD8qyZJvttVGq60z1VPGn4M5y6uCcMBUM",
    Competition = "OnYMDvUdLu0u8W0ld5dK9ejgutl397dlCp7A2L7rK7c",
    Pool = "NcgWkb377fZRWQDT0t8Xnhb2JYDlJ1pOmXfYZZxb4LM"
}

Config.Evaluate = {
    Interval = 1,  -- 2 * 5mins
    BatchSize = 25 -- 5 per interval
}

Config.Pool = {
    JoinThrottle = 2 * 60,    -- 2 minute
    LeaderboardInterval = 12, -- 12 * 5 mins
}

Config.Embedding = {
    RetrieveSize = 5,
}

Config.Llama = {
    DefaultModel = "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
}

return Config
