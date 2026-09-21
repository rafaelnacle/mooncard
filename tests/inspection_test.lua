local helpers = require("tests.helpers")
local fresh = helpers.fresh
local unit = helpers.unit
local snapshot = helpers.snapshot

return function(test)
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
end
