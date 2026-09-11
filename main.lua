local title_font
local hint_font

function love.load()
    love.graphics.setBackgroundColor(0.06, 0.07, 0.10)
    title_font = love.graphics.newFont(48)
    hint_font = love.graphics.newFont(18)
end

function love.draw()
    local width, height = love.graphics.getDimensions()
    local gap = 20
    local text_height = title_font:getHeight() + gap + hint_font:getHeight()
    local top = (height - text_height) / 2

    love.graphics.setColor(0.93, 0.94, 0.98)
    love.graphics.setFont(title_font)
    love.graphics.printf("Mooncard", 0, top, width, "center")

    love.graphics.setColor(0.62, 0.65, 0.73)
    love.graphics.setFont(hint_font)
    love.graphics.printf("Press Escape to quit.", 0,
        top + title_font:getHeight() + gap, width, "center")
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
