--[[ TODO List - Client ]]

----------------------------------------------------------------[ Constants ]--
local ARGV = {...}
local COMMAND_CHANNEL = 1010
local RESPONSE_CHANNEL = 1011

local CHAN_INDEX = 3
local RESP_INDEX = 4
local MSG_INDEX  = 5
local DIST_INDEX = 6

------------------------------------------------------------------[ OBJECTS ]--

-- Object to define a command with helpers
Command = {
  -- Command code, (add, get, etc)
  cmd = nil,

  -- Arguments associated with command
  args = nil,

  new = function(self, o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
  end
}

-----------------------------------------------------------[ Hardware Setup ]--

-- Get the modem
local modem = peripheral.wrap("back")

--------------------------------------------------------[ Primary Functions ]--

-- Main function to run
function run()
  -- Get the command
  local command = ARGV[1]

  -- Check if there was one
  if command == nil then
    printHelp()
  else
    -- Open up modem
    modem.open(RESPONSE_CHANNEL)

    -- Handle it
    table.remove(ARGV, 1)

    local cmd = Command:new({
      cmd = command,
      args = ARGV
    })

    handleCommand(cmd)
  end
end

-- Handles commands based on cmd. Runs correct function for given cmd
function handleCommand(cmd)
  -- Check which cmd
  if cmd.cmd == "get" then
    cmd_get(cmd)
  elseif cmd.cmd == "list" then
    cmd.cmd = "get"
    cmd_get(cmd)
  elseif cmd.cmd == "add" then
    cmd_add(cmd)
  elseif cmd.cmd == "remove" then
    cmd_remove(cmd)
  elseif cmd.cmd == "done" then
    cmd.cmd = "remove"
    cmd_remove(cmd)
  elseif cmd.cmd == "stop" then
    cmd_stop(cmd)
  else
    printHelp()
  end
end

-- Function for handling get command. Issues get and prints results
function cmd_get(cmd)
  -- Format cmd correctly & send
  cmd.args = nil
  modem.transmit(COMMAND_CHANNEL, RESPONSE_CHANNEL, textutils.serialize(cmd))

  -- Wait for response
  local resp = waitForResponse()

  -- Print message if empty
  if table.getn(resp) == 0 then
    print("TODO List empty")
  else
    -- Loop through each one, add index prefix
    local i = 1
    for k,v in pairs(resp) do
      print(i..": "..v.contents)
      i = i + 1
    end
  end
end

-- Function for handling add command. Issues add and prints result
function cmd_add(cmd)
  -- Flatten string args into single string
  local str = ""
  for k,v in pairs(cmd.args) do
    -- Will have trailing space, don't really care
    str = str..v.." "
  end

  -- Correct cmd.args value to flattened value
  cmd.args = {str}

  -- Send it
  modem.transmit(COMMAND_CHANNEL, RESPONSE_CHANNEL, textutils.serialize(cmd))

  -- Get and print our response
  local resp = waitForResponse()
  print(resp)
end

-- Function for handling remove command. Issues remove and prints result
function cmd_remove(cmd)
  -- Just send it, simple command
  modem.transmit(COMMAND_CHANNEL, RESPONSE_CHANNEL, textutils.serialize(cmd))

  -- Get and print our response
  local resp = waitForResponse()
  print(resp)
end

-- Function for handling stop command. Issues stop and prints result
function cmd_stop(cmd)
  -- Just send it, simple command
  modem.transmit(COMMAND_CHANNEL, RESPONSE_CHANNEL, textutils.serialize(cmd))

  -- Get and print our response
  local resp = waitForResponse()
  print(resp)
end

---------------------------------------------------------[ Helper Functions ]--

-- Gets a single message from the modem
function getMessage(m)
  -- print("Waiting for message...")
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

-- Helper function for printing the help message
function printHelp()
  print("Usage:")
  print("  get - Prints current list of TODOs")
  print("  add <ele> - Adds the given TODO element")
  print("  remove <index> - Removes the given TODO index")
end

-- Helper function to wait for a response. Returns obj version
function waitForResponse()
  return contents(getMessage())
end

run()