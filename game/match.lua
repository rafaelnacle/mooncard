local match = {}

match.cards = {
    { name = "Moon Wisp", cost = 1, attack = 1, health = 2 },
    { name = "Goblin Raider", cost = 2, attack = 3, health = 2 },
    { name = "Grove Sentinel", cost = 3, attack = 2, health = 5, guard = true },
    { name = "Stone Ogre", cost = 4, attack = 5, health = 4 },
    { name = "Dusk Wolf", cost = 2, attack = 2, health = 3 },
    { name = "Iron Warder", cost = 2, attack = 1, health = 4, guard = true },
    { name = "Ember Drake", cost = 5, attack = 6, health = 4 },
    { name = "Elder Treant", cost = 6, attack = 4, health = 8, guard = true },
}

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

local function draw(state, side)
    local player = state.players[side]
    if #player.deck == 0 then
        player.fatigue = player.fatigue + 1
        player.health = player.health - player.fatigue
        announce(state, player.name .. (side == 1 and " take " or " takes ") .. player.fatigue .. " fatigue damage.")
        check_winner(state)
        return
    end
    local card = table.remove(player.deck)
    if #player.hand < 7 then
        table.insert(player.hand, card)
    else
        announce(state, player.name .. (side == 1 and " discard " or " discards ") .. match.cards[card].name .. ": hand full.")
    end
end

local function begin_turn(state)
    local player = state.players[state.active]
    state.turn = state.turn + 1
    player.max_mana = math.min(6, player.max_mana + 1)
    player.mana = player.max_mana
    for _, unit in ipairs(player.board) do unit.ready = true end
    announce(state, player.name .. (state.active == 1 and " begin turn " or " begins turn ") .. state.turn .. ".")
    draw(state, state.active)
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
        for card = 1, #match.cards do
            for _ = 1, 2 do table.insert(player.deck, card) end
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

function match.validate(state, side, action)
    if state.winner then return false, "The duel is over." end
    if state.active ~= side then return false, "Wait for your turn." end
    local player, enemy = state.players[side], state.players[3 - side]
    if action.kind == "end_turn" then return true end
    if action.kind == "play" then
        local card = match.cards[player.hand[action.hand]]
        if not card then return false, "Choose a card in your hand." end
        if #player.board >= 5 then return false, "Your board is full." end
        if player.mana < card.cost then return false, "Not enough mana." end
        return true
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

local function remove_dead(player)
    for i = #player.board, 1, -1 do
        if player.board[i].health <= 0 then table.remove(player.board, i) end
    end
end

function match.apply(state, side, action)
    local valid, reason = match.validate(state, side, action)
    if not valid then return false, reason end
    local player, enemy = state.players[side], state.players[3 - side]
    if action.kind == "end_turn" then
        state.active = 3 - side
        begin_turn(state)
    elseif action.kind == "play" then
        local card_id = table.remove(player.hand, action.hand)
        local card = match.cards[card_id]
        player.mana = player.mana - card.cost
        table.insert(player.board, {
            id = state.next_id, card = card_id, health = card.health, ready = false,
        })
        state.next_id = state.next_id + 1
        announce(state, player.name .. (side == 1 and " summon " or " summons ") .. card.name .. ".")
    elseif action.kind == "attack" then
        local attacker = match.unit(player, action.attacker)
        local card = match.cards[attacker.card]
        attacker.ready = false
        if action.target == "hero" then
            enemy.health = enemy.health - card.attack
            announce(state, card.name .. " hits " .. (side == 2 and "you" or enemy.name) .. " for " .. card.attack .. ".")
        else
            local target = match.unit(enemy, action.target)
            local target_card = match.cards[target.card]
            target.health = target.health - card.attack
            attacker.health = attacker.health - target_card.attack
            announce(state, card.name .. " attacks " .. target_card.name .. ".")
            remove_dead(player)
            remove_dead(enemy)
        end
        check_winner(state)
    end
    return true
end

function match.legal_actions(state, side)
    local actions = {}
    if state.winner or state.active ~= side then return actions end
    local function add(action)
        if match.validate(state, side, action) then table.insert(actions, action) end
    end
    for i = 1, #state.players[side].hand do add({ kind = "play", hand = i }) end
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
