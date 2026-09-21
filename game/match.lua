local cards = require("game.cards")
local spells = require("game.spells")
local match = {}

match.cards = cards.definitions

local function announce(state, message)
    state.message = message
    table.insert(state.log, 1, message)
    if #state.log > 5 then table.remove(state.log) end
end

local function check_winner(state)
    for i, player in ipairs(state.players) do
        if player.health <= 0 then state.winner = 3 - i end
    end
end

local function emit(events, kind, side, id, amount)
    if events then
        table.insert(events, { kind = kind, side = side, id = id, amount = amount })
    end
end

local function draw(state, side, events)
    local player = state.players[side]
    if #player.deck == 0 then
        player.fatigue = player.fatigue + 1
        player.health = player.health - player.fatigue
        emit(events, "damage", side, "hero", player.fatigue)
        announce(state, player.name .. (side == 1 and " take " or " takes ") .. player.fatigue .. " fatigue damage.")
        check_winner(state)
        return
    end
    local card = table.remove(player.deck)
    if #player.hand < 7 then
        table.insert(player.hand, card)
        if events then table.insert(events, { kind = "draw", side = side, hand = #player.hand }) end
    else
        announce(state, player.name .. (side == 1 and " discard " or " discards ") .. match.cards[card].name .. ": hand full.")
    end
end

local function begin_turn(state, events)
    local player = state.players[state.active]
    state.turn = state.turn + 1
    player.max_mana = math.min(6, player.max_mana + 1)
    player.mana = player.max_mana
    for _, unit in ipairs(player.board) do unit.ready = true end
    announce(state, player.name .. (state.active == 1 and " begin turn " or " begins turn ") .. state.turn .. ".")
    draw(state, state.active, events)
end

function match.new(random)
    random = random or math.random
    local state = { players = {}, active = 1, turn = 0, next_id = 1, log = {} }
    for side = 1, 2 do
        local player = {
            name = side == 1 and "You" or "The Warden",
            health = 20, mana = 0, max_mana = 0, fatigue = 0,
            deck = {}, hand = {}, board = {},
        }
        for _, entry in ipairs(cards.starter_deck) do
            for _ = 1, entry.count do table.insert(player.deck, entry.card) end
        end
        for i = #player.deck, 2, -1 do
            local j = random(i)
            player.deck[i], player.deck[j] = player.deck[j], player.deck[i]
        end
        state.players[side] = player
        for _ = 1, 3 do draw(state, side) end
    end
    begin_turn(state)
    return state
end

function match.unit(player, id)
    for _, unit in ipairs(player.board) do
        if unit.id == id then return unit end
    end
end

function match.can_play(state, side, hand)
    if state.winner then return false, "The duel is over." end
    if state.active ~= side then return false, "Wait for your turn." end
    local player = state.players[side]
    local card = match.cards[player.hand[hand]]
    if not card then return false, "Choose a card in your hand." end
    if card.kind ~= "spell" and #player.board >= 5 then return false, "Your board is full." end
    if player.mana < card.cost then return false, "Not enough mana." end
    if card.kind == "spell" then
        local target_side = spells.target_side(card, side)
        for _, target in ipairs(state.players[target_side].board) do
            if spells.validate_target(card, target) then return true end
        end
        return false, spells.no_targets(card)
    end
    return true
end

function match.validate(state, side, action)
    if state.winner then return false, "The duel is over." end
    if state.active ~= side then return false, "Wait for your turn." end
    local player, enemy = state.players[side], state.players[3 - side]
    if action.kind == "end_turn" then return true end
    if action.kind == "play" or action.kind == "cast" then
        local valid, reason = match.can_play(state, side, action.hand)
        if not valid then return false, reason end
        local card = match.cards[player.hand[action.hand]]
        if action.kind == "play" then
            if card.kind == "spell" then return false, "Choose a target for this spell." end
            return true
        end
        if card.kind ~= "spell" then return false, "That card is a creature, not a spell." end
        local target_side = spells.target_side(card, side)
        local target = match.unit(state.players[target_side], action.target)
        return spells.validate_target(card, target)
    end
    if action.kind == "attack" then
        local attacker = match.unit(player, action.attacker)
        if not attacker then return false, "Choose one of your creatures." end
        if not attacker.ready then return false, "That creature cannot attack yet." end
        local target = action.target ~= "hero" and match.unit(enemy, action.target) or nil
        if action.target ~= "hero" and not target then return false, "Choose an enemy target." end
        local has_guard = false
        for _, unit in ipairs(enemy.board) do
            if match.cards[unit.card].guard then has_guard = true end
        end
        if has_guard and (not target or not match.cards[target.card].guard) then
            return false, "Defeat enemy Guards first."
        end
        return true
    end
    return false, "Unknown action."
end

local function remove_dead(state, side, events)
    local player = state.players[side]
    for i = #player.board, 1, -1 do
        if player.board[i].health <= 0 then
            emit(events, "death", side, player.board[i].id)
            table.remove(player.board, i)
        end
    end
end

-- Success returns true, nil, events. Failure returns false, reason without mutation.
-- Events describe resolved outcomes; presentation must never reconstruct combat rules.
function match.apply(state, side, action)
    local valid, reason = match.validate(state, side, action)
    if not valid then return false, reason end
    local events = {}
    local player, enemy = state.players[side], state.players[3 - side]
    if action.kind == "end_turn" then
        state.active = 3 - side
        begin_turn(state, events)
    elseif action.kind == "play" then
        local card_id = table.remove(player.hand, action.hand)
        local card = match.cards[card_id]
        player.mana = player.mana - card.cost
        table.insert(player.board, {
            id = state.next_id, card = card_id, health = card.health, ready = false,
        })
        emit(events, "summon", side, state.next_id)
        state.next_id = state.next_id + 1
        announce(state, player.name .. (side == 1 and " summon " or " summons ") .. card.name .. ".")
    elseif action.kind == "cast" then
        local card = match.cards[table.remove(player.hand, action.hand)]
        local target_side = spells.target_side(card, side)
        local target = match.unit(state.players[target_side], action.target)
        player.mana = player.mana - card.cost
        local outcome, message = spells.resolve(card, target)
        outcome.side, outcome.id = target_side, target.id
        table.insert(events, outcome)
        remove_dead(state, target_side, events)
        announce(state, message)
    elseif action.kind == "attack" then
        local attacker = match.unit(player, action.attacker)
        local card = match.cards[attacker.card]
        attacker.ready = false
        if action.target == "hero" then
            enemy.health = enemy.health - card.attack
            emit(events, "damage", 3 - side, "hero", card.attack)
            announce(state, card.name .. " hits " .. (side == 2 and "you" or enemy.name) .. " for " .. card.attack .. ".")
        else
            local target = match.unit(enemy, action.target)
            local target_card = match.cards[target.card]
            target.health = target.health - card.attack
            attacker.health = attacker.health - target_card.attack
            emit(events, "damage", side, attacker.id, target_card.attack)
            emit(events, "damage", 3 - side, target.id, card.attack)
            announce(state, card.name .. " attacks " .. target_card.name .. ".")
            remove_dead(state, side, events)
            remove_dead(state, 3 - side, events)
        end
        check_winner(state)
    end
    return true, nil, events
end

function match.legal_actions(state, side)
    local actions = {}
    if state.winner or state.active ~= side then return actions end
    local function add(action)
        if match.validate(state, side, action) then table.insert(actions, action) end
    end
    for i, card_id in ipairs(state.players[side].hand) do
        local card = match.cards[card_id]
        if card.kind == "spell" then
            local target_side = spells.target_side(card, side)
            for _, target in ipairs(state.players[target_side].board) do
                add({ kind = "cast", hand = i, target = target.id })
            end
        else
            add({ kind = "play", hand = i })
        end
    end
    for _, unit in ipairs(state.players[side].board) do
        add({ kind = "attack", attacker = unit.id, target = "hero" })
        for _, target in ipairs(state.players[3 - side].board) do
            add({ kind = "attack", attacker = unit.id, target = target.id })
        end
    end
    add({ kind = "end_turn" })
    return actions
end

return match
