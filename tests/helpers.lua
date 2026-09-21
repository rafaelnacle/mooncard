local match = require("game.match")

local function fresh()
    return match.new(function(n) return n end)
end
local function unit(id, card, health, ready)
    return { id = id, card = card, health = health or match.cards[card].health, ready = ready ~= false }
end
local function snapshot(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do table.insert(keys, key) end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do table.insert(parts, tostring(key) .. "=" .. snapshot(value[key])) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function reject(state, side, action, reason)
    local before = snapshot(state)
    local ok, error_message, events = match.apply(state, side, action)
    assert(not ok and error_message == reason, error_message)
    assert(events == nil, "Rejected action emitted outcomes")
    assert(snapshot(state) == before, "Rejected action mutated state")
end

return {
    fresh = fresh,
    unit = unit,
    snapshot = snapshot,
    reject = reject,
}
