local match = require("game.match")
local helpers = require("tests.helpers")
local fresh = helpers.fresh
local unit = helpers.unit
local snapshot = helpers.snapshot
local reject = helpers.reject

return function(test)
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
end
