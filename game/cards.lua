-- Stable IDs: renaming or adding a card must not change existing deck references.
local cards = {}

cards.definitions = {
    [1] = { name = "Moon Wisp", kind = "creature", cost = 1, attack = 1, health = 2,
        visual = { symbol = "moon", role = "SPIRIT", color = { 0.63, 0.68, 0.98 } } },
    [2] = { name = "Goblin Raider", kind = "creature", cost = 2, attack = 3, health = 2,
        visual = { symbol = "blades", role = "RAIDER", color = { 0.93, 0.59, 0.35 } } },
    [3] = { name = "Grove Sentinel", kind = "creature", cost = 3, attack = 2, health = 5, guard = true,
        visual = { symbol = "leaf", role = "GUARD", color = { 0.40, 0.79, 0.58 } } },
    [4] = { name = "Stone Ogre", kind = "creature", cost = 4, attack = 5, health = 4,
        visual = { symbol = "mountain", role = "BRUTE", color = { 0.72, 0.70, 0.62 } } },
    [5] = { name = "Dusk Wolf", kind = "creature", cost = 2, attack = 2, health = 3,
        visual = { symbol = "wolf", role = "BEAST", color = { 0.55, 0.77, 0.89 } } },
    [6] = { name = "Iron Warder", kind = "creature", cost = 2, attack = 1, health = 4, guard = true,
        visual = { symbol = "tower", role = "GUARD", color = { 0.85, 0.73, 0.43 } } },
    [7] = { name = "Ember Drake", kind = "creature", cost = 5, attack = 6, health = 4,
        visual = { symbol = "drake", role = "DRAGON", color = { 0.98, 0.43, 0.34 } } },
    [8] = { name = "Elder Treant", kind = "creature", cost = 6, attack = 4, health = 8, guard = true,
        visual = { symbol = "tree", role = "GUARD", color = { 0.67, 0.81, 0.37 } } },
    [9] = { name = "Ember Bolt", kind = "spell", cost = 2, effect = "damage", amount = 3,
        visual = { symbol = "bolt", role = "SPELL", color = { 1.0, 0.53, 0.26 } } },
    [10] = { name = "Mending Light", kind = "spell", cost = 1, effect = "heal", amount = 3,
        visual = { symbol = "mend", role = "SPELL", color = { 0.43, 0.93, 0.78 } } },
}

-- Catalog additions do not automatically change the starter deck.
cards.starter_deck = {
    { card = 1, count = 2 },
    { card = 2, count = 2 },
    { card = 3, count = 2 },
    { card = 4, count = 2 },
    { card = 5, count = 2 },
    { card = 6, count = 2 },
    { card = 7, count = 2 },
    { card = 8, count = 2 },
    { card = 9, count = 2 },
    { card = 10, count = 2 },
}

return cards
