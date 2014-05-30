--[[ TODO List - Server ]]

----------------------------------------------------------------[ Constants ]--
local ARGV = {...}
local CHAN_INDEX = 3
local RESP_INDEX = 4
local MSG_INDEX  = 5
local DIST_INDEX = 6

local COMMAND_CHANNEL = 1010
local PERSISTANCE_FILE_NAME = "todo_list.json"

------------------------------------------------------------------[ OBJECTS ]--

-- Ugly display wrapper
Display = {
  -- Holds on to our out terminal
  term = nil,

  -- Holds cursor info
  cursor = {
    x = 1,
    y = 1
  },

  -- Helper for printing a line to the display
  print = function(self, str)
    self.term.setCursorPos(self.cursor.x,
                           self.cursor.y)
    self.term.write(str)
    self.cursor.y = self.cursor.y + 1
  end,

  -- Helper for clearing the display
  reset = function(self)
    self.cursor.x = 1
    self.cursor.y = 1
    self.term.clear()
  end,

  new = function(self, o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
  end
}

-- Object containing a single todo element
TodoElement = {
  -- Holds the todo elements string
  contents = nil,

  new = function(self, o)
    o = o or {} -- Allow setting intial
    setmetatable(o, self)
    self.__index = self
    return o
  end
}

-- Object for modeling a todo list with some helpers
TodoList = {
  -- Actual list comprised of TodoElements
  list = {},
  -- Current length of the list
  length = 0,
  
  -- File to use for persistance
  saveFile = nil,

  -- Function to add a new todo element from a string
  add = function(self, str)
    self.length = self.length + 1
    local new = TodoElement:new({contents = str})
    table.insert(self.list, self.length, new)
    self:saveToDisk()
  end,

  -- Function to remove a todo element based on index
  remove = function(self, index)
    local res = table.remove(self.list, index)
    self:saveToDisk()
    return res ~= nil
  end,

  -- Helper function to reprint the current todo list
  update = function(self, disp)
    disp:reset()
    disp:print("------ TODO ------")
    local i = 1
    for k,v in pairs(self.list) do
      disp:print(i..":"..v.contents)
      i = i + 1
    end
  end,
  
  -- Function used to save the current state to disk
  saveToDisk = function(self)
    local outFile = fs.open(PERSISTANCE_FILE_NAME, "w")
    
    -- Write out every entry
    outFile.write(textutils.serialize(self.list))
    
    outFile.close()
  end,
  
  -- Function used to load old state from disk
  loadFromDisk = function(self)
    print("Reading from persistance file")
    local inFile = fs.open(PERSISTANCE_FILE_NAME, "r")
    
    local lines = inFile.readAll()
    self.list = textutils.unserialize(lines)
    self.length = table.getn(self.list)
    
    inFile.close()
  end,

  new = function(self, o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
  end
}

-- Object to define a command with helpers
Command = {
  -- Command code, (add, get, etc)
  cmd = nil,

  -- Arguments associated with command
  args = nil,

  -- Channel command was received on
  channel = nil,

  -- Response channel for said command
  responseChannel = nil,

  -- Contains instance of modem to send
  modem = nil,

  -- Helper function to send a response along the commands response channel
  sendResp = function(self, resp)
    self.modem.transmit(self.responseChannel,
                        COMMAND_CHANNEL,
                        textutils.serialize(resp))
  end,

  new = function(self, o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
  end
}

-------------------------------------------------------[ Instance Variables ]--

-- Get our display
local disp = Display:new({
  term = peripheral.wrap("left")
})

-- Instance of TodoList
local todos = TodoList:new()
-- Start off printing out our list
todos:update(disp)
todos:loadFromDisk()

-- Field to keep track of stop commands
local keepListening = true

-----------------------------------------------------------[ Hardware Setup ]--

-- Get the modem
local modem = peripheral.wrap("top")

--------------------------------------------------------[ Primary Functions ]--

-- Main loop. Waits for a commmand to come in, then process it.
function run()
  -- Start clean
  disp:reset()

  -- Get our command channel
  if COMMAND_CHANNEL == nil and table.getn(ARGV) == 0 then
    print("Must run as:")
    print("  todo <command_channel_id>")
  else
    -- Get the supplied command channel
    if COMMAND_CHANNEL == nil then
      COMMAND_CHANNEL = tonumber(ARGV[1])
    end

    -- Start listening
    modem.open(COMMAND_CHANNEL)
    todos:update(disp)

    -- Keep looping until stop is seen
    while keepListening do
      local cmd = waitForCommand(modem)
      handleCommand(cmd)
    end

    -- Make sure to clear the screen again
    disp:reset()
  end
end

-- Handles a command object once received. Determines which logic to hit
function handleCommand(command)
  -- Send command to correct function
  if command.cmd == "stop"then
    cmd_stop(command)
  elseif command.cmd == "add" then
    cmd_add(command)
  elseif command.cmd == "get" then
    cmd_get(command)
  elseif command.cmd == "remove" then
    cmd_remove(command)
  else
    -- unknown command
    command:sendResp("Unknown command: "..command.cmd)
  end
end

-- Handles the stop command functionality
function cmd_stop(command)
  if command.args == nil or table.getn(command.args) == 0 or command.args[1] ~= "yes" then
    command:sendResp("Are you sure?")
  else
    keepListening = false
    command:sendResp("Stopped!")
  end
end

-- Handles the add command functionality
function cmd_add(command)
  -- Need to have something to add
  if command.args == nil or table.getn(command.args) == 0 then
    command:sendResp("Bad args")
  else
    -- Looks good!
    todos:add(command.args[1])
    -- Update the display
    todos:update(disp)
    command:sendResp("Added entry!")
  end
end

-- Handles the remove command functionality
function cmd_remove(command)
  -- Need to have something to remove
  if command.args == nil or table.getn(command.args) == 0 then
    command:sendResp("Bad args")
  else
    -- Looks good!
    local res = todos:remove(command.args[1])
    if res then
      -- Update the display
      todos:update(disp)
      command:sendResp("Entry removed.")
    else
      command:sendResp("Entry not found.")
    end
  end
end

-- Handles the get command functionality
function cmd_get(command)
  -- Just send back our current list
  command:sendResp(todos.list)
end

---------------------------------------------------------[ Helper Functions ]--

-- Gets a single message from the modem
function getMessage(m)
  print("Waiting for message...")
  return {os.pullEvent("modem_message")}
end

-- Returns the content field of a modem message
function contentStr(msg)
  return msg[MSG_INDEX]
end

-- Helper to get content field as object
function contents(msg)
  return textutils.unserialize(contentStr(msg))
end

-- Returns the response channel field of a modem message
function respChannel(msg)
  return msg[RESP_INDEX]
end

-- Returns the channel field of a modem message
function channel(msg)
  return msg[CHAN_INDEX]
end

-- Helper function to wait until a command comes in. Builds a command object
function waitForCommand(modem)
  -- Wait for a message
  local msg = getMessage(modem)

  -- Get our parts
  local m = contents(msg)
  local c = channel(msg)
  local r = respChannel(msg)
  
  -- Build the command
  local command = Command:new({
    cmd = m.cmd,
    args = m.args,
    channel = c,
    responseChannel = r,
    modem = modem
  })
  
  print("Got command: "..textutils.serialize(m))
  
  return command
end

-- Start running
run()