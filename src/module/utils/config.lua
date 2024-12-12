local Config = {}

Config.Process = {
    Chat = "ZuZZeU2-JeNRdpBWBWU8p6IcjNXyZ0BFZ4M2Pwoj9vM",
    LlamaHerder = "J0hmRtTPfV3NFiLvn1Pw9-KqrfeAzRAE2JkKWQjz3t0",
    OllamaHerder = "79uAAtUuyh0qjscpzKG51LfNFT_LRDADvBD9Kb6yyks",
    Embedding = "q7QJTZbOI_avjaltnF-kP21kpL3qCs8sJSP6Wdl9wzM",
    Token = "al1xXXnWnfJD8qyZJvttVGq60z1VPGn4M5y6uCcMBUM",
    Competition = "oM_qGTdQhu00aPdo-9O7aJH_HSQvtJuxisheaibE-uM",
    Pool = "jzZzZJ6SpxLKaZv8rx2rmkq-QwKGQliFyWqr-OK9CIo"
}

Config.Evaluate = {
    Interval = 0,   -- 2 * 5mins
    BatchSize = 60 -- 5 per interval
}

Config.Pool = {
    JoinThrottle = 2 * 60,    -- 2 minute
    LeaderboardInterval = 12, -- 12 * 5 mins
}

Config.Embedding = {
    RetrieveSize = 300,
}

Config.Llama = {
    DefaultModel = "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
}

return Config
