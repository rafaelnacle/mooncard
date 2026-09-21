local cards = require("game.cards").definitions
local spells = {}

-- Each effect owns its targeting, resolution and player-facing explanation.
local effects = {
    damage = {
        friendly = false,
        prompt = "Choose an enemy creature.",
        no_targets = "No enemy creature to target.",
        validate = function() return true end,
        resolve = function(card, target)
            target.health = target.health - card.amount
            return { kind = "damage", amount = card.amount },
                card.name .. " deals " .. card.amount .. " damage to " .. cards[target.card].name .. "."
        end,
        description = function(card)
            return "Deal " .. card.amount .. " damage to an enemy creature. Ignores Guard. Cannot target heroes."
        end,
    },
    heal = {
        friendly = true,
        prompt = "Choose a wounded friendly creature.",
        no_targets = "No wounded friendly creature to heal.",
        validate = function(target)
            if target.health >= cards[target.card].health then
                return false, "That creature is already at full health."
            end
            return true
        end,
        resolve = function(card, target)
            local restored = math.min(card.amount, cards[target.card].health - target.health)
            target.health = target.health + restored
            return { kind = "heal", amount = restored },
                card.name .. " restores " .. restored .. " health to " .. cards[target.card].name .. "."
        end,
        description = function(card)
            return "Restore up to " .. card.amount .. " health to a wounded friendly creature, capped at its starting health. Cannot target heroes."
        end,
    },
}

local function definition(card)
    return assert(effects[card.effect], "Unknown spell effect: " .. tostring(card.effect))
end

function spells.target_side(card, side)
    return definition(card).friendly and side or 3 - side
end

function spells.validate_target(card, target)
    local effect = definition(card)
    if not target then return false, effect.prompt end
    return effect.validate(target)
end

-- Call only after validation; returns the resolved outcome and log message.
function spells.resolve(card, target)
    return definition(card).resolve(card, target)
end

function spells.description(card)
    return definition(card).description(card)
end

function spells.prompt(card)
    return definition(card).prompt
end

function spells.no_targets(card)
    return definition(card).no_targets
end

return spells
