local match = require("game.match")
local spells = require("game.spells")
local animation = {}

function animation.snapshot(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = animation.snapshot(item) end
    return copy
end

function animation.new(before, side, action, events)
    local effect = {
        before = before, side = side, kind = action.kind,
        elapsed = 0, duration = 0.4, impact = action.kind == "attack" and 0.16 or 0,
        attacker = action.attacker, target = action.target, hand = action.hand,
        damage = {}, dead = {}, healing = {},
    }
    if action.kind == "cast" then
        effect.spell = match.cards[before.players[side].hand[action.hand]]
        effect.target_side = spells.target_side(effect.spell, side)
    end
    for _, event in ipairs(events) do
        if event.kind == "damage" and event.amount > 0 then
            table.insert(effect.damage, { side = event.side, id = event.id, amount = event.amount })
        elseif event.kind == "heal" and event.amount > 0 then
            table.insert(effect.healing, { side = event.side, id = event.id, amount = event.amount })
        elseif event.kind == "death" then
            local unit = match.unit(before.players[event.side], event.id)
            if unit then table.insert(effect.dead, { side = event.side, unit = unit }) end
        elseif event.kind == "summon" then
            effect.summoned = event.id
        elseif event.kind == "draw" then
            effect.drawn_side, effect.drawn_hand = event.side, event.hand
        end
    end
    if action.kind == "end_turn" then effect.duration = 0.3 end
    return effect
end

function animation.update(effect, dt)
    if not effect then return nil end
    effect.elapsed = effect.elapsed + math.max(0, dt)
    if effect.elapsed >= effect.duration then return nil end
    return effect
end

function animation.progress(effect)
    return math.min(1, math.max(0, (effect.elapsed - effect.impact) / (effect.duration - effect.impact)))
end

return animation
