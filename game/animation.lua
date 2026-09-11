local match = require("game.match")
local animation = {}

function animation.snapshot(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = animation.snapshot(item) end
    return copy
end

function animation.new(before, after, side, action)
    local effect = {
        before = before, side = side, kind = action.kind,
        elapsed = 0, duration = 0.4, impact = action.kind == "attack" and 0.16 or 0,
        attacker = action.attacker, target = action.target, hand = action.hand,
        damage = {}, dead = {},
    }
    if action.kind == "play" then effect.summoned = after.next_id - 1 end
    for player_side, player in ipairs(before.players) do
        local next_player = after.players[player_side]
        local hero_damage = player.health - next_player.health
        if hero_damage > 0 then
            table.insert(effect.damage, { side = player_side, id = "hero", amount = hero_damage })
        end
        for _, unit in ipairs(player.board) do
            local survivor
            for _, next_unit in ipairs(next_player.board) do
                if next_unit.id == unit.id then survivor = next_unit; break end
            end
            if not survivor then table.insert(effect.dead, { side = player_side, unit = unit }) end
            local amount = survivor and unit.health - survivor.health or 0
            if not survivor and action.kind == "attack" then
                local other_side = unit.id == action.attacker and 3 - side or side
                local other_id = unit.id == action.attacker and action.target or action.attacker
                for _, other in ipairs(before.players[other_side].board) do
                    if other.id == other_id then
                        amount = match.cards[other.card].attack
                    end
                end
            end
            if amount > 0 then
                table.insert(effect.damage, { side = player_side, id = unit.id, amount = amount })
            end
        end
    end
    if action.kind == "end_turn" then
        local next_side = after.active
        if #after.players[next_side].hand > #before.players[next_side].hand then
            effect.drawn_side, effect.drawn_hand = next_side, #after.players[next_side].hand
        end
        effect.duration = 0.3
    end
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
