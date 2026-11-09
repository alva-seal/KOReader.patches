-- 2-zenfm-autostart.lua
-- Auto-start ZenFM silently when Wi-Fi is already connected.
-- Drop this file into your KOReader user patches directory.

local ok_ui, UIManager = pcall(require, "ui/uimanager")
if not ok_ui or not UIManager then return end

local function is_connected()
  local ok_net, NetworkMgr = pcall(require, "ui/network/manager")
  if not ok_net or not NetworkMgr then return false end

  -- Try common KOReader network status methods; fall back conservatively.
  if type(NetworkMgr.isConnected) == "function" then
    return NetworkMgr:isConnected()
  end
  if type(NetworkMgr.isOnline) == "function" then
    return NetworkMgr:isOnline()
  end
  if type(NetworkMgr.isWifiOn) == "function" then
    return NetworkMgr:isWifiOn()
  end
  return false
end

-- Set to true if you also want Android to auto-start (first time needs OS approval).
local ALLOW_ANDROID = false

local function is_android()
  local ok = pcall(require, "android")
  return ok
end

local started = false
local function try_start()
  if started then return end

  -- Only start when Wi-Fi is already connected.
  if not is_connected() then
    UIManager:scheduleIn(5, try_start)
    return
  end

  if is_android() and not ALLOW_ANDROID then
    -- Skip auto-start on Android unless explicitly allowed above.
    started = true
    return
  end

  local ok_daemon, Daemon = pcall(require, "zenfm_daemon")
  if not ok_daemon or not Daemon then
    -- ZenFM plugin not installed or not available; stop retrying.
    started = true
    return
  end

  local d = Daemon:new()
  if d:status() then
    started = true
    return
  end

  -- Start the backend directly (no "running" popup).
  local ok, _ = d:start()
  -- Mark as done regardless; you can reboot or stop/start manually later if needed.
  started = true
end

-- Wait a moment for KOReader UI to settle, then begin polling.
UIManager:scheduleIn(3, try_start)
