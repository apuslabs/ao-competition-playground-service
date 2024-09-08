local Config = {}

Config.Process = {
    LlamaHerder = "ZO9tosDW3L5HT8MU3Xa6bUUoSLpJGblNM4Ef936clCU",
    Embedding = "CZNh4g-sHxs0w6eM_xvONOFWK6fvWzQNd96fW5Mvlug",
    Token = "al1xXXnWnfJD8qyZJvttVGq60z1VPGn4M5y6uCcMBUM",
    Competition = "OnYMDvUdLu0u8W0ld5dK9ejgutl397dlCp7A2L7rK7c",
    Pool = "NcgWkb377fZRWQDT0t8Xnhb2JYDlJ1pOmXfYZZxb4LM"
}

Config.Evaluate = {
    Interval = 2, -- 2 * 5mins
    BatchSize = 1 -- 20 per interval
}

Config.Pool = {
    JoinThrottle = 1 * 60,    -- 1 minute
    LeaderboardInterval = 12, -- 12 * 5 mins
}

Config.Llama = {
    DefaultModel = "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
}

return Config
