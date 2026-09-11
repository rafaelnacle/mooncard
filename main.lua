local match = require("game.match")
local ai = require("game.ai")
local view = require("game.view")
local animation = require("game.animation")
local state
local selected
local notice
local notice_time = 0
local ai_time = 0

local function restart()
    state = match.new(love.math.random)
    selected, notice = nil, nil
    ai_time, notice_time = 0, 0
    view.reset()
end

local function apply_action(side, action)
    local valid, reason = match.validate(state, side, action)
    if not valid then return false, reason end
    local before = animation.snapshot(state)
    local ok, error_message = match.apply(state, side, action)
    if ok then view.animate(before, state, side, action) end
    return ok, error_message
end

local function act(action)
    local ok, reason = apply_action(1, action)
    if ok then
        selected, notice = nil, nil
        ai_time = 0
    else
        notice, notice_time = reason, 3
    end
end

function love.load()
    view.load()
    restart()
end

function love.update(dt)
    view.update(dt, state)
    if notice then
        notice_time = notice_time - dt
        if notice_time <= 0 then notice = nil end
    end
    if state.active == 2 and not state.winner and not view.busy() then
        ai_time = ai_time + dt
        if ai_time >= 0.8 then
            ai_time = 0
            local action = ai.choose(state, 2)
            if action then apply_action(2, action) end
        end
    end
end

function love.draw()
    view.draw(state, selected, notice)
end

function love.mousepressed(x, y, button)
    if button == 2 then selected, notice = nil, nil; return end
    if button ~= 1 or view.busy() then return end
    local hit = view.hit(state, x, y)
    if not hit then return end
    if hit.kind == "restart" then restart(); return end
    if state.winner then return end
    if state.active ~= 1 then notice, notice_time = "Wait for your turn.", 2; return end
    if hit.kind == "hand" then
        act({ kind = "play", hand = hit.index })
    elseif hit.kind == "end_turn" then
        act({ kind = "end_turn" })
    elseif hit.kind == "unit" and hit.side == 1 then
        local unit = match.unit(state.players[1], hit.id)
        if not unit.ready then
            notice, notice_time = "That creature cannot attack yet.", 3
        else
            selected = selected ~= hit.id and hit.id or nil
            notice = nil
        end
    elseif hit.side == 2 and selected then
        act({ kind = "attack", attacker = selected, target = hit.kind == "hero" and "hero" or hit.id })
    end
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
end
