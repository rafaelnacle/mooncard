local card_art = require("game.card_art")
local layout = require("game.layout")
local menu = {}
local fonts = {}
local selected = 1
local elapsed = 0
local buttons = {
    { action = "play", label = "Play", x = 500, y = 382, w = 280, h = 54 },
    { action = "quit", label = "Quit", x = 500, y = 450, w = 280, h = 54 },
}
local gold = { 0.84, 0.70, 0.40 }
local muted = { 0.57, 0.65, 0.66 }
local ink = { 0.91, 0.91, 0.84 }

function menu.load()
    for _, size in ipairs({ 14, 18, 22, 54 }) do
        fonts[size] = love.graphics.newFont(size)
    end
end

function menu.enter()
    selected, elapsed = 1, 0
end

function menu.update(dt)
    elapsed = elapsed + math.max(0, dt)
end

function menu.hit(x, y)
    for i, button in ipairs(buttons) do
        if layout.contains(button, x, y) then return button.action, i end
    end
end

function menu.mousemoved(x, y)
    local _, index = menu.hit(x, y)
    if index then selected = index end
end

function menu.mousepressed(x, y, button)
    if button == 1 then return menu.hit(x, y) end
end

function menu.keypressed(key)
    if key == "up" or key == "down" or key == "tab" then
        selected = selected % #buttons + 1
    elseif key == "return" or key == "kpenter" or key == "space" then
        return buttons[selected].action
    end
end

local function text(value, y, size, tint)
    love.graphics.setColor(tint)
    love.graphics.setFont(fonts[size])
    love.graphics.printf(value, 0, y, 1280, "center")
end

local function emblem(x, y, angle, symbol, tint)
    local g = love.graphics
    g.push("all")
    g.translate(x, y + math.sin(elapsed * 0.8 + x) * 5)
    g.rotate(angle)
    g.setColor(0.075, 0.097, 0.115)
    g.rectangle("fill", -67, -94, 134, 188, 8, 8)
    g.setColor(tint[1], tint[2], tint[3], 0.4)
    g.setLineWidth(1)
    g.rectangle("line", -67, -94, 134, 188, 8, 8)
    g.rectangle("line", -59, -86, 118, 172, 5, 5)
    card_art.icon(symbol, 0, 0, 56, tint, 0.75)
    g.pop()
end

function menu.draw()
    local g = love.graphics
    g.clear(0.045, 0.060, 0.075)
    emblem(270, 370, -0.16, "leaf", { 0.40, 0.79, 0.58 })
    emblem(1010, 370, 0.16, "drake", { 0.98, 0.43, 0.34 })
    card_art.icon("moon", 640, 152, 62, gold)
    text("MOONCARD", 220, 54, ink)
    text("THE GROVE DUEL", 292, 14, gold)
    g.setColor(gold[1], gold[2], gold[3], 0.3)
    g.line(560, 334, 720, 334)
    for i, button in ipairs(buttons) do
        local active = i == selected
        g.setColor(active and 0.14 or 0.075, active and 0.16 or 0.097, active and 0.15 or 0.115)
        g.rectangle("fill", button.x, button.y, button.w, button.h, 7, 7)
        g.setColor(active and gold or muted)
        g.setLineWidth(active and 2 or 1)
        g.rectangle("line", button.x, button.y, button.w, button.h, 7, 7)
        text(button.label, button.y + 13, 22, active and gold or ink)
    end
    g.setLineWidth(1)
    text("An offline card duel against the Warden.", 552, 18, muted)
    text("Click to choose  /  Arrow keys + Enter  /  Escape to quit", 664, 14, muted)
end

return menu
