local match = require("game.match")
local ai = require("game.ai")
local helpers = require("tests.helpers")
local fresh = helpers.fresh
local unit = helpers.unit
local snapshot = helpers.snapshot

return function(test)
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
end
