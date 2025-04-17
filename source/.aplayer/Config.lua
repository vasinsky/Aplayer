local Config = {}

--SET YOUR music collection path
Config.BASE_DIR = "/mnt/sdcard/ROMS/music"

--!!! Do not CHANGE
Config.MOUNT_DIR = "/mnt/mmc/MUOS/application/.aplayer/music-app"
Config.MUSIC_APP = "music-app"

--Change if you need :)
Config.USE_SUPPORT_JAPANESE = false
Config.USE_VISUALIZATION = true
Config.BG_IMG = "assets/bg.jpg"
Config.BG_OPACITY = 0.3
Config.COLORS = {
                    background = {0.04, 0.10, 0.18}, text = {1.00, 1.00, 1.00}, shadow = {0.00, 0.00, 0.00, 0.5},
                    highlight = {0.17, 0.27, 0.37}, directory = {0.94, 1.00, 0.90}, currentTrack = {1.00, 1.00, 1.00},
                    currentTrackBg = {0.37, 0.27, 0.37}, scrollBar = {1,1,1},
                    progressBar = {0.94, 1.00, 0.90}, border = {1.00, 1.00, 1.00}, equalizer = {0.94, 1.00, 0.90}
                }

Config.SPEEDS = {1, 1.5, 1.8, 2.0, 0.5}

-- allow R1 when buttons are locked
Config.allowR1 = true

return Config