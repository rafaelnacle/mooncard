local match = require("game.match")
local helpers = require("tests.helpers")
local fresh = helpers.fresh
local unit = helpers.unit
local snapshot = helpers.snapshot

return function(test)
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
end
