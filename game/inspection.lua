local match = require("game.match")
local spells = require("game.spells")
local inspection = {}

function inspection.describe(state, region)
    if not region then return nil end
    local card_id, unit
    if region.kind == "hand" then
        if region.side == 2 then return nil end
        card_id = state.players[1].hand[region.index]
    elseif region.kind == "unit" then
        unit = match.unit(state.players[region.side], region.id)
        if unit then card_id = unit.card end
    end
    local card = match.cards[card_id]
    if not card then return nil end
    local details = { card = card, health = unit and unit.health or card.health }
    if card.kind == "spell" then
        details.description = spells.description(card)
    elseif card.guard then
        details.description = "Guard: enemies must attack this creature first. Guard does not block spells.\n\nCan attack once per turn."
    else
        details.description = "No special ability.\n\nCan attack once per turn. Creature combat deals damage to both creatures."
    end
    if unit then
        details.status = region.side ~= state.active and "Waiting for its controller's turn."
            or (unit.ready and "Ready to attack." or "Resting until its next turn.")
    else
        local valid, reason = match.can_play(state, 1, region.index)
        details.status = valid and (card.kind == "spell" and "Click, then choose a highlighted target."
            or "Click to summon. Attacks from next turn.") or reason
    end
    return details
end

function inspection.bounds(region)
    local width, height = 270, 340
    local x = region.x < 640 and region.x + region.w + 12 or region.x - width - 12
    local y = region.kind == "hand" and region.y - height - 12 or region.y - 30
    return { x = math.max(12, math.min(1280 - width - 12, x)),
        y = math.max(12, math.min(720 - height - 12, y)), w = width, h = height }
end

return inspection
