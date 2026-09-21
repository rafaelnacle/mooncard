local match = require("game.match")
local ai = {}

function ai.choose(state, side)
    local player, enemy = state.players[side], state.players[3 - side]
    local best, best_score
    for _, action in ipairs(match.legal_actions(state, side)) do
        local score = -100
        if action.kind == "play" then
            local card = match.cards[player.hand[action.hand]]
            score = 20 + card.cost
        elseif action.kind == "cast" then
            local card = match.cards[player.hand[action.hand]]
            local target = match.unit(card.effect == "heal" and player or enemy, action.target)
            local target_card = match.cards[target.card]
            if card.effect == "heal" then
                local restored = math.min(card.amount, target_card.health - target.health)
                score = restored * 5 + (target_card.guard and 7 or 0)
            else
                local kills = card.amount >= target.health
                local follow_up = false
                for _, unit in ipairs(player.board) do
                    if unit.ready and match.cards[unit.card].attack >= target.health - card.amount then
                        if match.validate(state, side, { kind = "attack", attacker = unit.id, target = target.id }) then
                            follow_up = true
                        end
                    end
                end
                score = (kills and 18 + target_card.cost * 3 or (follow_up and 15 or -110))
                    + ((kills or follow_up) and target_card.guard and 6 or 0)
            end
        elseif action.kind == "attack" then
            local attacker = match.unit(player, action.attacker)
            local card = match.cards[attacker.card]
            if action.target == "hero" then
                score = card.attack >= enemy.health and 1000 or 5 + card.attack
            else
                local target = match.unit(enemy, action.target)
                local target_card = match.cards[target.card]
                local kills = card.attack >= target.health
                local dies = target_card.attack >= attacker.health
                score = (kills and 12 + target_card.cost * 3 or 0)
                    - (dies and card.cost * 3 + 4 or 0)
                    + (target_card.guard and 8 or 0)
            end
        end
        if not best_score or score > best_score then best, best_score = action, score end
    end
    return best
end

return ai
