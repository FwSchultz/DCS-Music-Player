-- DCS Music Player v0.5.0
-- Standalone DCS Lua implementation.
-- Features: playlist, OGG/WAV duration parsing, Auto-Next, shuffle, logging, persistent config.

local function loadDCSMusicPlayer()
    package.path = package.path .. ";.\\Scripts\\?.lua;.\\Scripts\\UI\\?.lua;"

    local lfs = require("lfs")
    local U = require("me_utilities")
    local Skin = require("Skin")
    local Button = require('Button')
    local Panel = require('Panel')
    local DialogLoader = require("DialogLoader")
    local Tools = require("tools")

    local socketOk, socket = pcall(require, "socket")

    local APP = "DCS-Music-Player"
    local VERSION = "0.5.0"

    local baseConfigDir = lfs.writedir() .. "Config\\" .. APP .. "\\"
    local musicDir = baseConfigDir .. "Music\\"
    local configFile = baseConfigDir .. "config.lua"
    local logFilePath = lfs.writedir() .. "Logs\\" .. APP .. ".log"
    local dialogFile = lfs.writedir() .. "Scripts\\" .. APP .. "\\PlayerWindow.dlg"

    lfs.mkdir(baseConfigDir)
    lfs.mkdir(musicDir)

    local logFile = io.open(logFilePath, "w")

    local function now()
        if socketOk and socket and socket.gettime then
            return socket.gettime()
        end
        return os.time()
    end

    local function log(message)
        message = tostring(message or "")
        if logFile then
            logFile:write("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. message .. "\r\n")
            logFile:flush()
        end
        if net and net.log then
            net.log("[" .. APP .. "] " .. message)
        end
    end

    local config
    local window
    local panel
    local defaultWindowSkin
    local hiddenWindowSkin = Skin.windowSkinChatMin()
    local isHidden = false

    local btnPrev
    local btnPlay
    local btnStop
    local btnNext
    local btnShuffle
    local playlistDropdownButton
    local playlistDropdownPanel
    local playlistDropdownButtons = {}
    local playlistDropdownOpen = false
    local playlistDropdownBaseHeight = nil
    local volumeSlider
    local statusDisplay
    local volumeValueDisplay

    local playlists = {}
    local playlistNames = {}
    local currentPlaylistName = nil
    local playlist = {}
    local currentIndex = 1
    local isPlaying = false
    local currentStartedAt = nil
    local currentDuration = nil
    local autoNextHandled = false
    local lastFrameCheck = 0
    local lastLoggedVolume = nil
    local lastVolumeLogAt = 0
    local marqueeOffset = 1
    local lastMarqueeTick = 0
    local marqueePad = "     •     "
    local marqueeWidth = 27

    local function defaultConfig()
        return {
            version = 2,
            hideOnLaunch = false,
            volume = 70,
            inactiveOpacity = 0.25,
            hoverOpacity = 1.00,
            autoNext = true,
            autoNextGraceSeconds = 0.35,
            currentPlaylist = nil,
            windowPosition = {x = 200, y = 200},
            windowSize = {w = 328, h = 90},
            hotkeys = {
                toggle = "Ctrl+Shift+8",
                stop = "Ctrl+Shift+1",
                previous = "Ctrl+Shift+2",
                play = "Ctrl+Shift+3",
                next = "Ctrl+Shift+4",
                shuffle = "Ctrl+Shift+5",
                volumeDown = "Ctrl+Shift+6",
                volumeUp = "Ctrl+Shift+7",
                reload = "Ctrl+Shift+9",
                playlistPrevious = "Ctrl+Shift+0",
                playlistNext = "Ctrl+Shift+-",
            }
        }
    end

    local function mergeDefaults(target, defaults)
        if type(target) ~= "table" then target = {} end
        for k, v in pairs(defaults) do
            if target[k] == nil then
                target[k] = v
            elseif type(v) == "table" and type(target[k]) == "table" then
                target[k] = mergeDefaults(target[k], v)
            end
        end
        return target
    end

    local function saveConfig()
        if not config then return end
        U.saveInFile(config, "config", configFile)
    end

    local function loadConfig()
        local loaded = Tools.safeDoFile(configFile, false)
        if loaded and loaded.config then
            config = mergeDefaults(loaded.config, defaultConfig())
            config.version = 2
            saveConfig()
            log("Config loaded/migrated: " .. configFile)
        else
            config = defaultConfig()
            saveConfig()
            log("Default config created: " .. configFile)
        end

        config.volume = tonumber(config.volume) or 70

        config.inactiveOpacity = tonumber(config.inactiveOpacity) or 0.25
        config.hoverOpacity = tonumber(config.hoverOpacity) or 1.00
        config.inactiveOpacity = math.max(0.05, math.min(1.00, config.inactiveOpacity))
        config.hoverOpacity = math.max(0.05, math.min(1.00, config.hoverOpacity))

        config.autoNextGraceSeconds = tonumber(config.autoNextGraceSeconds) or 0.35
        config.windowPosition = config.windowPosition or {x = 200, y = 200}
        config.windowSize = config.windowSize or {w = 328, h = 90}
        config.hotkeys = config.hotkeys or defaultConfig().hotkeys
    end

    local function u32le(data, pos)
        local b1, b2, b3, b4 = data:byte(pos, pos + 3)
        if not b4 then return nil end
        return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end

    local function u64le(data, pos)
        local value = 0
        local multiplier = 1
        for i = 0, 7 do
            local b = data:byte(pos + i)
            if not b then return nil end
            value = value + b * multiplier
            multiplier = multiplier * 256
        end
        return value
    end

    local function getWavDuration(path)
        local f = io.open(path, "rb")
        if not f then return nil, "cannot open WAV" end

        local data = f:read(262144)
        f:close()

        if not data or data:sub(1, 4) ~= "RIFF" or data:sub(9, 12) ~= "WAVE" then
            return nil, "invalid WAV header"
        end

        local fmtPos = data:find("fmt ", 13, true)
        if not fmtPos then return nil, "WAV fmt chunk missing" end

        local byteRate = u32le(data, fmtPos + 16)
        if not byteRate or byteRate <= 0 then
            return nil, "invalid WAV byte rate"
        end

        local dataPos = data:find("data", fmtPos + 4, true)
        if not dataPos then return nil, "WAV data chunk missing" end

        local dataSize = u32le(data, dataPos + 4)
        if not dataSize then return nil, "invalid WAV data size" end

        return dataSize / byteRate
    end

    local function getOggDuration(path)
        local f = io.open(path, "rb")
        if not f then return nil, "cannot open OGG" end

        local sampleRate = nil
        local lastGranule = nil
        local buffer = ""
        local totalRead = 0
        local maxHeaderScan = 524288

        while true do
            local chunk = f:read(65536)
            if not chunk or #chunk == 0 then break end

            totalRead = totalRead + #chunk
            buffer = buffer .. chunk

            if not sampleRate and totalRead <= maxHeaderScan then
                local vorbisPos = buffer:find(string.char(1) .. "vorbis", 1, true)
                if vorbisPos then
                    sampleRate = u32le(buffer, vorbisPos + 12)
                end
            end

            local searchFrom = 1
            while true do
                local p = buffer:find("OggS", searchFrom, true)
                if not p then break end

                if #buffer >= p + 13 then
                    local granule = u64le(buffer, p + 6)
                    if granule and granule > 0 then
                        lastGranule = granule
                    end
                end

                searchFrom = p + 1
            end

            -- Preserve overlap in case an OggS/page header spans two chunks.
            if #buffer > 131072 then
                buffer = buffer:sub(#buffer - 131071)
            end
        end

        f:close()

        if not sampleRate or sampleRate <= 0 then
            return nil, "invalid/missing OGG sample rate"
        end

        if not lastGranule or lastGranule <= 0 then
            return nil, "final OGG granule position missing"
        end

        return lastGranule / sampleRate
    end

    local function detectDuration(path, ext)
        if ext == ".wav" then
            return getWavDuration(path)
        elseif ext == ".ogg" then
            return getOggDuration(path)
        end
        return nil, "unsupported extension"
    end

    local function lowerExtension(filename)
        local ext = filename:match("^.+(%.[^%.]+)$")
        return ext and string.lower(ext) or nil
    end

    local function displayName(filename)
        return filename:match("(.+)%..+$") or filename
    end

    local function sortTracks(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end

    local function formatTime(seconds)
        if not seconds then return "--:--" end
        seconds = math.max(0, math.floor(seconds + 0.5))
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        return string.format("%d:%02d", m, s)
    end

    local function scanTracksInDirectory(dirPath)
        local tracks = {}

        local ok, err = pcall(function()
            for file in lfs.dir(dirPath) do
                if file ~= "." and file ~= ".." then
                    local fullPath = dirPath .. file
                    local attrs = lfs.attributes(fullPath)

                    if attrs and attrs.mode == "file" then
                        local ext = lowerExtension(file)
                        if ext == ".ogg" or ext == ".wav" then
                            local duration = nil
                            local durationErr = nil

                            local durationOk, result, errText = pcall(detectDuration, fullPath, ext)
                            if durationOk then
                                duration = result
                                durationErr = errText
                            else
                                durationErr = result
                            end

                            table.insert(tracks, {
                                path = fullPath,
                                filename = file,
                                name = displayName(file),
                                ext = ext,
                                duration = duration,
                            })

                            if duration then
                                log(string.format(
                                    "Track indexed: %s | duration=%s",
                                    file,
                                    formatTime(duration)
                                ))
                            else
                                log(string.format(
                                    "Track indexed: %s | duration=unknown | %s",
                                    file,
                                    tostring(durationErr)
                                ))
                            end
                        end
                    end
                end
            end
        end)

        if not ok then
            log("ERROR while reading playlist directory '" .. tostring(dirPath) .. "': " .. tostring(err))
        end

        table.sort(tracks, sortTracks)
        return tracks
    end

    -- Forward declarations: playlist selection callbacks use these functions
    -- before their implementations appear later in this file.
    local resetPlaybackTimer
    local playCurrent
    local setTitle
    local rebuildPlaylistDropdown
    local closePlaylistDropdown

    local function reloadPlaylists()
        playlists = {}
        playlistNames = {}

        -- Root files are exposed as a fallback playlist named "Main".
        local rootTracks = scanTracksInDirectory(musicDir)
        if #rootTracks > 0 then
            playlists["Main"] = rootTracks
            table.insert(playlistNames, "Main")
        end

        local ok, err = pcall(function()
            for entry in lfs.dir(musicDir) do
                if entry ~= "." and entry ~= ".." then
                    local fullPath = musicDir .. entry .. "\\"
                    local attrs = lfs.attributes(fullPath)

                    if attrs and attrs.mode == "directory" then
                        local tracks = scanTracksInDirectory(fullPath)
                        if #tracks > 0 then
                            playlists[entry] = tracks
                            table.insert(playlistNames, entry)
                        else
                            log("Playlist folder ignored (no OGG/WAV): " .. entry)
                        end
                    end
                end
            end
        end)

        if not ok then
            log("ERROR while scanning playlist folders: " .. tostring(err))
        end

        table.sort(playlistNames, function(a, b)
            return string.lower(a) < string.lower(b)
        end)

        if #playlistNames == 0 then
            currentPlaylistName = nil
            playlist = {}
            currentIndex = 1
            isPlaying = false
            currentStartedAt = nil
            currentDuration = nil

            if window then
                window:setText(" DCS Music Player - no playlists/tracks")
            end

            log("Playlists reloaded: 0 playlists")
            return false
        end

        local desired = config.currentPlaylist
        if desired and playlists[desired] then
            currentPlaylistName = desired
        elseif currentPlaylistName and playlists[currentPlaylistName] then
            -- keep current
        else
            currentPlaylistName = playlistNames[1]
        end

        playlist = playlists[currentPlaylistName]
        currentIndex = 1
        config.currentPlaylist = currentPlaylistName
        saveConfig()
        if playlistDropdownButton then
            playlistDropdownButton:setText("≡")
        end

        if closePlaylistDropdown then
            closePlaylistDropdown()
        end

        log(string.format(
            "Playlists reloaded: %d playlist(s) | active=%s | tracks=%d",
            #playlistNames,
            tostring(currentPlaylistName),
            #playlist
        ))

        if rebuildPlaylistDropdown then
            rebuildPlaylistDropdown()
        end

        return true
    end

    local function selectPlaylistByName(name, autoplay)
        if not name or not playlists[name] then
            return false
        end

        if isPlaying then
            sound.stopPreview()
        end

        currentPlaylistName = name
        playlist = playlists[name]
        currentIndex = 1
        isPlaying = false
        resetPlaybackTimer()

        config.currentPlaylist = currentPlaylistName
        saveConfig()

        if playlistDropdownButton then
            playlistDropdownButton:setText("≡")
        end

        -- Selecting an entry should always collapse the dropdown immediately.
        if closePlaylistDropdown then
            closePlaylistDropdown()
        end

        marqueeOffset = 1

        log(string.format(
            "Playlist selected: %s | tracks=%d",
            currentPlaylistName,
            #playlist
        ))

        if autoplay then
            playCurrent()
        else
            setTitle("")
        end

        return true
    end

    local function cyclePlaylist(direction, autoplay)
        log(string.format(
            "Playlist cycle requested: direction=%s | current=%s",
            tostring(direction),
            tostring(currentPlaylistName)
        ))

        if #playlistNames == 0 then
            if not reloadPlaylists() then return end
        end

        local currentPos = 1
        for i, name in ipairs(playlistNames) do
            if name == currentPlaylistName then
                currentPos = i
                break
            end
        end

        currentPos = currentPos + direction
        if currentPos < 1 then currentPos = #playlistNames end
        if currentPos > #playlistNames then currentPos = 1 end

        local targetName = playlistNames[currentPos]
        log("Playlist cycle target: " .. tostring(targetName))
        selectPlaylistByName(targetName, autoplay)
    end

    local function buildHeaderTitle(trackName)
        trackName = tostring(trackName or "")
        if trackName == "" then
            return "♫"
        end

        if #trackName <= marqueeWidth then
            marqueeOffset = 1
            return "♫  " .. trackName
        end

        local loopText = trackName .. marqueePad
        local n = #loopText
        if marqueeOffset < 1 or marqueeOffset > n then
            marqueeOffset = 1
        end

        local doubled = loopText .. loopText
        local visible = doubled:sub(marqueeOffset, marqueeOffset + marqueeWidth - 1)
        return "♫  " .. visible
    end

    setTitle = function(prefix)
        if not window then return end

        if #playlist == 0 then
            window:setText("♫")
            return
        end

        local track = playlist[currentIndex]
        if playlistDropdownButton then
            playlistDropdownButton:setText("≡")
        end

        window:setText(buildHeaderTitle(track.name))
    end

    local function logVolumeDebounced(value)
        local t = now()
        if lastLoggedVolume ~= value and (t - lastVolumeLogAt >= 0.30) then
            log("Volume: " .. tostring(value))
            lastLoggedVolume = value
            lastVolumeLogAt = t
        end
    end

    local function setVolume(value, forceLog)
        value = math.max(0, math.min(100, math.floor((tonumber(value) or 70) + 0.5)))
        config.volume = value

        if volumeSlider and math.floor(volumeSlider:getValue() + 0.5) ~= value then
            volumeSlider:setValue(value)
        end
        if volumeValueDisplay then
            volumeValueDisplay:setText(tostring(value) .. "%")
        end

        sound.setEffectsGain(value / 100.0)
        saveConfig()

        if forceLog then
            log("Volume: " .. tostring(value))
            lastLoggedVolume = value
            lastVolumeLogAt = now()
        else
            logVolumeDebounced(value)
        end
    end

    resetPlaybackTimer = function()
        currentStartedAt = nil
        currentDuration = nil
        autoNextHandled = false
    end

    playCurrent = function()
        if #playlist == 0 and not reloadPlaylists() then
            return
        end

        local track = playlist[currentIndex]
        if not track then
            log("ERROR: current track not found")
            return
        end

        sound.stopPreview()

        local ok, err = pcall(function()
            sound.playPreview(track.path)
        end)

        if not ok then
            isPlaying = false
            resetPlaybackTimer()
            log("ERROR playing '" .. tostring(track.path) .. "': " .. tostring(err))
            if window then window:setText("♫  Playback error - see log") end
            return
        end

        isPlaying = true
        currentStartedAt = now()
        currentDuration = track.duration
        autoNextHandled = false
        marqueeOffset = 1

        setTitle("PLAY")
        log(string.format(
            "Playing: %s | duration=%s | autoNext=%s",
            track.path,
            formatTime(track.duration),
            tostring(config.autoNext)
        ))
    end

    local function stop()
        sound.stopPreview()
        isPlaying = false
        resetPlaybackTimer()
        marqueeOffset = 1
        setTitle("STOP")
        log("Stopped")
    end

    local function previous()
        if #playlist == 0 and not reloadPlaylists() then return end
        currentIndex = currentIndex - 1
        if currentIndex < 1 then currentIndex = #playlist end
        playCurrent()
    end

    local function nextTrack(reason)
        if #playlist == 0 and not reloadPlaylists() then return end
        currentIndex = currentIndex + 1
        if currentIndex > #playlist then currentIndex = 1 end

        if reason then
            log("Next track: " .. reason)
        end

        playCurrent()
    end

    local function shuffle()
        if #playlist == 0 and not reloadPlaylists() then return end

        if #playlist == 1 then
            currentIndex = 1
        else
            local old = currentIndex
            repeat
                currentIndex = math.random(1, #playlist)
            until currentIndex ~= old
        end

        log("Shuffle selected track " .. tostring(currentIndex))
        playCurrent()
    end

    local function show()
        if not window then return end
        window:setVisible(true)
        window:setSkin(defaultWindowSkin)
        panel:setVisible(true)
        window:setHasCursor(true)
        isHidden = false
        setTitle(isPlaying and "PLAY" or "")
    end

    local function hide()
        if not window then return end
        window:setSkin(hiddenWindowSkin)
        panel:setVisible(false)
        window:setHasCursor(false)
        isHidden = true
    end

    local function toggle()
        if isHidden then show() else hide() end
    end

    local function handleMove(self)
        local x, y = self:getPosition()
        config.windowPosition = {x = x, y = y}
        saveConfig()
    end

    local function handleResize(self)
        local w, h = self:getSize()

        w = math.max(328, w)
        h = math.max(90, h)

        panel:setBounds(0, 0, w, h - 20)

        local margin = 8
        local gap = 6
        local controlsY = 5
        local volumeY = 36
        local buttonH = 26
        local iconW = 48
        local shuffleW = 52
        local playlistIconW = 48
        local menuW = math.min(220, math.max(180, w - margin * 2))

        btnPrev:setBounds(margin, controlsY, iconW, buttonH)
        btnPlay:setBounds(margin + (iconW + gap), controlsY, iconW, buttonH)
        btnStop:setBounds(margin + (iconW + gap) * 2, controlsY, iconW, buttonH)
        btnNext:setBounds(margin + (iconW + gap) * 3, controlsY, iconW, buttonH)
        btnShuffle:setBounds(margin + (iconW + gap) * 4, controlsY, shuffleW, buttonH)

        local playlistX = margin + (iconW + gap) * 4 + shuffleW + gap
        playlistDropdownButton:setBounds(playlistX, controlsY, playlistIconW, buttonH)

        local volumeValueX = playlistX + playlistIconW - 54
        if volumeValueDisplay then volumeValueDisplay:setBounds(volumeValueX, volumeY, 54, 20) end
        volumeSlider:setBounds(margin, volumeY - 5, volumeValueX - gap - margin, 20)

        if playlistDropdownPanel then
            local menuX = math.min(playlistX, w - margin - menuW)
            playlistDropdownPanel:setBounds(
                menuX,
                controlsY + buttonH + 2,
                menuW,
                math.max(1, #playlistNames * buttonH)
            )
            for i, button in ipairs(playlistDropdownButtons) do
                button:setBounds(0, (i - 1) * buttonH, menuW, buttonH)
            end
        end

        config.windowSize = {w = w, h = h}
        saveConfig()
    end

    local function addHotkey(key, fn)
        if key and key ~= "" then
            window:addHotKeyCallback(key, fn)
        end
    end


    closePlaylistDropdown = function()
        if not playlistDropdownOpen then
            return
        end

        playlistDropdownOpen = false

        if playlistDropdownPanel then
            playlistDropdownPanel:setVisible(false)
        end

        if window and playlistDropdownBaseHeight then
            local w, _ = window:getSize()
            window:setSize(w, playlistDropdownBaseHeight)
        end

        if playlistDropdownButton then
            playlistDropdownButton:setText("≡")
        end

        log("Playlist dropdown closed")
    end

    local function openPlaylistDropdown()
        if playlistDropdownOpen then
            closePlaylistDropdown()
            return
        end

        if #playlistNames == 0 then
            log("Playlist dropdown: no playlists available")
            return
        end

        rebuildPlaylistDropdown()

        local w, h = window:getSize()
        playlistDropdownBaseHeight = h
        playlistDropdownOpen = true

        local itemHeight = 28
        local extraHeight = (#playlistNames * itemHeight) + 4
        window:setSize(w, h + extraHeight)

        if playlistDropdownPanel then
            playlistDropdownPanel:setVisible(true)
        end

        if playlistDropdownButton then
            playlistDropdownButton:setText("≡")
        end

        log(string.format("Playlist dropdown opened: %d entries", #playlistNames))
    end

    rebuildPlaylistDropdown = function()
        if not panel or not playlistDropdownButton then
            return
        end

        -- Existing buttons stay allocated; hide them and rebuild the current list.
        for _, button in ipairs(playlistDropdownButtons) do
            button:setVisible(false)
        end
        playlistDropdownButtons = {}

        if not playlistDropdownPanel then
            playlistDropdownPanel = Panel.new()
            playlistDropdownPanel:setVisible(false)
            panel:insertWidget(playlistDropdownPanel)
        end

        local buttonSkin = playlistDropdownButton:getSkin()
        local windowW, _ = window:getSize()
        local selectorX, _ = playlistDropdownButton:getPosition()
        local selectorW = math.min(220, windowW - 16)
        local itemHeight = 28

        for i, name in ipairs(playlistNames) do
            local selectedName = name
            local button = Button.new(name)
            button:setBounds(0, (i - 1) * itemHeight, selectorW, itemHeight)
            button:setSkin(buttonSkin)
            button:addMouseUpCallback(function()
                log("Playlist dropdown selected: " .. tostring(selectedName))
                selectPlaylistByName(selectedName, false)
            end)
            playlistDropdownPanel:insertWidget(button)
            table.insert(playlistDropdownButtons, button)
        end

        local x, y = playlistDropdownButton:getPosition()
        local menuX = math.min(x, windowW - 8 - selectorW)
        playlistDropdownPanel:setBounds(
            menuX,
            y + 30,
            selectorW,
            math.max(1, #playlistNames * itemHeight)
        )

        if playlistDropdownButton then
            playlistDropdownButton:setText("≡")
        end
    end

    local function getObjectMethod(obj, name)
        local ok, value = pcall(function() return obj[name] end)
        if ok and type(value) == "function" then
            return value
        end
        return nil
    end

    local function logRelevantMethods(label, obj)
        local found = {}

        local function collect(tbl)
            if type(tbl) ~= "table" then return end
            for k, v in pairs(tbl) do
                if type(k) == "string" and type(v) == "function" then
                    local lower = string.lower(k)
                    if lower:find("mouse", 1, true)
                        or lower:find("alpha", 1, true)
                        or lower:find("opacity", 1, true)
                        or lower:find("skin", 1, true) then
                        found[k] = true
                    end
                end
            end
        end

        pcall(function() collect(obj) end)
        pcall(function()
            local mt = getmetatable(obj)
            collect(mt)
            if mt and type(mt.__index) == "table" then
                collect(mt.__index)
            end
        end)

        local names = {}
        for name in pairs(found) do
            table.insert(names, name)
        end
        table.sort(names)

        if #names > 0 then
            log("HOVER PROBE " .. label .. " methods: " .. table.concat(names, ", "))
        else
            log("HOVER PROBE " .. label .. " methods: none discovered via pairs/metatable")
        end
    end

    local function setPlayerOpacity(value)
        if not window then return end

        local ok, err = pcall(function()
            window:setOpacity(value)
        end)

        if ok then
            log(string.format("Opacity: %.2f", value))
        else
            log("Opacity change failed: " .. tostring(err))
        end
    end

    local function installHoverOpacity()
        if not window then return end

        local enterMethod = getObjectMethod(window, "addMouseEnterCallback")
        local leaveMethod = getObjectMethod(window, "addMouseLeaveCallback")

        if enterMethod then
            local ok, err = pcall(function()
                enterMethod(window, function()
                    setPlayerOpacity(config.hoverOpacity)
                end)
            end)
            if ok then
                log("Hover opacity ENTER callback installed")
            else
                log("Hover opacity ENTER callback failed: " .. tostring(err))
            end
        end

        if leaveMethod then
            local ok, err = pcall(function()
                leaveMethod(window, function()
                    setPlayerOpacity(config.inactiveOpacity)
                end)
            end)
            if ok then
                log("Hover opacity LEAVE callback installed")
            else
                log("Hover opacity LEAVE callback failed: " .. tostring(err))
            end
        end
    end

    local function createWindow()
        if window then return end

        window = DialogLoader.spawnDialogFromFile(dialogFile, cdata)
        defaultWindowSkin = window:getSkin()
        panel = window.Box

        installHoverOpacity()
        log(string.format(
            "Hover opacity config: inactive=%.2f | hover=%.2f",
            config.inactiveOpacity,
            config.hoverOpacity
        ))
        setPlayerOpacity(config.inactiveOpacity)

        btnPrev = panel.PrevButton
        btnPlay = panel.PlayButton
        btnStop = panel.StopButton
        btnNext = panel.NextButton
        btnShuffle = panel.ShuffleButton
        playlistDropdownButton = panel.PlaylistDropdownButton
        volumeSlider = panel.VolumeSlider
        volumeValueDisplay = panel.VolumeValue

        -- Compact layout. Keep older oversized saved windows from breaking, but shrink minimums.
        local savedW = tonumber(config.windowSize.w) or 312
        -- RC10 narrows the old 360px layout automatically.
        if savedW >= 360 then savedW = 312 end
        config.windowSize.w = math.max(312, savedW)
        local savedH = tonumber(config.windowSize.h) or 90
        if savedH >= 90 and savedH <= 120 then savedH = 90 end
        config.windowSize.h = math.max(90, savedH)

        window:setBounds(
            config.windowPosition.x,
            config.windowPosition.y,
            config.windowSize.w,
            config.windowSize.h
        )

        window:addPositionCallback(handleMove)
        window:addSizeCallback(handleResize)

        btnPrev:addMouseDownCallback(function() previous() end)
        btnPlay:addMouseDownCallback(function() playCurrent() end)
        btnStop:addMouseDownCallback(function() stop() end)
        btnNext:addMouseDownCallback(function() nextTrack("manual") end)
        btnShuffle:addMouseDownCallback(function() shuffle() end)
        playlistDropdownButton:addMouseUpCallback(function() openPlaylistDropdown() end)

        volumeSlider:addChangeCallback(function()
            setVolume(volumeSlider:getValue(), false)
        end)

        addHotkey(config.hotkeys.toggle, toggle)
        addHotkey(config.hotkeys.stop, stop)
        addHotkey(config.hotkeys.previous, previous)
        addHotkey(config.hotkeys.play, playCurrent)
        addHotkey(config.hotkeys.next, function() nextTrack("hotkey") end)
        addHotkey(config.hotkeys.shuffle, shuffle)
        addHotkey(config.hotkeys.reload, function()
            reloadPlaylists()
            setTitle(isPlaying and "PLAY" or "")
        end)
        addHotkey(config.hotkeys.playlistPrevious, function()
            cyclePlaylist(-1, false)
        end)
        addHotkey(config.hotkeys.playlistNext, function()
            cyclePlaylist(1, false)
        end)

        addHotkey(config.hotkeys.volumeDown, function()
            setVolume(config.volume - 10, true)
        end)

        addHotkey(config.hotkeys.volumeUp, function()
            setVolume(config.volume + 10, true)
        end)

        handleResize(window)
        setVolume(config.volume, true)
        window:setVisible(true)

        reloadPlaylists()
        if playlistDropdownButton then
            playlistDropdownButton:setText("≡")
        end

        if config.hideOnLaunch then
            hide()
        else
            show()
        end

        log("Window created")
    end

    local function checkAutoNext()
        if not config.autoNext then return end
        if not isPlaying then return end
        if autoNextHandled then return end
        if not currentStartedAt or not currentDuration then return end

        local t = now()

        if t - lastMarqueeTick >= 0.35 then
            lastMarqueeTick = t
            if #playlist > 0 then
                local trackName = tostring(playlist[currentIndex] and playlist[currentIndex].name or "")
                if #trackName > marqueeWidth then
                    marqueeOffset = marqueeOffset + 1
                    local loopLen = #(trackName .. marqueePad)
                    if marqueeOffset > loopLen then marqueeOffset = 1 end
                else
                    marqueeOffset = 1
                end
                setTitle(isPlaying and "PLAY" or "")
            end
        end

        -- Limit work to about five checks per second.
        if t - lastFrameCheck < 0.20 then return end
        lastFrameCheck = t

        local elapsed = t - currentStartedAt
        local triggerAt = currentDuration + config.autoNextGraceSeconds

        if elapsed >= triggerAt then
            autoNextHandled = true
            log(string.format(
                "Auto-Next trigger: elapsed=%.2f duration=%.2f grace=%.2f",
                elapsed,
                currentDuration,
                config.autoNextGraceSeconds
            ))
            nextTrack("auto-next")
        end
    end

    loadConfig()
    math.randomseed(os.time())

    local handler = {}
    local initialized = false

    function handler.onSimulationFrame()
        if not initialized then
            local ok, err = pcall(createWindow)
            if not ok then
                log("FATAL creating window: " .. tostring(err))
            else
                initialized = true
            end
        end

        if initialized then
            local ok, err = pcall(checkAutoNext)
            if not ok then
                log("ERROR Auto-Next check: " .. tostring(err))
            end
        end
    end

    function handler.onSimulationStop()
        if window and not isHidden then
            setTitle(isPlaying and "PLAY" or "")
        end
    end

    DCS.setUserCallbacks(handler)

    log(string.format(
        "%s v%s hook loaded | timer=%s",
        APP,
        VERSION,
        socketOk and "socket.gettime" or "os.time"
    ))
end

local ok, err = pcall(loadDCSMusicPlayer)
if not ok and net and net.log then
    net.log("[DCS-Music-Player] FATAL load error: " .. tostring(err))
end
