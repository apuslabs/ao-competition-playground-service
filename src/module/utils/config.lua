local Config = {}

Config.Process = {
    Chat = "ZuZZeU2-JeNRdpBWBWU8p6IcjNXyZ0BFZ4M2Pwoj9vM",
    LlamaHerder = "IdHBRpDM4rgkLbO0oNU7cErvDQ7DdcCrQo8b-3Rd6io",
    Embedding = "vp4pxoOsilVxdsRqTmLjP86CwwUwtj1RoKeGrFVxIVk",
    Token = "al1xXXnWnfJD8qyZJvttVGq60z1VPGn4M5y6uCcMBUM",
    Competition = "didygr4-n88nmlu-NLW-qJfxJLvfiRhU-mRgKHYb6WE",
    Pool = "jzZzZJ6SpxLKaZv8rx2rmkq-QwKGQliFyWqr-OK9CIo"
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
    RetrieveSize = 200,
}

Config.Llama = {
    DefaultModel = "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
}

return Config
