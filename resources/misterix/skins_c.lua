--========================================================
-- MTA:SA Skin Replacement Script
-- Put this file as: client.lua
--========================================================

local skins = {
    { txd = "alien.txd",         dff = "alien.dff",         id = 241 },
    { txd = "dino.txd",          dff = "dino.dff",          id = 310 },
    { txd = "godzilla.txd",      dff = "godzilla.dff",      id = 295 },
    { txd = "leatherface.txd",   dff = "leatherface.dff",   id = 101 },
    { txd = "woodscreature.txd", dff = "woodscreature.dff", id = 49  },
    { txd = "ghost.txd", dff = "ghost.dff", id = 204  },
    { txd = "mothman.txd", dff = "mothman.dff", id = 205  },
    { txd = "piggsy.txd", dff = "piggsy.dff", id = 258  }
}

function loadSkinReplacements()
    for _, skin in ipairs(skins) do

        -- Load TXD
        local txd = engineLoadTXD(skin.txd)
        if txd then
            engineImportTXD(txd, skin.id)
        else
            outputDebugString("Failed to load TXD: " .. skin.txd, 1)
        end

        -- Load DFF
        local dff = engineLoadDFF(skin.dff)
        if dff then
            engineReplaceModel(dff, skin.id)
        else
            outputDebugString("Failed to load DFF: " .. skin.dff, 1)
        end
    end

    outputDebugString("Custom skin replacements loaded successfully!")
end

addEventHandler("onClientResourceStart", resourceRoot, loadSkinReplacements)