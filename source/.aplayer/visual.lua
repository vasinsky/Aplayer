local visual = {}

function visual.get(num, level, timeOffset, dt)
    local alpha = math.min(0.2 + level * 0.8, 1)*2
    local colorShift = 0.94 + math.sin(timeOffset) * 0.06

    if num == 1 then
        for i = 0, 10 do
            local angle = i * (math.pi / 8) + timeOffset
            local radius = 100 + level * 300 + math.sin(timeOffset + i) * 50
            local x = love.graphics.getWidth() / 2 + math.cos(angle) * radius
            local y = love.graphics.getHeight() / 2 + math.sin(angle) * radius
            --15
            love.graphics.circle("fill", x, y, 10 + level * 40)
        end

        for i = 1, 8 do
            for j = 1, 8 do
                local x = love.graphics.getWidth() / 2 + math.cos(i * timeOffset * 0.5) * (j * 50 + level * 200)
                local y = love.graphics.getHeight() / 2 + math.sin(j * timeOffset * 0.5) * (i * 50 + level * 200)
                love.graphics.rectangle("fill", x, y, 2 + level * 10, 8 + level * 10)
            end
        end

        for i = 0, 7 do
            local angle = i * (math.pi / 4) + timeOffset * 0.75
            for j = 1, 4 do
                local r = j * 55 + level * 100
                local dynamicRadius = r + math.sin(timeOffset + j * 0.5) * 60

                local x = love.graphics.getWidth() / 2 + math.cos(angle) * dynamicRadius
                local y = love.graphics.getHeight() / 2 + math.sin(angle) * dynamicRadius
                love.graphics.circle("line", x, y, 5 + level * 40) -- 20 40
            end
        end
    elseif num == 2 then
            for i = 0, 8 do
                local angle = i * (math.pi / 8) + timeOffset
                local radius = 8 + level * 200 + math.sin(timeOffset + i) * 50
                local x = love.graphics.getWidth() / 2 + math.cos(angle) * radius
                local y = love.graphics.getHeight() / 2 + math.sin(angle) * radius
                --15
                love.graphics.circle("fill", x, y, 10 + level * 40)
            end

            local a = 1
            local b = 15

            if math.floor(love.timer.getTime()) % 3 == 0 then
                a, b = b, a
            end

            for i = 1, a do
                for j = 1, b do
                    local x = love.graphics.getWidth() / 2 + math.cos(i * timeOffset * 0.5) * (j * 50 + level * 200)
                    local y = love.graphics.getHeight() / 2 + math.sin(j * timeOffset * 0.5) * (i * 50 + level * 200)
                    love.graphics.rectangle("fill", x, y, 2 + level * 10, 8 + level * 10)
                end
            end

            for i = 0, 8 do
                local angle = i * (math.pi / 4) + timeOffset * 0.75
                for j = 1, 4 do
                    local r = j * 55 + level * 100

                    local x = love.graphics.getWidth() / 2 + math.cos(angle) * 60 * i
                    local y = love.graphics.getHeight() / 2 + math.sin(angle) * 60 * i
                    love.graphics.circle("line", x, y, 14 + level * 30) -- 20 40
                end
            end
    elseif num == 3 then
            for i = 0, 17 do
                local angle = i * (math.pi / 4) + timeOffset * 0.75
                for j = 1, 4 do
                    local r = j * 25 + level * 100
                    local dynamicRadius = r + math.sin(timeOffset + j * 2.5) * 60

                    local x = love.graphics.getWidth() / 2 + math.cos(angle) * dynamicRadius
                    local y = love.graphics.getHeight() / 2 + math.sin(angle) * dynamicRadius

                    love.graphics.circle("fill", x, y, (15 + level * 30) / 3)

                    love.graphics.circle("fill", love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, (10 + level * 20) / 3)
                end
            end

            timeOffset = timeOffset + dt * 0.1
            level = (level + dt * 0.05) % 1

            local centerX = love.graphics.getWidth() / 2
            local centerY = love.graphics.getHeight() / 2
            local numTurns = 1006

            for i = 0, 200 do
                local angle = i * (math.pi / 32) + timeOffset * 0.75
                local radius = i * 10 + level * 300
                local x = centerX + math.cos(angle) * radius
                local y = centerY + math.sin(angle) * radius

                love.graphics.circle("line", x, y, 2 + level * 20)
            end
    end
end

return visual