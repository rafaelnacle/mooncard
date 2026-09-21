local match = require("game.match")
local helpers = require("tests.helpers")
local fresh = helpers.fresh
local unit = helpers.unit
local snapshot = helpers.snapshot
local reject = helpers.reject

return function(test)
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
end
