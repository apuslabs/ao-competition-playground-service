local Config = {}

Config.Process = {
    Chat = "URaM7OLcB-TZj3C76qg7mjjX6nC2HvU9unUIxSDotJg",
    LlamaHerder = "J0hmRtTPfV3NFiLvn1Pw9-KqrfeAzRAE2JkKWQjz3t0",
    OllamaHerder = "79uAAtUuyh0qjscpzKG51LfNFT_LRDADvBD9Kb6yyks",
    Embedding = "q7QJTZbOI_avjaltnF-kP21kpL3qCs8sJSP6Wdl9wzM",
    Token = "al1xXXnWnfJD8qyZJvttVGq60z1VPGn4M5y6uCcMBUM",
    Competition = "oM_qGTdQhu00aPdo-9O7aJH_HSQvtJuxisheaibE-uM",
    Pool = "HJV6BxQGakxlQe6rfGxOMiifKSFYRz5WEwZOKPLPWEg"
}

Config.Evaluate = {
    Interval = 1,   -- 2 * 5mins
    BatchSize = 20 -- 5 per interval
}

Config.AESKey = "c1Tl31gxC9tv8CKG"
Config.AESIV =  "pool000000000000"

Config.Pool = {
    JoinThrottle = 1 * 60,    -- 2 minute
    LeaderboardInterval = 12, -- 12 * 5 mins
    CompetitionExtraTimeWindow = 3600 * 48 -- 48 hours
}

Config.Embedding = {
    RetrieveSize = 300,
}

Config.Llama = {
    DefaultModel = "ISrbGzQot05rs_HKC08O_SmkipYQnqgB1yC3mjZZeEo"
}

return Config
