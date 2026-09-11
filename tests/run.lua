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
    local ok, error_message = match.apply(state, side, action)
    assert(not ok and error_message == reason, error_message)
    assert(snapshot(state) == before, "Rejected action mutated state")
end

test("opening hands, decks, first draw and mana", function()
    local s = fresh()
    assert(s.active == 1 and s.turn == 1)
    assert(#s.players[1].hand == 4 and #s.players[1].deck == 8)
    assert(#s.players[2].hand == 3 and #s.players[2].deck == 9)
    assert(s.players[1].mana == 1 and s.players[2].mana == 0)
    for _, p in ipairs(s.players) do
        local counts = { 0, 0, 0, 0 }
        for _, zone in ipairs({ p.deck, p.hand }) do
            for _, card in ipairs(zone) do counts[card] = counts[card] + 1 end
        end
        for _, count in ipairs(counts) do assert(count == 3) end
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
    assert(match.apply(s, 1, action))
    local effect = animation.new(before, s, 1, action)
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
    assert(match.apply(s, 1, action))
    local effect = animation.new(before, s, 1, action)
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
    assert(match.apply(s, 1, action))
    local effect = animation.new(before, s, 1, action)
    assert(s.winner == 1 and not before.winner)
    assert(#effect.dead == 0 and #effect.damage == 1)
    assert(effect.damage[1].id == "hero" and effect.damage[1].amount == 5)
    s = fresh()
    s.players[2].deck = {}
    before = animation.snapshot(s)
    action = { kind = "end_turn" }
    assert(match.apply(s, 1, action))
    effect = animation.new(before, s, 1, action)
    assert(not effect.drawn_hand and effect.damage[1].amount == 1)
end)

print(passed .. " tests passed")
