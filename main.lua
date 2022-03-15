--[[
    vurl interpreter
    viba, march 2022
    i really dont care what you do with this code
]]--

local lg = love.graphics
local mem = {}
local lines
local lp
local branches
local returnStack
local runCode
local screen
local co
local t
local isRunning = false

local commands = {
    set = function(a)
        mem[a[1]] = a[2]
    end,
    
    list = function(a)
        return a
    end,
    insert = function(a)
        table.insert(a[1], a[2], a[3])
    end,
    push = function(a)
        table.insert(a[1], a[2])
    end,
    remove = function(a)
        return table.remove(a[1], a[2]) or ""
    end,
    pop = function(a)
        return table.remove(a[1]) or ""
    end,
    index = function(a)
        return a[1][tonumber(a[2])] or ""
    end,
    replace = function(a)
        a[1][tonumber(a[2])] = a[3]
    end,
    
    add = function(a)
        return tostring(tonumber(a[1]) + tonumber(a[2]))
    end,
    sub = function(a)
        return tostring(tonumber(a[1]) - tonumber(a[2]))
    end,
    mul = function(a)
        return tostring(tonumber(a[1]) * tonumber(a[2]))
    end,
    div = function(a)
        return tostring(tonumber(a[1]) / tonumber(a[2]))
    end,
    mod = function(a)
        return tostring(tonumber(a[1]) % tonumber(a[2]))
    end,
    join = function(a)
        return a[1] .. a[2]
    end,
    len = function(a)
        return #a[1]
    end,
    substr = function(a)
        return string.sub(a[1], a[2], a[3])
    end,
    
    eq = function(a)
        return (a[1] == a[2]) and '1' or '0'
    end,
    
    gt = function(a)
        return (tonumber(a[1]) > tonumber(a[2])) and '1' or '0'
    end,
    
    lt = function(a)
        return (tonumber(a[1]) < tonumber(a[2])) and '1' or '0'
    end,
    
    gte = function(a)
        return (tonumber(a[1]) >= tonumber(a[2])) and '1' or '0'
    end,
    
    lte = function(a)
        return (tonumber(a[1]) <= tonumber(a[2])) and '1' or '0'
    end,
    
    ["and"] = function(a)
        return (a[1]=='1' and a[2]=='1') and '1' or '0'
    end,
    
    ["or"] = function(a)
        return (a[1]=='1' or a[2]=='1') and '1' or '0'
    end,
    
    ["not"] = function(a)
        return (a[1]=='0') and '1' or '0'
    end,
    
    ["if"] = function(a)
        if a[1]=='0' then
            lp = branches[lp]
        end
    end,
    
    ["while"] = function(a)
        if a[1]=='0' then
            lp = branches[lp]
        end
    end,
    
    frame = function(a)
        if a[1] and a[1]=='0' then
            lp = branches[lp]
        end
    end,
    
    define = function(a)
        mem[a[1]] = lp
        lp = branches[lp]
    end,
    
    call = function(a)
        table.insert(returnStack, lp)
        lp = mem[a[1]]
    end,
    
    ["end"] = function(a)
        if branches[lp].type == "while" then
            lp = branches[lp].value - 1
        elseif branches[lp].type == "frame" then
            coroutine.yield()
            lp = branches[lp].value - 1
        elseif branches[lp].type == "define" then
            lp = table.remove(returnStack)
        end
    end,
    
    print = function(a)
        print(a[1])
    end,
    input = function(a)
        return io.read()
    end,
    
    random = function(a)
        return tostring(love.math.random(tonumber(a[1]), tonumber(a[2])))
    end,
    
    clear = function(a)
        lg.clear()
    end,
    
    line = function(a)
        lg.line(tonumber(a[1]), tonumber(a[2]), tonumber(a[3]), tonumber(a[4]))
    end,
    
    rect = function(a)
        lg.rectangle("fill", a[1], a[2], a[3], a[4])
    end,
    
    circle = function(a)
        lg.circle("fill", a[1], a[2], a[3])
    end,
    
    ellipse = function(a)
        lg.ellipse("fill", a[1], a[2], a[3], a[4])
    end,
    
    text = function(a)
        lg.print(a[1], a[2], a[3])
    end,
    
    draw = function(a)
        lg.draw(a[1], a[2], a[3])
    end,
    
    origin = function(a)
        lg.origin()
    end,
    
    translate = function(a)
        lg.translate(tonumber(a[1]), tonumber(a[2]))
    end,
    
    rotate = function(a)
        lg.rotate(tonumber(a[1]))
    end,
    
    scale = function(a)
        lg.scale(tonumber(a[1]), tonumber(a[2]))
    end,
    
    image = function(a)
        return lg.newImage("mnt/" .. a[1])
    end,
    
    sound = function(a)
        return love.audio.newSource("mnt/" .. a[1], "static")
    end,
    
    music = function(a)
        return love.audio.newSource("mnt/" .. a[1], "stream")
    end,
    
    play = function(a)
        love.audio.play(a[1])
    end,
    
    stop = function(a)
        if a[1] then
            a[1]:stop()
        else
            love.audio.stop()
        end
    end,
    
    color = function(a)
        lg.setColor(tonumber(a[1])/255, tonumber(a[2])/255, tonumber(a[3])/255)
    end,
    
    mousex = function(a)
        return love.mouse.getX()
    end,
    
    mousey = function(a)
        return love.mouse.getY()
    end,
    
    mousedown = function(a)
        return love.mouse.isDown(tonumber(a[1] or "1")) and "1" or "0"
    end,
    
    keydown = function(a)
        return love.keyboard.isDown(a[1]) and "1" or "0"
    end,
    
    timer = function(a)
        return tostring(t)
    end,
}

local function parseLine(line)
    local l = {}
    
    local command, argstring = string.match(line, "^%s*(%S+)%s?(.*)$")
    
    local isInQuotes = false
    local parensLevel = 0
    local args = {}
    local a = ""
    local c = 1
    while c <= #argstring do
        local char = string.sub(argstring, c, c)
        
        if char == '"' then
            isInQuotes = not isInQuotes
            a = a .. char
        elseif char == "(" then
            parensLevel = parensLevel + 1
            a = a .. char
        elseif char == ")" then
            parensLevel = parensLevel - 1
            a = a .. char
        elseif (not isInQuotes) and (parensLevel <= 0) and string.match(char, "%s") then
            table.insert(args, a)
            a = ""
        else
            a = a .. char
        end
        
        c = c + 1
    end
    if #a > 0 then
        table.insert(args, a)
    end
    
    local parsedArgs = {}
    for i, arg in ipairs(args) do
        if string.match(arg, "^%[.+%]$") then
            parsedArgs[i] = {type="var", value=string.sub(arg, 2, -2)}
        elseif string.match(arg, "^%(.+%)$") then
            parsedArgs[i] = {type="cmd", value=parseLine(string.sub(arg, 2, -2))}
        elseif string.match(arg, "^\"(.*)\"$") then
            parsedArgs[i] = {type="lit", value=string.sub(arg, 2, -2)}
        else
            parsedArgs[i] = {type="lit", value=arg}
        end
    end
    
    l.command = command
    l.args = parsedArgs

    return l
end

local function message(s)
    screen:renderTo(function()
        lg.clear()
        lg.print(s, 0, 0)
    end)
end

function run(code)
    lines = {}
    branches = {}
    returnStack = {}
    local branchStack = {}
    
    local lineNumber = 1
    for line in string.gmatch(code, "[^\n]+") do
        if (not string.match(line, "^%s*#%s")) and (not string.match(line, "^%s+$")) then
            local pl = parseLine(line)
            table.insert(lines, pl)

            if pl.command == "if"
            or pl.command == "while"
            or pl.command == "frame"
            or pl.command == "define" then
                table.insert(branchStack, {type=pl.command, value=lineNumber})
            elseif pl.command == "end" then
                local b = table.remove(branchStack)
                branches[lineNumber] = b
                branches[b.value] = lineNumber
            end
            
            lineNumber = lineNumber + 1
        end
    end
    
    local function err(msg)
        message(msg)
        isRunning = false
        coroutine.yield()
    end
    
    local function runLine(line)
        local args = {}
        for i, a in ipairs(line.args) do
            if a.type == "var" then
                args[i] = mem[a.value]
            elseif a.type == "cmd" then
                args[i] = runLine(a.value)
            elseif a.type == "lit" then
                args[i] = a.value
            end
        end
        if not commands[line.command] then err("unknown command: " .. line.command) end
        local ok, ret = pcall(commands[line.command], args)
        if not ok then
            err(ret)
            return
        end
        return ret
    end
    
    lp = 1
    
    while lp <= #lines do
        local line = lines[lp]
        
        runLine(line)
        
        lp = lp + 1
    end
end

local function start(code)
    co = coroutine.create(run)
    lg.setCanvas(screen)
    lg.clear()
    coroutine.resume(co, code)
    lg.setCanvas()
    isRunning = true
end

function love.load(arg)
    t = 0
    screen = lg.newCanvas()
    lg.setNewFont(18)
    
    if not arg[1] then message("no input file\n\ndrag and drop a directory or file,\nor run this program again with a filepath as an argument.") else
        local f = io.open(arg[1], "r")
        local code = f:read("a")
        f:close()
        start(code)
    end
end

function love.filedropped(file)
    file:open("r")
    local code = file:read()
    file:close()
    start(code)
end

function love.directorydropped(dir)
    love.filesystem.mount(dir, "mnt")
    local code = love.filesystem.read("mnt/main.vurl")
    start(code)
end

function love.update(dt)
    if not isRunning then return end
    t = t + dt
    lg.setCanvas(screen)
    coroutine.resume(co)
    lg.setCanvas()
end

function love.draw()
    lg.push()
    lg.setCanvas()
    lg.setColor(1, 1, 1, 1)
    lg.draw(screen)
    lg.pop()
end
