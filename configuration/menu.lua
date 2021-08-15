local gui = require("lib.graphics.gui")
local graphics = require("lib.graphics.graphics")
local renderer = require("lib.graphics.renderer")
local serialization = require("serialization")
local colors = require("lib.graphics.colors")

graphics.setContext()
local maxWidth = 160
local maxheight = 50
local selectionBoxWidth = 20
local location = {x = 2, y = 1}
local configurationData = {}


local modules = {
    {name = "HUD",              module = "hud", desc = "Overlays a HUD on your screen."},
    {name = "Primary Server",   module = "server", desc = "Updates all data and handles communication between other servers."},
    {name = "Power Control",    module = "modules.tools.powerControl", desc = "Emits redstone when power levels are below a certain amount."}
}
local processes = {}

local activatorVar = nil
local selector = nil
local deselector = nil

local function save()
    configurationData.modules = {}
    configurationData.processes = {}
    for i = 1, #modules do
        table.insert(configurationData.modules, {name = modules[i].name, module = modules[i].module, desc = modules[i].desc})
    end
    for i = 1, #processes do
        table.insert(configurationData.processes, {name = processes[i].name, module = processes[i].module, desc = processes[i].desc})
    end
    local file = io.open("/home/NIDAS/settings/enabledModules", "w")
    file:write(serialization.serialize(configurationData))
    file:close()
end

local deactivateVar = nil
local function activate(module, displayName, desc, skipRendering)
    displayName = displayName or module
    if module == "server" or module == "local" then --Server or primary process is always #1
        table.insert(processes, 1, {func = require(module), returnValue = nil, name = displayName, module = module, desc = desc})
    else
        table.insert(processes, {func = require(module), returnValue = nil, name = displayName, module = module, desc = desc})
    end
    local found = 0
    for i = 1, #modules do
        if modules[i].module == module then
            found= i
        end
    end
    if found ~= 0 then table.remove(modules, found) end
    selector = activatorVar(location.x, location.y, selectionBoxWidth, maxheight-5, "Activate", activate, modules, "Available", selector)
    deselector = activatorVar(location.x+selectionBoxWidth+1, location.y, selectionBoxWidth, maxheight-5, "Disable", deactivateVar, processes, "Active", deselector)
    if not skipRendering then renderer.update() end
end

local function deactivate(module)
    local found = 0
    for i = 1, #processes do
        if processes[i].module == module then
            table.insert(modules, {name = processes[i].name, module = processes[i].module, desc = processes[i].desc})
            found = i
        end
    end
    if found ~= 0 then
        table.remove(processes, found)
    end
    selector = activatorVar(location.x, location.y, selectionBoxWidth, maxheight-5, "Activate", activate, modules, "Available", selector)
    deselector = activatorVar(location.x+selectionBoxWidth+1, location.y, selectionBoxWidth, maxheight-5, "Disable", deactivate, processes, "Active", deselector)
    renderer.update()
end
deactivateVar = deactivate

local function load()
    local file = io.open("/home/NIDAS/settings/enabledModules", "r")
    if file ~= nil then
        configurationData = serialization.unserialize(file:read("*a"))
        if configurationData ~= nil then
            for i = 1, #configurationData.processes do
                activate(configurationData.processes[i].module, configurationData.processes[i].name, configurationData.processes[i].desc, true)
            end
            local primaryScreen = configurationData.primaryScreen or require("component").screen.address
            require("component").gpu.bind(primaryScreen, false)
            renderer.setPrimaryScreen(primaryScreen)
            renderer.setDebug(configurationData.debug or false)
            renderer.setMulticasting(configurationData.multicasting or true)
        else
            configurationData = {multicasting = true}
        end
        file:close()
    end
end

local currentTab = nil
local function flush()
    if currentTab ~= nil then
        renderer.removeObject(currentTab)
    end
    currentTab = nil
end

local function infoScreen(x, y, width, height, text, title)
    flush()
    currentTab = gui.wrappedTextBox(x, y, width, height, text, title)
    renderer.update()
end

local function configScreen(x, y, width, height, title, data)
    flush()
    currentTab = gui.configMenu(x, y, width, height, title, data)
    graphics.context().gpu.setActiveBuffer(currentTab)
    local configurationTab = data.configure(x, y, gui, graphics, renderer, currentTab)
    currentTab = {currentTab}
    if configurationTab ~= nil then for i = 1, #configurationTab do table.insert(currentTab, configurationTab[i]) end end
end

local function activator(x, y, width, height, functionName, mainFunction, dataSource, listName, storageVariable)
    if storageVariable ~= nil then renderer.removeObject(storageVariable) end
    local buttons = {}
    for i = 1, #dataSource do
        local onActivation =
        {
            {displayName = functionName,
            value = mainFunction,
            args = {dataSource[i].module, dataSource[i].name, dataSource[i].desc}},
            {displayName = "Info",
            value = infoScreen,
            args = {location.x+2*selectionBoxWidth+2, location.y, maxWidth-(location.x+2*selectionBoxWidth+2), maxheight-5, dataSource[i].desc, dataSource[i].name}},
            {displayName = "Configure",
            value = configScreen,
            args = {location.x+2*selectionBoxWidth+2, location.y, maxWidth-(location.x+2*selectionBoxWidth+2), maxheight-5, dataSource[i].name, require(dataSource[i].module)}}
        }
        table.insert(buttons, {name = dataSource[i].name, func = gui.selectionBox, args = {x+width/2, y+i, onActivation}})
    end
    return gui.multiButtonList(x, y, buttons, width, height, listName.." ".."("..math.floor(#buttons)..")")
end
activatorVar = activator

local menuVariable = nil

local menu = {}
local function saveSettings()
    local component = require("component")
    save()
    gui.setColors(configurationData.primaryColor, configurationData.accentColor, configurationData.borderColor)
    renderer.clear()
    component.gpu.setResolution(configurationData.xRes or 125, configurationData.yRes or 35)
    graphics.setContext({gpu = require("component").gpu, width = configurationData.xRes or 125, height = configurationData.yRes or 35})
    maxWidth = graphics.context().width
    maxheight = graphics.context().height
    local primaryScreen = configurationData.primaryScreen or require("component").screen.address
    component.gpu.bind(primaryScreen, false)
    renderer.setPrimaryScreen(primaryScreen)
    renderer.setDebug(configurationData.debug or false)
    renderer.setMulticasting(configurationData.multicasting or true)
    menuVariable()
    graphics.context().gpu.fill(1, 1, 160, 50, " ")
    configScreen(location.x+2*selectionBoxWidth+2, location.y, maxWidth-(location.x+2*selectionBoxWidth+2), maxheight-5, "NIDAS Settings", menu)
    renderer.update()
end

function menu.configure(x, y, _, _, _, page)
    local _, ySize = graphics.context().gpu.getBufferSize(page)
    graphics.context().gpu.setActiveBuffer(page)
    local currentConfigWindow = {}
    local attributeChangeList = {
        {name = "Primary Screen",   attribute = "primaryScreen",    type = "component", defaultValue = require("component").screen.address, componentType = "screen"},
        {name = "Resolution (X)",   attribute = "xRes",             type = "number",    defaultValue = 125, minValue = 80},
        {name = "Resolution (Y)",   attribute = "yRes",             type = "number",    defaultValue = 35, minValue = 20},
        {name = "Primary Color",    attribute = "primaryColor",     type = "color",     defaultValue = colors.electricBlue},
        {name = "Accent Color",     attribute = "accentColor",      type = "color",     defaultValue = colors.magenta},
        {name = "Border Color",     attribute = "borderColor",      type = "color",     defaultValue = colors.darkGray},
        {name = "",                 attribute = nil,                type = "header",    defaultValue = nil},
        {name = "Multicasting",     attribute = "multicasting",     type = "boolean",   defaultValue = true},
        {name = "Developer Mode",   attribute = "debug",            type = "boolean",   defaultValue = false},

    }
    gui.multiAttributeList(x+3, y+3, page, currentConfigWindow, attributeChangeList, configurationData)
    table.insert(currentConfigWindow, gui.bigButton(x+2, y+tonumber(ySize)-4, "Save Configuration", saveSettings))
    renderer.update()
    return currentConfigWindow
end

local running = false
local serverData = nil
local interrupted = false
local function switch()
    running = not running
end

local function interrupt()
    graphics.rectangle(1, 1, maxWidth, 2*(maxheight-5), 0x000000)
    interrupted = true
end

local function update()
    require("shell").execute("cd /home")
    require("shell").execute("setup dev")
end

local function updateAvailable()
    local version = require("nidas_version")
    require("shell").execute("wget https://raw.githubusercontent.com/S4mpsa/NIDAS/develop/nidas_version.lua /home/NIDAS/available_version.lua -f -q")
    local availableVersion = require("available_version")
    if tonumber(version) < tonumber(availableVersion) then
        return true
    end
    return false
end

local function reboot()
    graphics.context().gpu.fill(1, 1, 160, 50, " ")
    renderer.multicast()
    require("computer").shutdown(true)
end

local function generateMenu()
    selector = activator(location.x, location.y, selectionBoxWidth, maxheight-5, "Activate", activate, modules, "Available", selector)
    deselector = activator(location.x+selectionBoxWidth+1, location.y, selectionBoxWidth, maxheight-5, "Disable", deactivate, processes, "Active", deselector)
    gui.bigButton(location.x, location.y+maxheight-5, "Run", switch)
    gui.bigButton(location.x+5, location.y+maxheight-5, "Save", save)
    gui.bigButton(location.x+11, location.y+maxheight-5, "Reboot", reboot)
    gui.bigButton(location.x+19, location.y+maxheight-5, "Shell", interrupt)
    gui.bigButton(location.x+26, location.y+maxheight-5, "Settings", configScreen, {location.x+2*selectionBoxWidth+2, location.y, maxWidth-(location.x+2*selectionBoxWidth+2), maxheight-5, "NIDAS Settings", menu})
    if updateAvailable() then gui.smallButton(maxWidth-21, maxheight, "Update available!", update) end
    gui.smallLogo(maxWidth-20, maxheight-4, require("nidas_version"))
end
menuVariable = generateMenu
local function main()
    if #processes > 0 and running then
        serverData = processes[1].func.update()
        for i = 2, #processes do
            local p = processes[i]
            processes[i].returnValue = p.func.update(serverData, table.unpack(p.args or {}))
        end
    end
    os.sleep()
end

local function update()
    load()
    gui.setColors(configurationData.primaryColor, configurationData.accentColor, configurationData.borderColor)
    require("component").gpu.setResolution(configurationData.xRes or 125, configurationData.yRes or 35)
    graphics.setContext({gpu = require("component").gpu, width = configurationData.xRes or 125, height = configurationData.yRes or 35})
    maxWidth = graphics.context().width
    maxheight = graphics.context().height
    generateMenu()
    graphics.context().gpu.fill(1, 1, 160, 50, " ")
    renderer.update()
    renderer.multicast()
    while not interrupted do
        main()
    end
end

return update