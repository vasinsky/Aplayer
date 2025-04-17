local Config = require("Config")
local visual = require("visual")

local baseDir, dir, files, selected = Config.BASE_DIR, Config.BASE_DIR, {}, 1
local currentSound, currentTrack, marqueeText, marqueeX = nil, nil, "", 0
local bgImage = love.graphics.newImage(Config.BG_IMG)
local utf8, bgTransparency, marqueeSpeed = require("utf8"), Config.BG_OPACITY, 50
local markedFile = nil
local eventNext = false
local speedIndex = 1
local speeds = Config.SPEEDS
local displaySpeed = false
local speedTimer = 0

local audioError = false

local escapePressedTime = nil
local escapeHoldDuration = 2

local fftSize = 2048
local spectrum = {}
local canvas
local timeOffset = 0
local maxBars = 64
local barWidth = 5
local maxHeight = 200

local showVisual = false
local numVisual = 1
local keyVisualPressTime = nil
local keyVisualHoldDuration = 1

local buttonRecursivePressTime = nil
local buttonRecursiveHeldFor = 0
local buttonRecursiveHeldThreshold = 2
local buttonRecursiveHeld = false
local recursiveMode = false

local homeDirText = ""

local useFontType, useFontTypeSize, useFontTypeIconPlayStart, useFontTypeHintOffsetY, useFontTypeMarqueeTextYOffset, useFontTypeHintTextYOffset

if Config.USE_SUPPORT_JAPANESE then
    useFontType = "assets/NotoSansJP-Regular.ttf"
    useFontTypeSize = 29
    useFontTypeIconPlayStart = "▶"
    useFontTypeHintOffsetY = "-8"
    useFontTypeMarqueeTextYOffset = "-4"
    useFontTypeHintTextYOffset = "-5"
else
     useFontType = "assets/DejaVuSansMono.ttf"
     useFontTypeSize = 29
     useFontTypeIconPlayStart = "►"
     useFontTypeHintOffsetY = "0"
     useFontTypeMarqueeTextYOffset = "0"
     useFontTypeHintTextYOffset = "0"
end

local success, font = pcall(love.graphics.newFont, useFontType, useFontTypeSize)
if not success then
    error("Failed to load font: " .. tostring(font))
end

local success, fontBig = pcall(love.graphics.newFont, useFontType, 250)
if not success then
    error("Failed to load font: " .. tostring(fontBig))
end

love.graphics.setFont(font)

local colors = Config.COLORS

local playMode, loopMode, equalizerIndex = "Single", false, 1
local equalizerModes = {"Rck", "Pop", "Jzz", "Vcl", "Bss", "Trb", "Mid"}
local scrollOffset, maxVisibleFiles, scrollSpeed, scrollDirection, scrollTimer = 0, 0, 0.2, nil, 0
local controlLocked, numSections, numSubSections, equalizerHeight = false, 90, 9, 25

local filters = {
    Off = nil, Rock = {type = "bandpass", volume = 1.2, highgain = 0.5, lowgain = 0.5},
    Pop = {type = "bandpass", volume = 1.1, highgain = 0.4, lowgain = 0.4}, Jazz = {type = "bandpass", volume = 1.0, highgain = 0.3, lowgain = 0.3},
    Vocal = {type = "bandpass", volume = 1.3, highgain = 0.6, lowgain = 0.6}, Bass = {type = "lowpass", volume = 1.5},
    Treble = {type = "highpass", volume = 1.5}, Mid = {type = "bandpass", volume = 1.2, highgain = 0.5, lowgain = 0.5}
}

local equalizerData = {}
for i = 1, numSections do
    equalizerData[i] = {}
    for j = 1, numSubSections do equalizerData[i][j] = math.random() end
end

local function updateEqualizer()
    for i = 1, numSections do
        for j = 1, numSubSections do
            equalizerData[i][j] = currentSound and currentSound:isPlaying() and math.random() or 0
        end
    end
end

local function togglePlayMode() playMode = playMode == "Single" and "ABC" or playMode == "ABC" and "Shuffle" or "Single" end
local function toggleLoopMode() loopMode = not loopMode end
local function toggleEqualizerMode() equalizerIndex = equalizerIndex % #equalizerModes + 1 if currentSound then currentSound:setFilter(filters[equalizerModes[equalizerIndex]]) end end
local function toggleControlLock() controlLocked = not controlLocked end

local function scanDirectory(path)
   files = {}

   local isDirectoryExists = os.execute("test -d \"" .. path .. "\"") == 0
   print("test -d '" .. path .. "'")

   if not isDirectoryExists then
        print("- Directory not found -")
        files = {"- Directory not found -"}
        return
    end

    local command = ""

    if not recursiveMode then
        command = "find \"" .. path .. "\" -mindepth 1 -maxdepth 1 2>/dev/null | sed 's#.*/##'"
    else
        command = "find \"" .. path .. "\" -mindepth 1 -maxdepth 10 -type f 2>/dev/null | sed 's#\"" .. path .. "\"##'"
    end

    print(command)

    local handle = io.popen(command)
    local output = handle:read("*a")
    handle:close()

    local directories, fileList = {}, {}
    for file in output:gmatch("[^\r\n]+") do
        if not file:match("^%.") then
            local fullPath = ""
            if not recursiveMode then
                fullPath = path .. "/" .. file
            else
                fullPath = path .. "/" .. string.gsub(file, "^" .. Config.MOUNT_DIR, "")
            end
            local isDirectory = os.execute("test -d \"" .. fullPath .. "\"") == 0
            if isDirectory then
                table.insert(directories, file .. "/")
            else
                if not recursiveMode then
                    table.insert(fileList, file)
                else
                    table.insert(fileList, string.sub(file, #path + 1))
                end
            end
        end
    end

    table.sort(directories)
    table.sort(fileList)

    for _, dir in ipairs(directories) do
        table.insert(files, dir)
    end
    for _, file in ipairs(fileList) do
        table.insert(files, file)
    end

    if #files == 0 then
        print("- Empty -")
        files = {"- Empty -"}
    else
        --[[
        print("Scanned files: ")
        for _, file in ipairs(files) do
            print(file)
        end
        --]]
    end
end

local pathHistory, hideDirectoryName = {""}, false

function love.load()
    os.execute("mount --bind \"" .. Config.BASE_DIR .. "\" \"" .. Config.MOUNT_DIR .. "\"")
    os.execute("mount -o remount,ro \"" .. Config.MOUNT_DIR .. "\"")
    --os.execute("unionfs-fuse -o cow " .. Config.BASE_DIR .. "=RO " .. Config.MOUNT_DIR)

    baseDir = Config.MOUNT_DIR
    dir = Config.MOUNT_DIR
    print("baseDir/dir \"" .. baseDir .. "\"")
    scanDirectory(dir)
    stopRequested = false

    canvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.quit()
    os.execute("umount -l \"" .. Config.MOUNT_DIR .. "\"")
end

local function truncateStringWithEllipsis(str, maxLength)
    if utf8.len(str) > maxLength then
        return string.sub(str, 1, utf8.offset(str, maxLength + 1) - 1) .. ".."
    else
        return str
    end
end

function EnterKey()
    --todo : some subtle bug related to switching between nested and normal modes
    selected = selected or 1
    local filePath = dir .. "/" .. files[selected]

    local isDirectory = os.execute("test -d \"" .. filePath .. "\"") == 0
    local isFile = os.execute("test -f \"" .. filePath .. "\"") == 0

    if isDirectory and not eventNext then
        dir = filePath
        table.insert(pathHistory, files[selected])
        scanDirectory(dir)
        selected = 1
        scrollOffset = 0
        hideDirectoryName = false
    elseif isFile then
        markedFile = filePath
        if currentSound then
            currentSound:stop()
            currentSound = nil
        end

        local relativePath = filePath:sub(#Config.MOUNT_DIR + 1)
        local fileForPlay = Config.MUSIC_APP .. "/" .. relativePath

        print("Single")
        print(fileForPlay)

        local success, errMsg = pcall(function()
            currentSound = love.audio.newSource(fileForPlay, "stream")
            if not currentSound then error("Failed to load audio source 232: " .. relativePath .. "\n") end

            currentSound:setPitch(speeds[speedIndex] or 1)

            local filter = filters[equalizerModes[equalizerIndex]]
            if filter then
                currentSound:setFilter(filter)
            end

            currentSound:play()
            soundPlaying = true
        end)

        if not success then
            audioError = "Audio error 246: " .. relativePath .. "\n" .. errMsg
            print(audioError)
            soundPlaying = false
        end

        marqueeText, marqueeX, currentTrack = files[selected], love.graphics.getWidth(), selected
    end
    eventNext = false
end

function love.keypressed(key)
    print(key)

    if (controlLocked and Config.allowR1) or not controlLocked  then
        if key == "n" and currentSound and currentSound:isPlaying() then
            eventNext = true

            if playMode == "Shuffle" then
                    if not shuffleIndices or #shuffleIndices == 0 then
                        shuffleIndices = {}
                        for i = 1, #files do
                            table.insert(shuffleIndices, i)
                        end
                        for i = #shuffleIndices, 2, -1 do
                            local j = math.random(1, i)
                            shuffleIndices[i], shuffleIndices[j] = shuffleIndices[j], shuffleIndices[i]
                        end
                    end

                    selected = table.remove(shuffleIndices, 1)

                    if selected > scrollOffset + maxVisibleFiles then
                        scrollOffset = selected - maxVisibleFiles
                    elseif selected <= scrollOffset then
                        scrollOffset = selected - 1
                    end
                    if scrollOffset < 0 then
                        scrollOffset = 0
                    end
            else
                selected = selected + 1

                if selected > #files then
                    selected = 1
                    scrollOffset = 0
                end

                if selected > scrollOffset + maxVisibleFiles then
                    scrollOffset = scrollOffset + 1
                elseif selected <= scrollOffset then
                    scrollOffset = scrollOffset - 1
                end

                if scrollOffset < 0 then
                    scrollOffset = 0
                end
           end
           EnterKey()
        end
    end

    if key == "c" then toggleControlLock() return end

    if controlLocked then return end

    if key == "k" then
        keyVisualPressTime = love.timer.getTime()
    elseif key == "j" then
        keyVisualPressTime = love.timer.getTime()
    elseif  key == "h" then
        numVisual = (numVisual % 3) + 1
    elseif key == "g" then
        numVisual = 3 - numVisual
    end
    if key == "up" then
        scrollDirection = "up"
        selected = math.max(1, selected - 1)
        if selected <= scrollOffset then scrollOffset = scrollOffset - 1 end
    elseif key == "down" then
        scrollDirection = "down"
        selected = math.min(#files, selected + 1)
        if selected > scrollOffset + maxVisibleFiles then scrollOffset = scrollOffset + 1 end
    elseif key == "return" then
        EnterKey()
    elseif key == "space" then if currentSound then if currentSound:isPlaying() then currentSound:pause() else currentSound:play() end end
    elseif key == "s" then if currentSound then stopRequested = true currentSound:stop() marqueeText, currentTrack = "", nil showVisual = false end
    elseif key == "left" then if currentSound then currentSound:seek(math.max(0, currentSound:tell() - 10)) end
    elseif key == "right" then if currentSound then currentSound:seek(math.min(currentSound:getDuration(), currentSound:tell() + 10)) end
    elseif key == "p" then togglePlayMode()
    elseif key == "l" then toggleLoopMode()
    elseif key == "e" then toggleEqualizerMode()
    elseif key == "escape" then escapePressedTime = love.timer.getTime()
    elseif key == "backspace"  then
        audioError = false
        if selected ~= 1 then selected = 1 scrollOffset = 0
        elseif dir ~= baseDir then
            if dir:sub(-1) == "/" then dir = dir:sub(1, -2) end
            local newDir = dir:match("(.+)/[^/]*$") or baseDir
            dir = newDir
            table.remove(pathHistory)
            scanDirectory(dir)
            selected = 1
            scrollOffset = 0
            hideDirectoryName = false
        end
    elseif key == "i" then
        speedIndex = speedIndex % #speeds + 1
        if currentSound then
            currentSound:setPitch(speeds[speedIndex])
        end
        displaySpeed = true
        speedTimer = 0.8
    end
end

function love.keyreleased(key)
    if key == "escape" then escapePressedTime = nil end
    if key == "up" or key == "down" then scrollDirection, scrollTimer = nil, 0 end
    if key == "k" or key == "j" then keyVisualPressTime = nil  end
end

function love.update(dt)
    if currentSound and (currentSound:isPlaying() or loopMode) and showVisual  and Config.USE_VISUALIZATION then
        timeOffset = timeOffset + dt * 2

        local data = love.audio.getActiveEffects()
        if data then
            for i = 1, fftSize do
                spectrum[i] = data[i] or 0
            end
        end

        local level = spectrum[10] or 1
        local alpha = math.min(0.2 + level * 0.8, 1)*2
        local colorShift = 0.94 + math.sin(timeOffset) * 0.06

        love.graphics.setCanvas(canvas)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(0.04, 0.10, 0.18, 0.05)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(colorShift, 1.00, 0.90)

        if numVisual == 1 then
            visual.get(1, level, timeOffset, dt)
        elseif numVisual == 2 then
            visual.get(2, level, timeOffset, dt)
        elseif numVisual == 3 then
            visual.get(3, level, timeOffset, dt)
        end

        love.graphics.setCanvas()
    end

    if displaySpeed then
        speedTimer = speedTimer - dt
        if speedTimer <= 0 then
            displaySpeed = false
        end
    end

    if marqueeText ~= "" then marqueeX = marqueeX - marqueeSpeed * dt if marqueeX + font:getWidth(marqueeText) < 0 then marqueeX = love.graphics.getWidth() end end

    if scrollDirection then
        scrollTimer = scrollTimer + dt
        if scrollTimer >= scrollSpeed then
            scrollTimer = 0
            if scrollDirection == "up" then selected = math.max(1, selected - 1) if selected <= scrollOffset then scrollOffset = scrollOffset - 1 end
            elseif scrollDirection == "down" then selected = math.min(#files, selected + 1) if selected > scrollOffset + maxVisibleFiles then scrollOffset = scrollOffset + 1 end end
        end
    end

    updateEqualizer()

    if currentSound and not currentSound:isPlaying() and currentSound:tell() == 0  then
        if stopRequested then
            currentSound, marqueeText, currentTrack = nil, "", nil
            stopRequested = false
        elseif playMode == "Single" and not loopMode then currentSound, marqueeText, currentTrack = nil, "", nil
        elseif playMode == "Single" and loopMode then currentSound:play()
        elseif playMode == "ABC" then
            selected = selected + 1
            if selected > #files then
                if loopMode then
                    selected = 1
                else
                    currentSound, marqueeText, currentTrack = nil, "", nil
                    return
                end
            end

            local filePath = dir .. "/" .. files[selected]

            local command = "file --mime-type -b \"" .. filePath .. "\""
            local handle = io.popen(command)
            local result = handle:read("*a")
            handle:close()

            if result and not result:match("directory") then
                local relativePath = filePath:sub(#Config.MOUNT_DIR + 1)
                local fileForPlay = Config.MUSIC_APP .. relativePath
                fileForPlay = fileForPlay

                print("ABC")
                print(fileForPlay)
                print(filePath)

                local success, errMsg = pcall(function()
                    currentSound = love.audio.newSource(fileForPlay, "stream")
                    if not currentSound then error("Failed to load audio source 457: " .. relativePath .. "\n") end

                    currentSound:setPitch(speeds[speedIndex] or 1)

                    local filter = filters[equalizerModes[equalizerIndex]]
                    if filter then
                        currentSound:setFilter(filter)
                    end

                    currentSound:play()
                    soundPlaying = true
                end)

                if not success then
                    audioError = "Audio error 471: ".. relativePath .. "\n" .. errMsg
                    print(audioError)
                    soundPlaying = false
                end

                marqueeText, marqueeX, currentTrack = files[selected], love.graphics.getWidth(), selected
                markedFile = filePath

                if selected > scrollOffset + maxVisibleFiles then
                    scrollOffset = selected - maxVisibleFiles
                elseif selected <= scrollOffset then
                    scrollOffset = selected - 1
                end
                if scrollOffset < 0 then
                    scrollOffset = 0
                end
            end
        elseif playMode == "Shuffle" then
            if not shuffleIndices or #shuffleIndices == 0 then
                shuffleIndices = {}
                for i = 1, #files do
                    table.insert(shuffleIndices, i)
                end
                for i = #shuffleIndices, 2, -1 do
                    local j = math.random(1, i)
                    shuffleIndices[i], shuffleIndices[j] = shuffleIndices[j], shuffleIndices[i]
                end
            end

            selected = table.remove(shuffleIndices, 1)

            local filePath = dir .. "/" .. files[selected]
            local command = "file --mime-type -b \"" .. filePath .. "\""
            local handle = io.popen(command)
            local result = handle:read("*a")
            handle:close()

            if not result:match("directory") and markedFile ~= filePath then
                local relativePath = filePath:sub(#Config.MOUNT_DIR + 1)
                local fileForPlay = Config.MUSIC_APP  .. relativePath
                fileForPlay = fileForPlay:gsub("//+", "/")

                print("Shuffle")
                print(fileForPlay)
                print(filePath)
                print(markedFile)

                local success, errMsg = pcall(function()
                    currentSound = love.audio.newSource(fileForPlay, "stream")
                    if not currentSound then error("Failed to load audio source 520: " .. relativePath .. "\n") end

                    currentSound:setPitch(speeds[speedIndex] or 1)

                    local filter = filters[equalizerModes[equalizerIndex]]
                    if filter then
                        currentSound:setFilter(filter)
                    end

                    currentSound:play()
                    soundPlaying = true
                end)

                if not success then
                    audioError = "Audio error 534: " .. relativePath .. "\n" .. errMsg
                    print(audioError)
                    soundPlaying = false
                end

                marqueeText, marqueeX, currentTrack = files[selected], love.graphics.getWidth(), selected
                markedFile = filePath
            end

            if selected > scrollOffset + maxVisibleFiles then
                scrollOffset = selected - maxVisibleFiles
            elseif selected <= scrollOffset then
                scrollOffset = selected - 1
            end
            if scrollOffset < 0 then
                scrollOffset = 0
            end
        end
    end

    if escapePressedTime then
        local currentTime = love.timer.getTime()
        if currentTime - escapePressedTime >= escapeHoldDuration then
            love.event.quit()
        end
    end

    if keyVisualPressTime then
        local currentTime = love.timer.getTime()
        if currentTime - keyVisualPressTime >= keyVisualHoldDuration then
            if love.keyboard.isDown("k") then
                showVisual = true
            elseif love.keyboard.isDown("j") then
                showVisual = false
            end
        end
    end

    if love.keyboard.isDown("s") then
        if buttonRecursivePressTime == nil then
            buttonRecursivePressTime = love.timer.getTime()
        end
        buttonRecursiveHeldFor = love.timer.getTime() - buttonRecursivePressTime

        if buttonRecursiveHeldFor >= buttonRecursiveHeldThreshold and not buttonRecursiveHeld then
            buttonRecursiveHeld = true
            recursiveMode = not recursiveMode
            print("Recursive mode toggled: " .. (recursiveMode and "ON" or "OFF"))
            selected = 1
            scrollOffset = 0
            scanDirectory(dir)

        end
    else
        buttonRecursivePressTime = nil
        buttonRecursiveHeldFor = 0
        buttonRecursiveHeld = false
    end
end

function love.draw()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local topAreaHeight, bottomAreaHeight, rowHeight, textOffset = 40, 80, 33, (24 - font:getHeight()) / 2

    love.graphics.setColor(1, 1, 1, bgTransparency)
    love.graphics.draw(bgImage, 0, topAreaHeight, 0, screenWidth / bgImage:getWidth(), (screenHeight - topAreaHeight - bottomAreaHeight) / bgImage:getHeight())
    love.graphics.setColor(colors.background)

    local currentTimeText = os.date("%H:%M:%S")
    love.graphics.setColor(colors.shadow)
    love.graphics.printf(currentTimeText, 10 + 2, (topAreaHeight - font:getHeight()) / 2 + 2, screenWidth, "left")
    love.graphics.setColor(colors.text)
    love.graphics.printf(currentTimeText, 10, (topAreaHeight - font:getHeight()) / 2, screenWidth, "left")

    local playTime = ""
    if currentSound and (currentSound:isPlaying() or currentSound:tell() > 0) then
        local position = currentSound:tell()
        local minutes, seconds = math.floor(position / 60), math.floor(position % 60)
        playTime = string.format(" " .. useFontTypeIconPlayStart .. " %02d:%02d", minutes, seconds)
    end

    love.graphics.setColor({1,1,1,0.5})
    love.graphics.printf(playTime, 13, (topAreaHeight - font:getHeight() + 90) / 2, screenWidth, "left")

    local playModeText = "Mode: " .. playMode .. " | Loop: " .. (loopMode and "On" or "Off") .. " | Eq: " .. equalizerModes[equalizerIndex]
    love.graphics.setColor(colors.text)
    love.graphics.printf(playModeText, -30, (topAreaHeight - font:getHeight()) / 2, screenWidth, "right")

    local controlText = (controlLocked and "Locked" or "Unlocked")
    love.graphics.setColor({1,1,1,0.5})
    love.graphics.printf(controlText, -13, (topAreaHeight - font:getHeight() + 90) / 2, screenWidth - 10, "right")

    if dir == baseDir then
        if recursiveMode then
            homeDirText = "- Home - (Nested)"
        else
            homeDirText = "- Home -"
        end

        love.graphics.setColor(colors.shadow)
        love.graphics.printf(homeDirText, 0 + 2, topAreaHeight + 10 + 2, screenWidth, "center")
        love.graphics.setColor(colors.text)
        love.graphics.printf(homeDirText, 0, topAreaHeight + 10, screenWidth, "center")
    elseif not hideDirectoryName then
        local pathText = truncateStringWithEllipsis(table.concat(pathHistory, "/"), 15):gsub("//+", "/")

        if recursiveMode then
            pathText = pathText .. " (Nested)"
        end

        love.graphics.setColor(colors.shadow)
        love.graphics.printf(pathText, 0 + 2, topAreaHeight + 10 + 2, screenWidth, "center")
        love.graphics.setColor(colors.text)
        love.graphics.printf(pathText, 0, topAreaHeight + 10, screenWidth, "center")
    end

    maxVisibleFiles = math.floor((screenHeight - topAreaHeight - bottomAreaHeight - 10 - 30) / rowHeight) - 3
    for i = scrollOffset + 1, math.min(#files, scrollOffset + maxVisibleFiles) do
        local y = (i - scrollOffset) * rowHeight + topAreaHeight + 30
        if i == selected then
            love.graphics.setColor(colors.highlight)
            love.graphics.rectangle("fill", 0, y-4, screenWidth, rowHeight)
            love.graphics.setColor(colors.text)
        elseif love.filesystem.getInfo(dir .. "/" .. files[i], "directory") then
            love.graphics.setColor(colors.directory)
        else
            love.graphics.setColor(colors.text)
        end

        local fileText
        local path = dir .. "/" .. files[i]
        local handle = io.popen("test -d '" .. path .. "' && echo 1 || echo 0")
        local isDir = handle:read("*a")
        handle:close()

        if tonumber(isDir) == 1 then
            fileText = "♫ " .. files[i]
        else
            fileText = "♪ " .. files[i]
        end

        local currentTrackFullName = dir .. "/" .. files[i]

        if markedFile then markedFile = markedFile:gsub("//+", "/") else markedFile = "" end
        currentTrackFullName = currentTrackFullName:gsub("//+", "/")

        if currentTrack == i  and markedFile == currentTrackFullName or ( currentSound and markedFile:find(files[i], 1, true) and fileText:find("♫", 1, true) ) then
            love.graphics.setColor(colors.currentTrackBg)
            love.graphics.rectangle("fill", 0, y-4, screenWidth, rowHeight)
            love.graphics.setColor(colors.currentTrack)
            love.graphics.setColor(colors.shadow)
            love.graphics.print(truncateStringWithEllipsis("▶ " .. fileText, 43), 10 + 2, y + textOffset + 2)
            love.graphics.setColor(colors.text)
            love.graphics.print(truncateStringWithEllipsis("▶ " .. fileText, 43), 10, y + textOffset)
        else
            love.graphics.setColor(colors.shadow)
            love.graphics.print(truncateStringWithEllipsis(fileText, 43), 10 + 2, y + textOffset + 2)
            love.graphics.setColor(colors.text)
            love.graphics.print(truncateStringWithEllipsis(fileText, 43), 10, y + textOffset)
        end
    end

    local equalizerY, barWidth = screenHeight - bottomAreaHeight - equalizerHeight - 62, screenWidth / numSections
    for i = 1, numSections do
        for j = 1, numSubSections do
            local barHeight = equalizerData[i][j] * equalizerHeight
            local colorFactor = j / numSubSections
            love.graphics.setColor(colors.equalizer[1] * colorFactor, colors.equalizer[2] * colorFactor, colors.equalizer[3] * colorFactor)
            love.graphics.rectangle("fill", (i - 1) * barWidth, equalizerY + (1 - equalizerData[i][j]) * equalizerHeight, barWidth - 2, barHeight)
        end
    end

    if #files > maxVisibleFiles then
        local scrollBarHeight = (maxVisibleFiles / #files) * (screenHeight - topAreaHeight - bottomAreaHeight)
        local scrollBarY = topAreaHeight + (scrollOffset / #files) * (screenHeight - topAreaHeight - bottomAreaHeight)
        love.graphics.setColor(colors.scrollBar)
        love.graphics.rectangle("fill", screenWidth - 10, scrollBarY, 10, scrollBarHeight)
    end

    if currentSound and (currentSound:isPlaying() or currentSound:tell() > 0) then
        local marqueeTextOffset = 6
        love.graphics.setColor(colors.shadow)
        love.graphics.print(marqueeText, marqueeX + 2 + useFontTypeMarqueeTextYOffset, screenHeight - bottomAreaHeight +marqueeTextOffset - rowHeight * 2 + 2 + useFontTypeMarqueeTextYOffset)
        love.graphics.setColor(colors.text)
        love.graphics.print(marqueeText, marqueeX, screenHeight - bottomAreaHeight + marqueeTextOffset - rowHeight * 2 + useFontTypeMarqueeTextYOffset)

        if currentSound then
            local duration = currentSound:getDuration()
            local progressBarOffset = 10
            if duration > 0 then
                local position, progress = currentSound:tell(), currentSound:tell() / duration
                love.graphics.setColor(colors.progressBar)
                love.graphics.rectangle("fill", 10, screenHeight - bottomAreaHeight - rowHeight + progressBarOffset, (screenWidth - 20) * progress, 10)
                love.graphics.setColor(colors.border)
                love.graphics.rectangle("line", 10, screenHeight - bottomAreaHeight - rowHeight + progressBarOffset, screenWidth - 20, 10)
            end
        end
    end

    local buttonFont = love.graphics.newFont(22)
    local mainFont = font

    local controlHintLines = {
        {{"Fn", "Exit (2s)"}, {"A", "Play"}, {"Y", "Pause/Play"}, {"X", "Stp"}, {"L1", "Mode"}},
        {{"L2", "Loop"}, {"R1", "Nxt"}, {"R2", "Eq"}, {"B", "UP"}, {"start", "Lock"}, {"select", "speed"}}
    }

    local yStart = screenHeight - bottomAreaHeight + (bottomAreaHeight - mainFont:getHeight() - 33) / 2 + useFontTypeHintOffsetY
    local lineHeight = mainFont:getHeight() + 6
    local buttonHeight = buttonFont:getHeight() + 6

    local pairSpacing = 15

    for lineIndex, controlHintText in ipairs(controlHintLines) do
        local totalWidth = 0
        local elementWidths = {}

        for _, element in ipairs(controlHintText) do
            local btn, action = element[1], element[2]
            local buttonWidth = buttonFont:getWidth(btn) + 16
            local textWidth = mainFont:getWidth(action)
            local elementWidth = buttonWidth + textWidth + pairSpacing
            table.insert(elementWidths, {buttonWidth, textWidth, elementWidth})
            totalWidth = totalWidth + elementWidth
        end

        local xPos = screenWidth / 2 - totalWidth / 2
        local yPos = yStart + (lineIndex - 1) * lineHeight

        for i, element in ipairs(controlHintText) do
            local btn, action = element[1], element[2]
            local buttonWidth, textWidth, elementWidth = unpack(elementWidths[i])
            love.graphics.setColor(0.17, 0.27, 0.37)
            if btn == "A" or btn == "Y" or btn == "X" or btn == "B" then
                love.graphics.circle("fill", xPos + buttonWidth / 2, yPos + buttonHeight / 2, buttonWidth / 2)
            else
                love.graphics.rectangle("fill", xPos, yPos, buttonWidth, buttonHeight, 8)
            end

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(buttonFont)
            love.graphics.printf(btn, xPos, yPos + 3, buttonWidth, "center")
            xPos = xPos + buttonWidth + 4
            love.graphics.setFont(mainFont)
            love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.5)
            love.graphics.print(action, xPos, yPos+useFontTypeHintTextYOffset)
            xPos = xPos + textWidth + pairSpacing
        end
    end

    if displaySpeed then
        love.graphics.setFont(fontBig)
        local textWidth = fontBig:getWidth(speeds[speedIndex] .. "X")
        local textHeight = fontBig:getHeight()
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(speeds[speedIndex] .. "X", (love.graphics.getWidth() - textWidth) / 2 + 3, (love.graphics.getHeight() - textHeight) / 2 + 3 )
        love.graphics.setFont(font)
    end

    if currentSound and (currentSound:isPlaying() or loopMode) and showVisual and Config.USE_VISUALIZATION  then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(canvas, 0, 0)
    end

    if audioError then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(audioError .. "\n\n Press \"B\" to close", 10, 10, love.graphics.getWidth() - 20)
    end
end