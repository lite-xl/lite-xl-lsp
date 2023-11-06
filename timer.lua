local core = require "core"
local Object = require "core.object"

---Timer class
---@class lsp.timer : core.object
---@field public interval integer
---@field public single_shot boolean
---@field private started boolean
---@field private last_run integer
local Timer = Object:extend()

---Constructor
---@param interval integer The interval in milliseconds
---@param single_shot boolean Indicates if timer should only run once
function Timer:new(interval, single_shot)
  Timer.super.new(self)

  self.single_shot = single_shot or false
  self.started = false
  self.cancel_thread_marker = { cancel = true }
  self.last_run = 0

  self:set_interval(interval or 1000)
end

---Starts a non running timer.
function Timer:start()
  if self.started then return end

  self.started = true
  self.cancel_thread_marker = { cancel = false }
  local this = self

  -- Save marker so that we keep this one and not an "updated" one
  local marker = self.cancel_thread_marker
  core.add_thread(function()
    while true do
      if marker.cancel == true then return end
      this:reset()
      local now = system.get_time()
      local remaining = (this.last_run + this.interval) - now
      if remaining > 0 then
        repeat
          if not this.started or marker.cancel then return end
          coroutine.yield(remaining)
          now = system.get_time()
          remaining = (this.last_run + this.interval) - now
        until remaining <= 0
      end
      if not this.started or marker.cancel then return end
      this:on_timer()
      if this.single_shot then break end
    end
    this.started = false
  end)
end

---Stops a running timer.
function Timer:stop()
  self.started = false
end

---Resets the timer countdown for execution.
function Timer:reset()
  self.last_run = system.get_time()
end

---Restarts the timer countdown for execution.
function Timer:restart()
  self:reset()
  if not self.started then
    self:start()
  end
end

---Check if the timer is running.
---@return boolean
function Timer:running()
  return self.started
end

---Appropriately set the timer interval by converting milliseconds to seconds.
---@param interval integer The interval in milliseconds
function Timer:set_interval(interval)
  local new_interval = interval / 1000
  -- As this new interval might be shorter than the currently running one, and
  -- because we might already be sleeping waiting for the old interval, we
  -- mark the already running coroutine as cancelled, and create a new one.
  if self.started and self.interval > new_interval then
    self.cancel_thread_marker.cancel = true
    self:stop()
    self:start()
  end
  self.interval = new_interval
end

---To be overwritten by the instantiated timer objects
function Timer:on_timer() end


return Timer
