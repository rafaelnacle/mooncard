local match = require("game.match")
local ai = require("game.ai")
local passed = 0
local function test(name, run)
    run()
    passed = passed + 1
    print("PASS " .. name)
end
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

test("opening hands, decks, first draw and mana", function()
    local s = fresh()
    assert(s.active == 1 and s.turn == 1)
    assert(#s.players[1].hand == 4 and #s.players[1].deck == 16)
    assert(#s.players[2].hand == 3 and #s.players[2].deck == 17)
    assert(s.players[1].mana == 1 and s.players[2].mana == 0)
    for _, p in ipairs(s.players) do
        local counts = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
        for _, zone in ipairs({ p.deck, p.hand }) do
            for _, card in ipairs(zone) do counts[card] = counts[card] + 1 end
        end
        for _, count in ipairs(counts) do assert(count == 2) end
    end
end)

test("summoning spends mana, creates unique units and prevents immediate attacks", function()
    local s = fresh()
    local p = s.players[1]
    p.hand, p.mana = { 1, 1 }, 2
    assert(match.apply(s, 1, { kind = "play", hand = 1 }))
    assert(p.mana == 1 and #p.hand == 1 and #p.board == 1)
    reject(s, 1, { kind = "attack", attacker = p.board[1].id, target = "hero" }, "That creature cannot attack yet.")
    assert(match.apply(s, 1, { kind = "play", hand = 1 }))
    assert(p.board[1].id ~= p.board[2].id)
end)

test("invalid actions leave the entire match unchanged", function()
    local s = fresh()
    s.players[1].hand = { 4 }
    reject(s, 1, { kind = "play", hand = 1 }, "Not enough mana.")
    reject(s, 2, { kind = "end_turn" }, "Wait for your turn.")
    reject(s, 1, { kind = "play", hand = 99 }, "Choose a card in your hand.")
    reject(s, 1, { kind = "attack", attacker = 99, target = "hero" }, "Choose one of your creatures.")
    reject(s, 1, { kind = "invalid" }, "Unknown action.")
    s.players[1].mana = 6
    for i = 1, 5 do s.players[1].board[i] = unit(i, 1) end
    reject(s, 1, { kind = "play", hand = 1 }, "Your board is full.")
    reject(s, 1, { kind = "attack", attacker = 1, target = 99 }, "Choose an enemy target.")
end)

test("combat is simultaneous and removes both dead creatures", function()
    local s = fresh()
    s.players[1].board = { unit(1, 2) }
    s.players[2].board = { unit(2, 2) }
    assert(match.apply(s, 1, { kind = "attack", attacker = 1, target = 2 }))
    assert(#s.players[1].board == 0 and #s.players[2].board == 0)
end)

test("damage persists, attacks exhaust, and new turns ready creatures", function()
    local s = fresh()
    s.players[1].board = { unit(1, 3) }
    s.players[2].board = { unit(2, 1) }
    assert(match.apply(s, 1, { kind = "attack", attacker = 1, target = 2 }))
    assert(s.players[1].board[1].health == 4)
    reject(s, 1, { kind = "attack", attacker = 1, target = "hero" }, "That creature cannot attack yet.")
    assert(match.apply(s, 1, { kind = "end_turn" }))
    assert(match.apply(s, 2, { kind = "end_turn" }))
    assert(s.players[1].board[1].ready and s.players[1].board[1].health == 4)
    assert(s.players[1].mana == 2)
end)

test("all Guards protect the hero and other creatures until defeated", function()
    local s = fresh()
    s.players[1].board = { unit(1, 4), unit(2, 4), unit(3, 4) }
    s.players[2].board = { unit(4, 3), unit(5, 3), unit(6, 1) }
    reject(s, 1, { kind = "attack", attacker = 1, target = "hero" }, "Defeat enemy Guards first.")
    reject(s, 1, { kind = "attack", attacker = 1, target = 6 }, "Defeat enemy Guards first.")
    assert(match.apply(s, 1, { kind = "attack", attacker = 1, target = 4 }))
    reject(s, 1, { kind = "attack", attacker = 2, target = "hero" }, "Defeat enemy Guards first.")
    assert(match.apply(s, 1, { kind = "attack", attacker = 2, target = 5 }))
    assert(match.apply(s, 1, { kind = "attack", attacker = 3, target = "hero" }))
    assert(s.players[2].health == 15 and s.players[1].board[3].health == 4)
end)

test("hand limit burns the drawn card", function()
    local s = fresh()
    s.players[2].hand = { 1, 1, 1, 1, 1, 1, 1 }
    local count = #s.players[2].deck
    assert(match.apply(s, 1, { kind = "end_turn" }))
    assert(#s.players[2].hand == 7 and #s.players[2].deck == count - 1)
    assert(s.message:find("hand full", 1, true))
end)

test("mana caps at six and fatigue increases to a terminal loss", function()
    local s = fresh()
    for _, p in ipairs(s.players) do p.deck, p.health = {}, 100 end
    for _ = 1, 14 do assert(match.apply(s, s.active, { kind = "end_turn" })) end
    for _, p in ipairs(s.players) do
        assert(p.max_mana == 6 and p.mana == 6 and p.fatigue == 7 and p.health == 72)
    end
    local next_side = 3 - s.active
    s.players[next_side].health = 1
    assert(match.apply(s, s.active, { kind = "end_turn" }))
    assert(s.winner == 3 - next_side)
    reject(s, s.active, { kind = "end_turn" }, "The duel is over.")
end)

test("hero lethal ends match and restart creates fresh independent state", function()
    local s = fresh()
    s.players[1].board = { unit(1, 4) }
    s.players[2].health = 5
    assert(match.apply(s, 1, { kind = "attack", attacker = 1, target = "hero" }))
    assert(s.winner == 1)
    reject(s, 1, { kind = "end_turn" }, "The duel is over.")
    assert(#match.legal_actions(s, 1) == 0)
    local next_match = fresh()
    assert(not next_match.winner and next_match.players[2].health == 20)
    assert(s.players[2].health == 0)
end)

test("AI takes lethal and ignores hidden enemy cards", function()
    local s = fresh()
    s.players[1].board = { unit(1, 4) }
    s.players[2].health = 5
    local action = ai.choose(s, 1)
    assert(action.kind == "attack" and action.target == "hero")
    local before = snapshot(action)
    s.players[2].hand, s.players[2].deck = { 4, 4, 4 }, { 1 }
    assert(snapshot(ai.choose(s, 1)) == before)
end)

test("100 seeded AI duels finish legally without violating limits", function()
    for seed = 1, 100 do
        math.randomseed(seed)
        local s = match.new()
        local steps = 0
        while not s.winner and steps < 1000 do
            local action = ai.choose(s, s.active)
            assert(action and match.apply(s, s.active, action))
            for _, p in ipairs(s.players) do
                assert(#p.hand <= 7 and #p.board <= 5)
                assert(p.mana >= 0 and p.mana <= p.max_mana and p.max_mana <= 6)
                for _, creature in ipairs(p.board) do assert(creature.health > 0) end
            end
            steps = steps + 1
        end
        assert(s.winner, "Match did not terminate: " .. seed)
    end
end)

test("full board and hand hit regions fit the window without overlap", function()
    local view = require("game.view")
    local s = fresh()
    s.players[1].hand = { 1, 1, 2, 2, 3, 3, 4 }
    for side = 1, 2 do
        for i = 1, 5 do s.players[side].board[i] = unit(side * 10 + i, 3) end
    end
    local regions = view.regions(s)
    for i, r in ipairs(regions) do
        assert(r.x >= 0 and r.y >= 0 and r.x + r.w <= 1280 and r.y + r.h <= 720)
        local hit = view.hit(s, r.x + r.w / 2, r.y + r.h / 2)
        assert(hit.kind == r.kind and hit.id == r.id and hit.index == r.index and hit.side == r.side)
        for j = i + 1, #regions do
            local other = regions[j]
            assert(r.x + r.w <= other.x or other.x + other.w <= r.x
                or r.y + r.h <= other.y or other.y + other.h <= r.y, "Hit regions overlap")
        end
    end
    s.winner = 1
    assert(#view.regions(s) == 1 and view.hit(s, 640, 434).kind == "restart")
    assert(not view.hit(s, 1170, 460))
end)

test("summon animation preserves its source snapshot and finishes after a long frame", function()
    local animation = require("game.animation")
    local s = fresh()
    s.players[1].hand = { 1 }
    local before = animation.snapshot(s)
    local action = { kind = "play", hand = 1 }
    local ok, reason, events = match.apply(s, 1, action)
    assert(ok, reason)
    assert(events)
    local effect = animation.new(before, 1, action, events)
    assert(effect.summoned == s.players[1].board[1].id)
    assert(#before.players[1].hand == 1 and #before.players[1].board == 0)
    local state_before = snapshot(s)
    effect = animation.update(effect, 0.1)
    assert(effect and animation.progress(effect) > 0)
    assert(animation.update(effect, 10) == nil)
    assert(snapshot(s) == state_before, "Animation mutated live rules")
end)

test("combat animation retains both dead cards and simultaneous damage", function()
    local animation = require("game.animation")
    local s = fresh()
    s.players[1].board = { unit(1, 2) }
    s.players[2].board = { unit(2, 2) }
    local before = animation.snapshot(s)
    local action = { kind = "attack", attacker = 1, target = 2 }
    local ok, reason, events = match.apply(s, 1, action)
    assert(ok, reason)
    assert(events)
    local effect = animation.new(before, 1, action, events)
    assert(#effect.dead == 2 and #effect.damage == 2)
    assert(effect.damage[1].amount == 3 and effect.damage[2].amount == 3)
    animation.update(effect, 0.1)
    assert(effect.elapsed < effect.impact and animation.progress(effect) == 0)
    animation.update(effect, 0.1)
    assert(effect.elapsed > effect.impact and animation.progress(effect) > 0)
    assert(#s.players[1].board == 0 and #before.players[1].board == 1)
end)

test("hero lethal and fatigue animate without inventing dead creatures", function()
    local animation = require("game.animation")
    local s = fresh()
    s.players[1].board = { unit(1, 4) }
    s.players[2].health = 5
    local before = animation.snapshot(s)
    local action = { kind = "attack", attacker = 1, target = "hero" }
    local ok, reason, events = match.apply(s, 1, action)
    assert(ok, reason)
    assert(events)
    local effect = animation.new(before, 1, action, events)
    assert(s.winner == 1 and not before.winner)
    assert(#effect.dead == 0 and #effect.damage == 1)
    assert(effect.damage[1].id == "hero" and effect.damage[1].amount == 5)
    s = fresh()
    s.players[2].deck = {}
    before = animation.snapshot(s)
    action = { kind = "end_turn" }
    ok, reason, events = match.apply(s, 1, action)
    assert(ok, reason)
    assert(events)
    effect = animation.new(before, 1, action, events)
    assert(not effect.drawn_hand and effect.damage[1].amount == 1)
end)

test("expanded roster is playable at its cost and every Guard protects its hero", function()
    for card_id, card in ipairs(match.cards) do
        if card.kind ~= "spell" then
            local s = fresh()
            s.players[1].hand, s.players[1].mana = { card_id }, card.cost
            assert(match.apply(s, 1, { kind = "play", hand = 1 }))
            local creature = s.players[1].board[1]
            assert(creature.card == card_id and creature.health == card.health)
            assert(s.players[1].mana == 0 and not creature.ready)
            s.players[2].board = { unit(99, card_id) }
            creature.ready = true
            local valid, reason = match.validate(s, 1,
                { kind = "attack", attacker = creature.id, target = "hero" })
            assert(valid == not card.guard)
            if card.guard then assert(reason == "Defeat enemy Guards first.") end
        end
    end
end)

test("Ember Bolt bypasses Guard, consumes mana and card once, and never retaliates", function()
    local s = fresh()
    local p, enemy = s.players[1], s.players[2]
    p.hand, p.mana, p.board = { 9 }, 2, { unit(1, 1) }
    enemy.board = { unit(2, 3), unit(3, 2) }
    assert(match.apply(s, 1, { kind = "cast", hand = 1, target = 3 }))
    assert(#p.hand == 0 and p.mana == 0 and #p.board == 1)
    assert(p.board[1].health == 2 and p.board[1].ready)
    assert(#enemy.board == 1 and enemy.board[1].id == 2 and enemy.board[1].health == 5)
    reject(s, 1, { kind = "cast", hand = 1, target = 2 }, "Choose a card in your hand.")
end)

test("spell target failures and cancellation checks preserve the match", function()
    local s = fresh()
    s.players[1].hand, s.players[1].mana = { 9, 10, 1 }, 6
    s.players[1].board = { unit(1, 3, 3), unit(2, 1) }
    s.players[2].board = { unit(3, 3) }
    local before = snapshot(s)
    assert(match.can_play(s, 1, 1) and match.can_play(s, 1, 2))
    assert(snapshot(s) == before)
    reject(s, 1, { kind = "cast", hand = 1, target = 1 }, "Choose an enemy creature.")
    reject(s, 1, { kind = "cast", hand = 1, target = "hero" }, "Choose an enemy creature.")
    reject(s, 1, { kind = "cast", hand = 2, target = 3 }, "Choose a wounded friendly creature.")
    reject(s, 1, { kind = "cast", hand = 2, target = "hero" }, "Choose a wounded friendly creature.")
    reject(s, 1, { kind = "cast", hand = 2, target = 2 }, "That creature is already at full health.")
    reject(s, 1, { kind = "cast", hand = 2, target = 99 }, "Choose a wounded friendly creature.")
    reject(s, 1, { kind = "play", hand = 1 }, "Choose a target for this spell.")
    reject(s, 1, { kind = "cast", hand = 3, target = 3 }, "That card is a creature, not a spell.")
    reject(s, 2, { kind = "cast", hand = 1, target = 1 }, "Wait for your turn.")
    s.players[1].mana = 0
    reject(s, 1, { kind = "cast", hand = 1, target = 3 }, "Not enough mana.")
end)

test("healing caps at starting health, works on a full board, and preserves readiness", function()
    local s = fresh()
    local p = s.players[1]
    p.hand, p.mana = { 10, 10, 9 }, 6
    for i = 1, 5 do p.board[i] = unit(i, 3) end
    p.board[1].health, p.board[1].ready = 4, false
    assert(match.apply(s, 1, { kind = "cast", hand = 1, target = 1 }))
    assert(p.board[1].health == 5 and not p.board[1].ready and #p.board == 5 and p.mana == 5)
    reject(s, 1, { kind = "cast", hand = 1, target = 1 }, "No wounded friendly creature to heal.")
    s.players[2].board = { unit(99, 3) }
    assert(match.apply(s, 1, { kind = "cast", hand = 2, target = 99 }))
    assert(s.players[2].board[1].health == 2 and #p.board == 5)
    p.hand, p.mana = { 9 }, 2
    s.players[2].board = {}
    reject(s, 1, { kind = "cast", hand = 1, target = 99 }, "No enemy creature to target.")
end)

test("legal spells and AI work from either player's side", function()
    for side = 1, 2 do
        local s = fresh()
        s.active = side
        local p, enemy = s.players[side], s.players[3 - side]
        p.hand, p.mana, p.board = { 9 }, 2, {}
        enemy.board = { unit(20, 2), unit(21, 3) }
        local best = ai.choose(s, side)
        assert(best.kind == "cast" and best.target == 20)
        assert(match.apply(s, side, best))
        p.hand, p.mana, p.board = { 10 }, 1, { unit(22, 3, 2) }
        best = ai.choose(s, side)
        assert(best.kind == "cast" and best.target == 22)
        assert(match.apply(s, side, best) and p.board[1].health == 5)
        p.hand, p.mana, p.board = { 9 }, 2, {}
        enemy.board = { unit(23, 4) }
        assert(ai.choose(s, side).kind == "end_turn")
    end
end)

test("spell animations retain lethal targets and show actual capped healing", function()
    local animation = require("game.animation")
    local s = fresh()
    s.players[1].hand, s.players[1].mana = { 9, 10 }, 3
    s.players[1].board = { unit(1, 3, 4) }
    s.players[2].board = { unit(2, 2) }
    local before = animation.snapshot(s)
    local action = { kind = "cast", hand = 1, target = 2 }
    local ok, reason, events = match.apply(s, 1, action)
    assert(ok, reason)
    assert(events)
    local effect = animation.new(before, 1, action, events)
    assert(effect.kind == "cast" and effect.target_side == 2)
    assert(#effect.dead == 1 and effect.damage[1].amount == 3 and #effect.healing == 0)
    before = animation.snapshot(s)
    action = { kind = "cast", hand = 1, target = 1 }
    ok, reason, events = match.apply(s, 1, action)
    assert(ok, reason)
    assert(events)
    effect = animation.new(before, 1, action, events)
    assert(effect.target_side == 1 and #effect.damage == 0 and effect.healing[1].amount == 1)
end)

test("inspection explains public cards and fits at screen edges", function()
    local inspection = require("game.inspection")
    local view = require("game.view")
    local s = fresh()
    s.players[1].hand = { 9, 10, 1, 2, 3, 4, 8 }
    s.players[2].board = { unit(20, 3, 2) }
    local before = snapshot(s)
    for _, region in ipairs(view.regions(s)) do
        local details = inspection.describe(s, region)
        if region.kind == "hand" or region.kind == "unit" then
            assert(details and #details.description > 0)
            local bounds = inspection.bounds(region)
            assert(bounds.x >= 0 and bounds.x + bounds.w <= 1280)
            assert(bounds.y >= 0 and bounds.y + bounds.h <= 720)
        else
            assert(not details)
        end
    end
    local details = inspection.describe(s, { kind = "unit", side = 2, id = 20 })
    assert(details and details.health == 2 and details.description:find("Guard does not block spells", 1, true))
    assert(not inspection.describe(s, nil))
    assert(not inspection.describe(s, { kind = "hand", side = 2, index = 1 }))
    assert(snapshot(s) == before)
end)

test("new catalog entries keep stable identities and do not silently join starter decks", function()
    local cards = require("game.cards")
    local art = require("game.card_art")
    local animation = require("game.animation")
    local baseline = snapshot(fresh())
    local extra_id = 101
    assert(not cards.definitions[extra_id])
    local extra = animation.snapshot(cards.definitions[1])
    extra.name = "Test Spirit"
    cards.definitions[extra_id] = extra
    assert(snapshot(fresh()) == baseline, "Catalog addition changed starter decks")
    local s = fresh()
    s.players[1].hand = { extra_id }
    assert(match.apply(s, 1, { kind = "play", hand = 1 }))
    assert(s.players[1].board[1].card == extra_id)
    assert(art.style(extra).symbol == "moon", "Renaming a card broke its appearance")
    cards.definitions[extra_id] = nil
end)

test("spell variants reuse targeting, amounts and explanations from either side", function()
    local cards = require("game.cards")
    local spells = require("game.spells")
    local animation = require("game.animation")
    local extra_id = 101
    for _, template in ipairs({ 9, 10 }) do
        local extra = animation.snapshot(cards.definitions[template])
        extra.name, extra.cost, extra.amount = "Test Spell", 1, 2
        cards.definitions[extra_id] = extra
        assert(spells.description(extra):find("2", 1, true))
        for side = 1, 2 do
            local s = fresh()
            s.active = side
            s.players[side].hand, s.players[side].mana = { extra_id }, 1
            local target_side = template == 9 and 3 - side or side
            s.players[target_side].board = { unit(50, 3, 2) }
            assert(match.can_play(s, side, 1))
            local action = { kind = "cast", hand = 1, target = 50 }
            assert(match.validate(s, side, action))
            local ok, reason, events = match.apply(s, side, action)
            assert(ok, reason)
            assert(events)
            assert(events[1].side == target_side and events[1].id == 50 and events[1].amount == 2)
            if template == 9 then
                assert(#s.players[target_side].board == 0 and events[2].kind == "death")
            else
                assert(s.players[target_side].board[1].health == 4 and #events == 1)
            end
        end
    end
    cards.definitions[extra_id] = nil
end)

test("unknown effects fail before spending resources or mutating the match", function()
    local cards = require("game.cards")
    local animation = require("game.animation")
    local extra_id = 101
    local extra = animation.snapshot(cards.definitions[9])
    extra.effect = "unimplemented"
    cards.definitions[extra_id] = extra
    local s = fresh()
    s.players[1].hand, s.players[1].mana = { extra_id }, 6
    s.players[2].board = { unit(20, 3) }
    local before = snapshot(s)
    local ok, reason = pcall(match.apply, s, 1, { kind = "cast", hand = 1, target = 20 })
    assert(not ok and type(reason) == "string" and reason:find("Unknown spell effect: unimplemented", 1, true))
    assert(snapshot(s) == before)
    cards.definitions[extra_id] = nil
end)

test("combat reports damage before deaths without retaining live state", function()
    local s = fresh()
    s.players[1].board = { unit(11, 4, 1) }
    s.players[2].board = { unit(22, 2) }
    local ok, reason, events = match.apply(s, 1, { kind = "attack", attacker = 11, target = 22 })
    assert(ok, reason)
    assert(events)
    assert(snapshot(events) == snapshot({
        { kind = "damage", side = 1, id = 11, amount = 3 },
        { kind = "damage", side = 2, id = 22, amount = 5 },
        { kind = "death", side = 1, id = 11 },
        { kind = "death", side = 2, id = 22 },
    }))
    local before = snapshot(s)
    events[1].amount, events[3].id = 999, 999
    assert(snapshot(s) == before)
end)

test("draw outcomes distinguish received cards from full-hand burns", function()
    local animation = require("game.animation")
    for _, full in ipairs({ false, true }) do
        local s = fresh()
        s.players[2].deck = { 1 }
        s.players[2].hand = full and { 1, 1, 2, 2, 3, 3, 4 } or { 1 }
        local before = animation.snapshot(s)
        local action = { kind = "end_turn" }
        local ok, reason, events = match.apply(s, 1, action)
        assert(ok, reason)
        assert(events)
        local effect = animation.new(before, 1, action, events)
        if full then
            assert(#events == 0 and not effect.drawn_hand)
        else
            assert(#events == 1 and events[1].kind == "draw")
            assert(effect.drawn_side == 2 and effect.drawn_hand == 2)
        end
    end
end)

print(passed .. " tests passed")
