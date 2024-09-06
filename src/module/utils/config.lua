local Config = {}

Config.Process = {
    LlamaHerder = "972kot-Duchcz6lkGD9EFnm4O2-k_0xT_QjxxNRySPM",
    Embedding = "agVpRpcfcR_wygOjNxv-xlbdCgWoaY1-5nPYw6wtJgE",
    Token = "al1xXXnWnfJD8qyZJvttVGq60z1VPGn4M5y6uCcMBUM",
    Competition = "OnYMDvUdLu0u8W0ld5dK9ejgutl397dlCp7A2L7rK7c",
    Pool = "NcgWkb377fZRWQDT0t8Xnhb2JYDlJ1pOmXfYZZxb4LM"
}

Config.Evaluate = {
    Interval = 2,  -- 2 * 5mins
    BatchSize = 20 -- 20 per interval
}

Config.Pool = {
    JoinThrottle = 1 * 60,    -- 1 minute
    LeaderboardInterval = 12, -- 12 * 5 mins
}

return Config
