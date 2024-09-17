local Config = {}

Config.Process = {
    Chat = "K0zJBT9HQ4KOGE6gCDYFa0tldMB0jdppOyCNH9loe38",
    LlamaHerder = "ZO9tosDW3L5HT8MU3Xa6bUUoSLpJGblNM4Ef936clCU",
    Embedding = "b_y_QuM8BVEbzv91dcfDd4V7FQnUbxJUtkigs4U-2M8",
    Token = "al1xXXnWnfJD8qyZJvttVGq60z1VPGn4M5y6uCcMBUM",
    Competition = "OnYMDvUdLu0u8W0ld5dK9ejgutl397dlCp7A2L7rK7c",
    Pool = "NcgWkb377fZRWQDT0t8Xnhb2JYDlJ1pOmXfYZZxb4LM"
}

Config.Evaluate = {
    Interval = 1,   -- 2 * 5mins
    BatchSize = 100 -- 5 per interval
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
