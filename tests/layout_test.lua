local helpers = require("tests.helpers")
local fresh = helpers.fresh
local unit = helpers.unit

return function(test)
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
end
