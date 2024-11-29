local Lodash = require("module.utils.lodash")

function RemoveUserFromUploadedList(address)
    if UploadedUserList[address] then
        UploadedUserList[address] = nil
        Log.warn(string.format("Removed %s from uploaded list", address))
    end
end

function CheckUserStatus(address)
    if not Lodash.Contain(WhiteList, address) then -- WhiteList
        return "User " .. address .. " is not allowed to join the event."
    end
    if UploadedUserList[address] then
        return "User " .. address .. " has already called join pool."
    end
    return "User is OK"
end


function BatchAddWhiteList(list)
    for _, v in ipairs(list) do
        Lodash.InsertUnique(WhiteList, v)
    end
end

function BatchRemoveWhiteList(list)
    for _, v in ipairs(list) do
        Lodash.Remove(WhiteList, v)
    end
end

function CountWhiteList()
    return #WhiteList
end

function DANGEROUS_CLEAR()
    WhiteList = {}
    UploadedUserList = {}
    UploadDatasetQueue = {}
    UploadedDatasetHashList = {}

    EmbeddingPorcesses = {}
    DatasetProcessMap = {}
end