
-- Import section
local ar = require("lib.graphics.ar")
package.loaded.powerdisplay = nil
local powerDisplay = require("hud.powerdisplay")
local toolbar = require("hud.toolbar")
local component = require("component")
local serialization = require("serialization")
local colors = require "lib.graphics.colors"
--

local glassData = {}
local powerDisplayUsers = {}
local toolbarUsers = {}
local function load()
    local file = io.open("/home/NIDAS/configuration/hudConfig", "r")
    if file ~= nil then
        glassData = serialization.unserialize(file:read("*a"))
        file:close()
    end
    if glassData == nil then glassData = {} end
    for address, data in pairs(glassData) do
        ar.clear(component.proxy(address))
        if data.energyDisplay then table.insert(powerDisplayUsers, {component.proxy(address), {data.xRes, data.yRes}, data.scale, data.borderColor, data.primaryColor, data.accentColor}) end
        if data.toolbar then table.insert(toolbarUsers, {component.proxy(address), {data.xRes, data.yRes}, data.scale, data.offset, data.borderColor, data.primaryColor, data.accentColor}) end
    end
end
local function save()
    local file = io.open("/home/NIDAS/configuration/hudConfig", "w")
    file:write(serialization.serialize(glassData))
    file:close()
    powerDisplayUsers = {}
    toolbarUsers = {}
    for address, data in pairs(glassData) do
        if data.energyDisplay then table.insert(powerDisplayUsers, {component.proxy(address), {data.xRes, data.yRes}, data.scale, data.borderColor, data.primaryColor, data.accentColor}) end
        if data.toolbar then table.insert(toolbarUsers, {component.proxy(address), {data.xRes, data.yRes}, data.scale, data.offset, data.borderColor, data.primaryColor, data.accentColor}) end
    end
    package.loaded.powerdisplay = nil
    powerDisplay = require("hud.powerdisplay")
end

local hud = {}

local selectedGlasses = "None"
local refresh = nil

local currentConfigWindow = {}
local function changeGlasses(glassAddress, data)
    selectedGlasses = glassAddress
    local x, y, gui, graphics, renderer, page = table.unpack(data)
    renderer.removeObject(currentConfigWindow)
    refresh(x, y, gui, graphics, renderer, page)
end

function hud.configure(x, y, gui, graphics, renderer, page)
    local renderingData = {x, y, gui, graphics, renderer, page}
    graphics.context().gpu.setActiveBuffer(page)
    graphics.text(3, 5, "Selected Glasses:")
    local onActivation = {}
    for address, componentType in component.list() do
        if componentType == "glasses" then
            if glassData[address] == nil then
                glassData[address] = {}
            end
            local displayName = glassData[address].owner or address
            table.insert(onActivation, {displayName = displayName, value = changeGlasses, args = {address, renderingData}})
        end
    end
    local _, ySize = graphics.context().gpu.getBufferSize(page)
    table.insert(currentConfigWindow, gui.smallButton(x+19, y+2, selectedGlasses, gui.selectionBox, {x+24, y+2, onActivation}))
    table.insert(currentConfigWindow, gui.bigButton(x+2, y+tonumber(ySize)-4, "Save Configuration", save))

    if selectedGlasses ~= "None" then
        local attributeChangeList = {
            {name = "Glass Owner",      attribute = "owner",            type = "string",    defaultValue = nil},
            {name = "Resolution (X)",   attribute = "xRes",             type = "number",    defaultValue = 2560},
            {name = "Resolution (Y)",   attribute = "yRes",             type = "number",    defaultValue = 1440},
            {name = "Scale",            attribute = "scale",            type = "number",    defaultValue = 3},
            {name = "UTC Offset",       attribute = "offset",           type = "number",    defaultValue = 0},
            {name = "Primary Color",    attribute = "primaryColor",     type = "color",     defaultValue = colors.electricBlue},
            {name = "Accent Color",     attribute = "accentColor",      type = "color",     defaultValue = colors.magenta},
            {name = "Background Color", attribute = "backgroundColor",  type = "color",     defaultValue = colors.darkGray},
            {name = "",                 attribute = nil,                type = "header",    defaultValue = nil},
            {name = "Active Modules",   attribute = nil,                type = "header",    defaultValue = nil},
            {name = "  Energy Display", attribute = "energyDisplay",    type = "boolean",   defaultValue = true},
            {name = "  Toolbar Overlay",attribute = "toolbar",          type = "boolean",   defaultValue = true},
        }
        gui.multiAttributeList(x+3, y+3, page, currentConfigWindow, attributeChangeList, glassData, selectedGlasses)
    end

    renderer.update()
    return currentConfigWindow
end
refresh = hud.configure
function hud.update(serverInfo)
    powerDisplay.widget(powerDisplayUsers, serverInfo.power)
    toolbar.widget(toolbarUsers)
end
load()
return hud
