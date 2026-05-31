local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local CollectRemote = remotes:WaitForChild("CollectHeldPack")
local CollectAllCardCash = remotes:WaitForChild("CollectAllCardCash")
local PackReroll = remotes:WaitForChild("PackReroll")
local PackPurchase = remotes:WaitForChild("PackPurchase")
local EquipPackTool = remotes:WaitForChild("EquipPackTool")

if _G.WaifuWindow then
   pcall(function() _G.WaifuWindow:Destroy() end)
   _G.WaifuWindow = nil
   task.wait(0.5)
end

local function httpFetch(url)
   local req = (syn and syn.request)
      or (http and http.request)
      or http_request
      or (fluxus and fluxus.request)
      or request
   if req then
      local ok, res = pcall(function()
         return req({ Url = url, Method = "GET" })
      end)
      if ok and res then
         local code = res.StatusCode or res.status or 0
         local body = res.Body or res.body
         if type(body) == "string" and #body > 500 and (code == 0 or (code >= 200 and code < 300)) then
            return body
         end
      end
   end
   local ok, body = pcall(function()
      return game:HttpGet(url)
   end)
   if ok and type(body) == "string" and #body > 500 then
      return body
   end
   return nil
end

local function loadRayfieldLibrary()
   local sources = {
      "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
      "https://raw.githubusercontent.com/Nvsted/Rayfield/main/source.lua",
      "https://sirius.menu/rayfield",
   }
   local lastErr = "unknown"
   for _, url in ipairs(sources) do
      local src = httpFetch(url)
      if src then
         local chunk, compileErr = loadstring(src)
         if chunk then
            local ok, lib = pcall(chunk)
            if ok and lib then
               return lib
            end
            lastErr = tostring(lib)
         else
            lastErr = tostring(compileErr)
         end
      else
         lastErr = "HTTP failed (403/blocked?): " .. url
      end
   end
   error("Rayfield could not load - " .. lastErr)
end

local Rayfield = loadRayfieldLibrary()

local Window = Rayfield:CreateWindow({
   Name = "Harold's Script V1.5",
   LoadingTitle = "Loading Script",
   LoadingSubtitle = "by PotatoIsCool and HAROLD BABY",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "PotatoScripts",
      FileName = "PotatosAnimeScript"
   },
   KeySystem = false,
})

_G.WaifuWindow = Window

-- Matches ConfigurationSaving in CreateWindow (Rayfield writes PotatoScripts/PotatosAnimeScript.rfld)
local RAYFIELD_CONFIG_FOLDER = "PotatoScripts"
local RAYFIELD_CONFIG_NAME = "PotatosAnimeScript"
local RAYFIELD_CONFIG_PATH = RAYFIELD_CONFIG_FOLDER .. "/" .. RAYFIELD_CONFIG_NAME .. ".rfld"
local AUTOLOAD_FILE = RAYFIELD_CONFIG_FOLDER .. "/waifu_autoload_enabled.flag"
local AUTOLOAD_LEGACY = "WaifuPotato_autoload.txt"
local DISCORD_WEBHOOK_FILE = "PotatoScripts/discord_webhook.txt"
local BACKEND_AUTH_FILE = "PotatoScripts/backend_auth.json"

-- Optional: paste webhook here if you do not use the Auto Buy tab input
local DEFAULT_DISCORD_WEBHOOK = ""
local DEFAULT_BACKEND_URL = "https://wcc.oracle.makogai.me"
local DEFAULT_BACKEND_API_KEY = "MAREMAREMARE"

local SaveFile = getgenv and getgenv() or {}
SaveFile.AutoCollect = false
SaveFile.AutoRoll = false
SaveFile.AutoRollDelay = 1.5
SaveFile.AutoBuyDelay = 1
SaveFile.AutoBuyVerifyDelay = 0.3
SaveFile.AutoBuyLocked = false
SaveFile.AutoOpenPacks = false
SaveFile.AutoBuyPacks = false
SaveFile.AutoPlace = false
SaveFile.AutoGradeToken = false
SaveFile.AutoServerhop = false
SaveFile.ServerhopDelay = 17
SaveFile.DiscordWebhook = ""
SaveFile.DiscordBuyNotify = true
SaveFile.DiscordNotifyMode = "instant" -- "instant" | "summary" | "backend"
SaveFile.DiscordSummaryMinutes = 10
SaveFile.BackendUrl = DEFAULT_BACKEND_URL
SaveFile.BackendApiKey = DEFAULT_BACKEND_API_KEY
SaveFile.BackendEnabled = true
SaveFile.BackendDashboardPassword = ""

local DiscordBuyBuffer = {
   entries = {},
   windowStart = nil,
   lastFlush = nil,
   summaryLoopRunning = false,
}

local DEFAULT_SELECTED_RANKS = {
   "Divine", "Celestial", "Goddess", "Valkyrie", "Archon",
   "Eternal", "Radiant", "RisingStar", "Beyond",
}
local DEFAULT_SELECTED_RARITIES = { "Rainbow", "Solaris" }

SaveFile.SelectedRarities = {
   ["All"] = false,
   ["Normal"] = false,
   ["Gold"] = false,
   ["Platinum"] = false,
   ["Emerald"] = false,
   ["Diamond"] = false,
   ["Rainbow"] = true,
   ["Nebula"] = false,
   ["Solaris"] = true,
}

SaveFile.SelectedRanks = {
   ["Princess"] = false,
   ["Queen"] = false,
   ["Matriarch"] = false,
   ["Empress"] = false,
   ["Seraph"] = false,
   ["Divine"] = true,
   ["Celestial"] = true,
   ["Goddess"] = true,
   ["Valkyrie"] = true,
   ["Archon"] = true,
   ["Eternal"] = true,
   ["Radiant"] = true,
   ["RisingStar"] = true,
   ["Beyond"] = true,
}

local function hasExecutorFilesystem()
   return typeof(isfile) == "function"
      and typeof(readfile) == "function"
      and typeof(writefile) == "function"
end

local function ensureConfigFolderExists()
   if typeof(makefolder) == "function" then
      pcall(makefolder, RAYFIELD_CONFIG_FOLDER)
   end
end

local function trimStoredText(s)
   if type(s) ~= "string" then
      return ""
   end
   return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function readAutoloadPath(path)
   if not hasExecutorFilesystem() or not isfile(path) then
      return ""
   end
   local ok, content = pcall(readfile, path)
   return ok and trimStoredText(content) or ""
end

local function migrateLegacyAutoloadFlag()
   if not hasExecutorFilesystem() then
      return
   end
   ensureConfigFolderExists()
   if isfile(AUTOLOAD_FILE) then
      return
   end
   if readAutoloadPath(AUTOLOAD_LEGACY) ~= "true" then
      return
   end
   pcall(function()
      writefile(AUTOLOAD_FILE, "true")
   end)
end

local function isAutoloadEnabled()
   if not hasExecutorFilesystem() then
      return false
   end
   local ok, res = pcall(function()
      migrateLegacyAutoloadFlag()
      if readAutoloadPath(AUTOLOAD_FILE) == "true" then
         return true
      end
      return readAutoloadPath(AUTOLOAD_LEGACY) == "true"
   end)
   return ok and res == true
end

local function setAutoload(enabled)
   if not hasExecutorFilesystem() then
      return false, "Filesystem APIs missing."
   end
   ensureConfigFolderExists()
   local payload = enabled and "true" or "false"
   local wOk, wErr = pcall(function()
      writefile(AUTOLOAD_FILE, payload)
   end)
   if not wOk then
      return false, tostring(wErr)
   end
   if readAutoloadPath(AUTOLOAD_FILE) ~= payload then
      return false, "Delta could not verify autoload flag on disk."
   end
   return true
end

local function packRayfieldColor(color)
   return { R = color.R * 255, G = color.G * 255, B = color.B * 255 }
end

local function saveRayfieldConfigToDisk()
   if not hasExecutorFilesystem() then
      return false, "This executor has no readfile/writefile."
   end
   if not Rayfield.Flags then
      return false, "UI not ready (Flags missing)."
   end
   ensureConfigFolderExists()
   local data = {}
   for flagName, v in pairs(Rayfield.Flags) do
      if v.Type == "ColorPicker" then
         data[flagName] = packRayfieldColor(v.Color)
      else
         if typeof(v.CurrentValue) == "boolean" then
            if v.CurrentValue == false then
               data[flagName] = false
            else
               data[flagName] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
            end
         else
            data[flagName] = v.CurrentValue or v.CurrentKeybind or v.CurrentOption or v.Color
         end
      end
   end
   local ok, err = pcall(function()
      writefile(RAYFIELD_CONFIG_PATH, HttpService:JSONEncode(data))
   end)
   if not ok then
      return false, tostring(err)
   end
   return true
end

local function getHttpRequest()
   return (syn and syn.request)
      or (http and http.request)
      or http_request
      or (fluxus and fluxus.request)
      or request
end

local function loadDiscordWebhookFromDisk()
   if DEFAULT_DISCORD_WEBHOOK ~= "" then
      SaveFile.DiscordWebhook = DEFAULT_DISCORD_WEBHOOK
      return
   end
   if not hasExecutorFilesystem() or not isfile(DISCORD_WEBHOOK_FILE) then
      return
   end
   local ok, content = pcall(readfile, DISCORD_WEBHOOK_FILE)
   if ok and type(content) == "string" and content:find("discord") then
      SaveFile.DiscordWebhook = content:gsub("^%s+", ""):gsub("%s+$", "")
   end
end

local function saveDiscordWebhookToDisk(url)
   if not hasExecutorFilesystem() then
      return
   end
   ensureConfigFolderExists()
   pcall(function()
      writefile(DISCORD_WEBHOOK_FILE, url)
   end)
end

local Backend = {
   _sessionId = nil,
   _sessionStart = nil,
   _heartbeatRunning = false,
   LastError = nil,
   ScriptVersion = "1.5",
}

function Backend.sessionId()
   if not Backend._sessionId then
      Backend._sessionId = string.format("%d_%d", os.time(), math.random(100000, 999999))
      Backend._sessionStart = os.clock()
   end
   return Backend._sessionId
end

function Backend.uptimeSec()
   if not Backend._sessionStart then
      return 0
   end
   return math.floor(os.clock() - Backend._sessionStart)
end

function Backend.isReady()
   return SaveFile.BackendEnabled
      and SaveFile.BackendUrl ~= ""
      and SaveFile.BackendApiKey ~= ""
      and getHttpRequest() ~= nil
end

local function backendBuildRow(eventName, props)
   props = props or {}
   return {
      event_name = eventName,
      user_id = Player.UserId,
      username = Player.Name,
      place_id = game.PlaceId,
      job_id = game.JobId,
      session_id = Backend.sessionId(),
      script_version = Backend.ScriptVersion,
      props = props,
   }
end

local function backendPostJson(path, body)
   local url = SaveFile.BackendUrl:gsub("/+$", "") .. path
   local req = getHttpRequest()
   if not req then
      return false, "no_http", nil
   end
   local ok, result = pcall(function()
      return req({
         Url = url,
         Method = "POST",
         Headers = {
            ["Content-Type"] = "application/json",
            ["X-API-Key"] = SaveFile.BackendApiKey,
         },
         Body = HttpService:JSONEncode(body),
      })
   end)
   if not ok then
      Backend.LastError = tostring(result)
      return false, Backend.LastError, nil
   end
   local status = result.StatusCode or result.status or result.Status
   local responseBody = result.Body or result.body or ""
   if status and status >= 200 and status < 300 then
      Backend.LastError = nil
      return true, nil, responseBody
   end
   Backend.LastError = "http_" .. tostring(status or "unknown") .. " " .. tostring(responseBody):sub(1, 200)
   return false, Backend.LastError, responseBody
end

local function backendPostRow(row)
   return backendPostJson("/api.php", row)
end

local function generateBackendPassword()
   local chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"
   local out = {}
   for i = 1, 16 do
      local idx = math.random(1, #chars)
      out[i] = chars:sub(idx, idx)
   end
   return table.concat(out)
end

local function loadBackendAuthFromDisk()
   if not hasExecutorFilesystem() or not isfile(BACKEND_AUTH_FILE) then
      return nil
   end
   local ok, content = pcall(readfile, BACKEND_AUTH_FILE)
   if not ok or type(content) ~= "string" then
      return nil
   end
   local okDecode, data = pcall(function()
      return HttpService:JSONDecode(content)
   end)
   if okDecode and type(data) == "table" then
      return data
   end
   return nil
end

local function saveBackendAuthToDisk(auth)
   if not hasExecutorFilesystem() then
      return
   end
   ensureConfigFolderExists()
   pcall(function()
      writefile(BACKEND_AUTH_FILE, HttpService:JSONEncode(auth))
   end)
end

local function ensureBackendDashboardAccount(showNotify)
   if not Backend.isReady() then
      return false, "not_ready"
   end

   local username = Player.Name
   local userId = Player.UserId
   local auth = loadBackendAuthFromDisk()
   local password
   local isNew = false

   if auth
      and auth.username == username
      and tonumber(auth.user_id) == userId
      and type(auth.password) == "string"
      and auth.password ~= ""
   then
      password = auth.password
   else
      password = generateBackendPassword()
      isNew = true
   end

   local ok, err = backendPostJson("/auth.php", {
      username = username,
      user_id = userId,
      password = password,
   })
   if not ok then
      return false, err
   end

   saveBackendAuthToDisk({
      username = username,
      user_id = userId,
      password = password,
   })
   SaveFile.BackendDashboardPassword = password

   if showNotify and isNew then
      Rayfield:Notify({
         Title = "Dashboard account created",
         Content = string.format(
            "Login at your analytics site\nUser: %s\nPass: %s\n(Saved in PotatoScripts/backend_auth.json)",
            username,
            password
         ),
         Duration = 12,
         Image = 4483362458,
      })
   end

   return true
end

function Backend.track(eventName, props)
   if not Backend.isReady() then
      return false
   end
   task.spawn(function()
      local ok, err = backendPostRow(backendBuildRow(eventName, props))
      if not ok then
         warn("[Backend]", eventName, err)
      end
   end)
   return true
end

function Backend.trackAction(eventName, props, source)
   props = props or {}
   if props.source == nil then
      props.source = source or "script_auto"
   end
   return Backend.track(eventName, props)
end

function Backend.trackToggle(feature, enabled, tab)
   return Backend.trackAction("feature_toggle", {
      feature = feature,
      enabled = enabled == true,
      tab = tab or "unknown",
   }, "script_manual")
end

function Backend.trackSync(eventName, props)
   if not Backend.isReady() then
      return false, "not_ready"
   end
   local ok, err = backendPostRow(backendBuildRow(eventName, props))
   return ok, err
end

function Backend.ensureAccount(showNotify)
   return ensureBackendDashboardAccount(showNotify == true)
end

function Backend.startSession()
   Backend.track("script_load", {
      executor = (identifyexecutor and identifyexecutor()) or "unknown",
   })
end

function Backend.endSession()
   Backend.trackSync("script_destroy", { uptime_sec = Backend.uptimeSec() })
end

function Backend.startHeartbeat()
   if Backend._heartbeatRunning then
      return
   end
   Backend._heartbeatRunning = true
   task.spawn(function()
      while Backend._heartbeatRunning and Backend.isReady() do
         Backend.track("session_heartbeat", {
            uptime_sec = Backend.uptimeSec(),
            auto_roll = SaveFile.AutoRoll,
            auto_buy = SaveFile.AutoBuyPacks,
         })
         task.wait(300)
      end
   end)
end

function Backend.stopHeartbeat()
   Backend._heartbeatRunning = false
end

local function applyBackendDefaults()
   SaveFile.BackendUrl = DEFAULT_BACKEND_URL
   SaveFile.BackendApiKey = DEFAULT_BACKEND_API_KEY
   SaveFile.BackendEnabled = true
end

local function loadBackendConfigFromDisk()
   applyBackendDefaults()
   local auth = loadBackendAuthFromDisk()
   if auth and type(auth.password) == "string" then
      SaveFile.BackendDashboardPassword = auth.password
   end
end

local function trackBackendPurchase(rank, variant, slot, priceText)
   Backend.trackAction("pack_purchase", {
      rank = rank,
      variant = variant,
      slot = slot,
      price = priceText,
   })
end

local function sendDiscordWebhook(payload)
   local webhookUrl = SaveFile.DiscordWebhook
   if webhookUrl == "" or not webhookUrl:find("discord") then
      return false, "no_webhook"
   end
   local req = getHttpRequest()
   if not req then
      return false, "no_http"
   end
   local ok, result = pcall(function()
      return req({
         Url = webhookUrl,
         Method = "POST",
         Headers = { ["Content-Type"] = "application/json" },
         Body = HttpService:JSONEncode(payload),
      })
   end)
   if not ok then
      return false, tostring(result)
   end
   local status = result and (result.StatusCode or result.status or result.Status)
   if status and status >= 200 and status < 300 then
      return true
   end
   return false, "http_" .. tostring(status or "unknown")
end

local function discordNotificationsEnabled()
   return SaveFile.DiscordBuyNotify
      and SaveFile.DiscordWebhook ~= ""
      and SaveFile.DiscordWebhook:find("discord")
end

local function sendDiscordInstantPurchase(rank, variant, slot, priceText)
   local fields = {
      { name = "Rank", value = tostring(rank), inline = true },
      { name = "Variant", value = tostring(variant), inline = true },
      { name = "Station slot", value = tostring(slot), inline = true },
      { name = "Player", value = Player.Name .. " (`" .. tostring(Player.UserId) .. "`)", inline = false },
   }
   if priceText and priceText ~= "" then
      table.insert(fields, { name = "Price", value = priceText, inline = true })
   end
   return sendDiscordWebhook({
      username = "Waifu Script",
      embeds = {
         {
            title = "Auto Buy — pack purchased",
            description = string.format("**%s** · **%s** (slot %s)", rank, variant, slot),
            color = 5793266,
            fields = fields,
            footer = { text = "Instant · otherscript.lua" },
         },
      },
   })
end

local function buildDiscordSummaryLines(entries)
   local grouped = {}
   local order = {}
   for _, e in ipairs(entries) do
      local key = string.format("%s · %s", e.rank, e.variant)
      if not grouped[key] then
         grouped[key] = { count = 0, slots = {} }
         table.insert(order, key)
      end
      grouped[key].count = grouped[key].count + 1
      local slotKey = tostring(e.slot)
      grouped[key].slots[slotKey] = (grouped[key].slots[slotKey] or 0) + 1
   end
   table.sort(order)
   local lines = {}
   for _, key in ipairs(order) do
      local g = grouped[key]
      local slotParts = {}
      for slot, n in pairs(g.slots) do
         table.insert(slotParts, n > 1 and ("slot " .. slot .. "×" .. n) or ("slot " .. slot))
      end
      table.sort(slotParts)
      local line = string.format("**%s** — **%d** bought", key, g.count)
      if #slotParts > 0 then
         line = line .. " _(`" .. table.concat(slotParts, ", ") .. "`)_"
      end
      table.insert(lines, line)
   end
   return lines
end

local function flushDiscordBuySummary(reason)
   if #DiscordBuyBuffer.entries == 0 then
      return false, "empty"
   end
   local entries = DiscordBuyBuffer.entries
   local total = #entries
   local lines = buildDiscordSummaryLines(entries)
   local description = table.concat(lines, "\n")
   if #description > 3900 then
      description = description:sub(1, 3900) .. "\n\n_…list truncated_"
   end
   local windowStart = DiscordBuyBuffer.windowStart or os.time()
   local elapsedMin = math.max(1, math.floor((os.time() - windowStart) / 60))
   local intervalMin = tonumber(SaveFile.DiscordSummaryMinutes) or 10
   local payload = {
      username = "Waifu Script",
      embeds = {
         {
            title = "Auto Buy — " .. elapsedMin .. " min summary",
            description = description,
            color = 10181046,
            fields = {
               { name = "Total purchases", value = tostring(total), inline = true },
               { name = "Unique packs", value = tostring(#lines), inline = true },
               { name = "Player", value = Player.Name .. " (`" .. tostring(Player.UserId) .. "`)", inline = false },
               { name = "Reason", value = reason or "interval", inline = true },
            },
            footer = { text = "Summary every " .. tostring(intervalMin) .. " min · otherscript.lua" },
         },
      },
   }
   local ok, err = sendDiscordWebhook(payload)
   DiscordBuyBuffer.entries = {}
   DiscordBuyBuffer.windowStart = os.time()
   DiscordBuyBuffer.lastFlush = os.time()
   return ok, err
end

local function ensureDiscordSummaryLoop()
   if DiscordBuyBuffer.summaryLoopRunning then
      return
   end
   if SaveFile.DiscordNotifyMode ~= "summary" or not discordNotificationsEnabled() then
      return
   end
   DiscordBuyBuffer.summaryLoopRunning = true
   if not DiscordBuyBuffer.windowStart then
      DiscordBuyBuffer.windowStart = os.time()
   end
   if not DiscordBuyBuffer.lastFlush then
      DiscordBuyBuffer.lastFlush = os.time()
   end
   task.spawn(function()
      while SaveFile.DiscordNotifyMode == "summary" and discordNotificationsEnabled() do
         task.wait(1)
         local intervalSec = math.max(60, (tonumber(SaveFile.DiscordSummaryMinutes) or 10) * 60)
         if (os.time() - (DiscordBuyBuffer.lastFlush or os.time())) >= intervalSec then
            if #DiscordBuyBuffer.entries > 0 then
               local ok, err = flushDiscordBuySummary(tostring(SaveFile.DiscordSummaryMinutes) .. " minute timer")
               if not ok then
                  warn("[Discord] summary flush failed:", err)
               end
            else
               DiscordBuyBuffer.lastFlush = os.time()
            end
         end
      end
      DiscordBuyBuffer.summaryLoopRunning = false
   end)
end

local function notifyDiscordPackPurchase(rank, variant, slot, priceText)
   trackBackendPurchase(rank, variant, slot, priceText)

   if SaveFile.DiscordNotifyMode == "backend" then
      return
   end
   if not discordNotificationsEnabled() then
      return
   end
   if SaveFile.DiscordNotifyMode == "summary" then
      if not DiscordBuyBuffer.windowStart then
         DiscordBuyBuffer.windowStart = os.time()
      end
      table.insert(DiscordBuyBuffer.entries, {
         rank = rank,
         variant = variant,
         slot = slot,
         price = priceText,
         t = os.time(),
      })
      ensureDiscordSummaryLoop()
      return
   end
   task.spawn(function()
      local ok, err = sendDiscordInstantPurchase(rank, variant, slot, priceText)
      if not ok then
         warn("[Discord] instant notify failed:", err)
      end
   end)
end

local function findActivePackModel(packFolder)
   for _, child in ipairs(packFolder:GetChildren()) do
      if child.Name:find("ActivePack") then
         return child
      end
   end
   return nil
end

local function readPackSlotInfo(packFolder)
   local slotIndex = tonumber(packFolder.Name:match("%d+"))
   if not slotIndex then
      return nil
   end

   local packName = packFolder:GetAttribute("PackName")
   local variantName = packFolder:GetAttribute("VariantName")
   if packName and variantName and variantName ~= "" then
      return slotIndex, packName, variantName
   end

   local item = findActivePackModel(packFolder)
   if not item then
      return slotIndex, nil, nil
   end

   local itemRank = item.Name:gsub("ActivePack%-", "")
   local gui = item:FindFirstChild("PackPriceBillboardGui")
   local frame = gui and gui:FindFirstChild("Frame")
   local label = frame and frame:FindFirstChild("VariantLabel")
   local itemRarity = (label and label.Text ~= "") and label.Text or "Normal"
   return slotIndex, itemRank, itemRarity
end

local function getPackPriceFromBillboard(item)
   local gui = item:FindFirstChild("PackPriceBillboardGui")
   local frame = gui and gui:FindFirstChild("Frame")
   if not frame then
      return nil
   end
   for _, child in ipairs(frame:GetChildren()) do
      if child:IsA("TextLabel") and (child.Name:lower():find("price") or child.Name:lower():find("cost")) then
         if child.Text and child.Text ~= "" then
            return child.Text
         end
      end
   end
   return nil
end

loadDiscordWebhookFromDisk()
loadBackendConfigFromDisk()

local function syncSaveFileFromRayfieldFlags()
   local flags = Rayfield.Flags
   if not flags then
      return
   end
   local delayInput = flags.ServerhopDelayInput
   if delayInput and typeof(delayInput.CurrentValue) == "string" then
      local n = tonumber(delayInput.CurrentValue)
      if n and n > 0 then
         SaveFile.ServerhopDelay = n
      end
   end
   local rollDelayInput = flags.AutoRollDelayInput
   if rollDelayInput and typeof(rollDelayInput.CurrentValue) == "string" then
      local n = tonumber(rollDelayInput.CurrentValue)
      if n and n > 0 then
         SaveFile.AutoRollDelay = n
      end
   end
   local buyDelayInput = flags.AutoBuyDelayInput
   if buyDelayInput and typeof(buyDelayInput.CurrentValue) == "string" then
      local n = tonumber(buyDelayInput.CurrentValue)
      if n and n > 0 then
         SaveFile.AutoBuyDelay = n
      end
   end
   local buyVerifyInput = flags.AutoBuyVerifyDelayInput
   if buyVerifyInput and typeof(buyVerifyInput.CurrentValue) == "string" then
      local n = tonumber(buyVerifyInput.CurrentValue)
      if n and n >= 0 then
         SaveFile.AutoBuyVerifyDelay = n
      end
   end
end

local MainTab = Window:CreateTab("Main", 4483362458)
MainTab:CreateSection("Main")

MainTab:CreateToggle({
   Name = "Auto Collect Cash",
   CurrentValue = false,
   Flag = "AutoCollectFlag",
   Callback = function(Value)
      SaveFile.AutoCollect = Value
      Backend.trackToggle("AutoCollectCash", Value, "Main")
      if SaveFile.AutoCollect then
         task.spawn(function()
            while SaveFile.AutoCollect do
               CollectAllCardCash:FireServer()
               Backend.trackAction("cash_collect", { mode = "all" })
               task.wait(1)
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Collect All Cash",
   Callback = function()
      CollectAllCardCash:FireServer()
      Backend.trackAction("cash_collect", { mode = "all" }, "script_manual")
   end,
})

MainTab:CreateButton({
   Name = "Collect All GradeTokens (BETA)",
   Callback = function()
      local character = Player.Character or Player.CharacterAdded:Wait()
      local hrp = character:WaitForChild("HumanoidRootPart")
      local originalCFrame = hrp.CFrame

      local systems = Workspace:FindFirstChild("Systems")
      if not systems then return end
      local obbyTokens = systems:FindFirstChild("GradeObbyTokens")
      if not obbyTokens then return end

      local function dropOnToken(tokenPart)
         hrp.CFrame = tokenPart.CFrame + Vector3.new(0, 15, 0)
         task.wait(0.8)
      end

      for _, diffName in ipairs({"Easy", "Medium", "Hard"}) do
         local diffFolder = obbyTokens:FindFirstChild(diffName)
         if diffFolder then
            for _, slot in ipairs(diffFolder:GetChildren()) do
               local tokenPart = slot:FindFirstChild("GradeTokenPart")
               if tokenPart then
                  dropOnToken(tokenPart)
                  if tokenPart and tokenPart.Parent then
                     dropOnToken(tokenPart)
                  end
                  if not (tokenPart and tokenPart.Parent) then
                     Backend.trackAction("grade_token_collect", {
                        difficulty = diffName,
                        slot = slot.Name,
                     }, "script_manual")
                  end
               end
            end
         end
      end

      task.wait(0.2)
      hrp.CFrame = originalCFrame
   end,
})

MainTab:CreateToggle({
   Name = "Auto Collect GradeTokens",
   CurrentValue = false,
   Flag = "AutoGradeTokenFlag",
   Callback = function(Value)
      SaveFile.AutoGradeToken = Value
      Backend.trackToggle("AutoGradeToken", Value, "Main")
      if SaveFile.AutoGradeToken then
         task.spawn(function()
            -- v1.lua "Auto Find Grade Tokens" uses workspace.Systems.GradeTokens + TokenName attribute with NO cooldown —
            -- it only sleeps 1s when nothing was found. Here we likewise skip timers: if GradeTokenPart exists, farm it every pass.
            local function dropOnToken(tokenPart)
               local character = Player.Character or Player.CharacterAdded:Wait()
               local hrp = character:WaitForChild("HumanoidRootPart")
               hrp.CFrame = tokenPart.CFrame + Vector3.new(0, 15, 0)
               task.wait(0.8)
            end

            while SaveFile.AutoGradeToken do
               local character = Player.Character or Player.CharacterAdded:Wait()
               local hrp = character:WaitForChild("HumanoidRootPart")
               local originalCFrame = hrp.CFrame

               local systems = Workspace:FindFirstChild("Systems")
               local obbyTokens = systems and systems:FindFirstChild("GradeObbyTokens")

               local foundAny = false
               if obbyTokens then
                  for _, diffName in ipairs({"Easy", "Medium", "Hard"}) do
                     if not SaveFile.AutoGradeToken then
                        break
                     end
                     local diffFolder = obbyTokens:FindFirstChild(diffName)
                     if diffFolder then
                        for _, slot in ipairs(diffFolder:GetChildren()) do
                           if not SaveFile.AutoGradeToken then
                              break
                           end
                           local tokenPart = slot:FindFirstChild("GradeTokenPart")
                           if tokenPart and tokenPart.Parent then
                              foundAny = true
                              dropOnToken(tokenPart)
                              if tokenPart and tokenPart.Parent then
                                 dropOnToken(tokenPart)
                              end
                              if not (tokenPart and tokenPart.Parent) then
                                 Backend.trackAction("grade_token_collect", {
                                    difficulty = diffName,
                                    slot = slot.Name,
                                 })
                                 Rayfield:Notify({
                                    Title = "GradeToken",
                                    Content = "Collected " .. diffName .. " - " .. slot.Name,
                                    Duration = 3,
                                    Image = 4483362458,
                                 })
                              end
                           end
                        end
                     end
                  end

                  hrp.CFrame = originalCFrame
               end

               if not SaveFile.AutoGradeToken then
                  break
               end
               task.wait(foundAny and 0.35 or 1)
            end
         end)
      end
   end,
})

MainTab:CreateSection("Server Hop")

MainTab:CreateInput({
   Name = "Serverhop Delay (seconds)",
   PlaceholderText = "17",
   RemoveTextAfterFocusLost = false,
   Flag = "ServerhopDelayInput",
   Callback = function(Text)
      local num = tonumber(Text)
      if num and num > 0 then
         SaveFile.ServerhopDelay = num
      end
   end,
})

MainTab:CreateToggle({
   Name = "Auto Serverhop",
   CurrentValue = false,
   Flag = "AutoServerhopFlag",
   Callback = function(Value)
      SaveFile.AutoServerhop = Value
      Backend.trackToggle("AutoServerhop", Value, "Main")
      if SaveFile.AutoServerhop then
         task.spawn(function()
            while SaveFile.AutoServerhop do
               task.wait(SaveFile.ServerhopDelay)
               if not SaveFile.AutoServerhop then break end

               local baseUrl = "https://games.roblox.com/v1/games/"
                  .. game.PlaceId
                  .. "/servers/Public?sortOrder=Asc&limit=100"
               local success, data = pcall(function()
                  local raw = game:HttpGet(baseUrl)
                  return HttpService:JSONDecode(raw)
               end)

               if not success or not data or not data.data or #data.data == 0 then
                  warn("Serverhop: Failed to fetch servers, retrying next cycle.")
                  continue
               end

               local servers = data.data
               local pool = math.max(1, math.floor(#servers / 3))
               local server = servers[math.random(1, pool)]
               if not server then
                  warn("Serverhop: No valid server found, retrying next cycle.")
                  continue
               end
               if server.id == game.JobId then
                  warn("Serverhop: Picked current server, retrying next cycle.")
                  continue
               end
               if server.playing >= server.maxPlayers then
                  warn("Serverhop: Server is full, retrying next cycle.")
                  continue
               end

               print("Serverhopping to:", server.id)
               Backend.trackAction("server_hop", {
                  target_job_id = server.id,
                  delay_sec = SaveFile.ServerhopDelay,
                  players = server.playing,
               })
               TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, Player)
               task.wait(5)
            end
         end)
      end
   end,
})

MainTab:CreateParagraph({
   Title = "Note From Developer:",
   Content = "There is not too much features. But nobody has made a script for this game and someone was asking for it. So I made it."
})

local AutoBuy = Window:CreateTab("AutoBuy", 4483362458)

AutoBuy:CreateDropdown({
   Name = "Select Active Packs",
   Options = {
      "Princess", "Queen", "Matriarch", "Empress", "Seraph",
      "Divine", "Celestial", "Goddess", "Valkyrie", "Archon",
      "Eternal", "Radiant", "RisingStar", "Beyond"
   },
   CurrentOption = DEFAULT_SELECTED_RANKS,
   MultipleOptions = true,
   Flag = "RankDropdown",
   Callback = function(Options)
      for rank in pairs(SaveFile.SelectedRanks) do
         SaveFile.SelectedRanks[rank] = false
      end
      for _, selectedName in ipairs(Options) do
         SaveFile.SelectedRanks[selectedName] = true
      end
   end,
})

AutoBuy:CreateDropdown({
   Name = "Select Rarities",
   Options = {
      "All", "Normal", "Gold", "Platinum", "Emerald", "Diamond", "Rainbow", "Nebula", "Solaris"
   },
   CurrentOption = DEFAULT_SELECTED_RARITIES,
   MultipleOptions = true,
   Flag = "RarityDropdown",
   Callback = function(Options)
      for rarity in pairs(SaveFile.SelectedRarities) do
         SaveFile.SelectedRarities[rarity] = false
      end
      for _, selected in ipairs(Options) do
         SaveFile.SelectedRarities[selected] = true
      end
   end,
})

AutoBuy:CreateSection("Discord")

AutoBuy:CreateInput({
   Name = "Discord Webhook URL",
   PlaceholderText = "https://discord.com/api/webhooks/...",
   RemoveTextAfterFocusLost = false,
   Flag = "DiscordWebhookInput",
   Callback = function(Text)
      Text = Text:gsub("^%s+", ""):gsub("%s+$", "")
      SaveFile.DiscordWebhook = Text
      if Text ~= "" and Text:find("discord") then
         saveDiscordWebhookToDisk(Text)
         Rayfield:Notify({
            Title = "Discord",
            Content = "Webhook saved. You will get a message when auto-buy purchases a pack.",
            Duration = 4,
            Image = 4483362458,
         })
      end
   end,
})

AutoBuy:CreateToggle({
   Name = "Discord notify on auto-buy",
   CurrentValue = true,
   Flag = "DiscordBuyNotifyFlag",
   Callback = function(Value)
      SaveFile.DiscordBuyNotify = Value
      Backend.trackToggle("DiscordBuyNotify", Value, "AutoBuy")
      if not Value and #DiscordBuyBuffer.entries > 0 then
         flushDiscordBuySummary("notifications turned off")
      end
   end,
})

AutoBuy:CreateDropdown({
   Name = "Discord notify mode",
   Options = { "Instant", "Summary", "Backend" },
   CurrentOption = { "Instant" },
   MultipleOptions = false,
   Flag = "DiscordNotifyModeDropdown",
   Callback = function(Options)
      local choice = Options[1] or "Instant"
      if choice:find("Backend") then
         if SaveFile.DiscordNotifyMode == "summary" and #DiscordBuyBuffer.entries > 0 then
            flushDiscordBuySummary("switched to backend")
         end
         SaveFile.DiscordNotifyMode = "backend"
         Rayfield:Notify({
            Title = "Discord",
            Content = "Backend mode: purchases log to your server; Discord summaries sent by cron.",
            Duration = 5,
            Image = 4483362458,
         })
      elseif choice:find("Summary") then
         if SaveFile.DiscordNotifyMode == "instant" and #DiscordBuyBuffer.entries > 0 then
            flushDiscordBuySummary("switched to summary")
         end
         SaveFile.DiscordNotifyMode = "summary"
         ensureDiscordSummaryLoop()
         Rayfield:Notify({
            Title = "Discord",
            Content = "Summary mode: one message every " .. tostring(SaveFile.DiscordSummaryMinutes or 10) .. " minutes.",
            Duration = 4,
            Image = 4483362458,
         })
      else
         if SaveFile.DiscordNotifyMode == "summary" and #DiscordBuyBuffer.entries > 0 then
            flushDiscordBuySummary("switched to instant")
         end
         SaveFile.DiscordNotifyMode = "instant"
         Rayfield:Notify({
            Title = "Discord",
            Content = "Instant mode: message on each buy.",
            Duration = 4,
            Image = 4483362458,
         })
      end
   end,
})

AutoBuy:CreateDropdown({
   Name = "Discord summary interval",
   Options = { "10 min", "30 min" },
   CurrentOption = { (tostring(SaveFile.DiscordSummaryMinutes or 10) .. " min") },
   MultipleOptions = false,
   Flag = "DiscordSummaryIntervalDropdown",
   Callback = function(Options)
      local choice = Options[1] or "10 min"
      local n = tonumber(choice:match("%d+")) or 10
      SaveFile.DiscordSummaryMinutes = n
      if SaveFile.DiscordNotifyMode == "summary" then
         ensureDiscordSummaryLoop()
         Rayfield:Notify({
            Title = "Discord",
            Content = "Summary interval set to " .. tostring(n) .. " minutes.",
            Duration = 4,
            Image = 4483362458,
         })
      end
   end,
})

AutoBuy:CreateButton({
   Name = "Send Discord summary now",
   Callback = function()
      if not discordNotificationsEnabled() then
         Rayfield:Notify({ Title = "Discord", Content = "Enable notify + set webhook first.", Duration = 4, Image = 4483362458 })
         return
      end
      if #DiscordBuyBuffer.entries == 0 then
         Rayfield:Notify({ Title = "Discord", Content = "No purchases queued yet.", Duration = 4, Image = 4483362458 })
         return
      end
      local ok, err = flushDiscordBuySummary("manual")
      if ok then
         Rayfield:Notify({ Title = "Discord", Content = "Summary sent!", Duration = 4, Image = 4483362458 })
      else
         Rayfield:Notify({ Title = "Discord", Content = tostring(err), Duration = 6, Image = 4483362458 })
      end
   end,
})

AutoBuy:CreateButton({
   Name = "Test Discord Webhook",
   Callback = function()
      if SaveFile.DiscordWebhook == "" or not SaveFile.DiscordWebhook:find("discord") then
         Rayfield:Notify({
            Title = "Discord",
            Content = "Paste your webhook URL in the input above first.",
            Duration = 5,
            Image = 4483362458,
         })
         return
      end
      local ok, err = sendDiscordWebhook({
         username = "Waifu Script",
         embeds = {
            {
               title = "Webhook test",
               description = "If you see this, auto-buy notifications will work.",
               color = 3447003,
               fields = {
                  { name = "Player", value = Player.Name, inline = true },
                  { name = "Place", value = tostring(game.PlaceId), inline = true },
               },
            },
         },
      })
      if ok then
         Rayfield:Notify({ Title = "Discord", Content = "Test message sent!", Duration = 4, Image = 4483362458 })
      else
         Rayfield:Notify({ Title = "Discord failed", Content = tostring(err), Duration = 6, Image = 4483362458 })
      end
   end,
})

AutoBuy:CreateInput({
   Name = "Auto Roll Delay (seconds)",
   PlaceholderText = "1.5",
   RemoveTextAfterFocusLost = false,
   Flag = "AutoRollDelayInput",
   Callback = function(Text)
      local num = tonumber(Text)
      if num and num > 0 then
         SaveFile.AutoRollDelay = num
      end
   end,
})

AutoBuy:CreateInput({
   Name = "Auto Buy Scan Delay (seconds)",
   PlaceholderText = "1",
   RemoveTextAfterFocusLost = false,
   Flag = "AutoBuyDelayInput",
   Callback = function(Text)
      local num = tonumber(Text)
      if num and num > 0 then
         SaveFile.AutoBuyDelay = num
      end
   end,
})

AutoBuy:CreateInput({
   Name = "Auto Buy Verify Delay (seconds)",
   PlaceholderText = "0.3",
   RemoveTextAfterFocusLost = false,
   Flag = "AutoBuyVerifyDelayInput",
   Callback = function(Text)
      local num = tonumber(Text)
      if num and num >= 0 then
         SaveFile.AutoBuyVerifyDelay = num
      end
   end,
})

AutoBuy:CreateToggle({
   Name = "Auto Roll Packs",
   CurrentValue = false,
   Flag = "AutoRollFlag",
   Callback = function(Value)
      SaveFile.AutoRoll = Value
      Backend.trackToggle("AutoRollPacks", Value, "AutoBuy")
      if SaveFile.AutoRoll then
         task.spawn(function()
            while SaveFile.AutoRoll do
               if not SaveFile.AutoBuyLocked then
                  PackReroll:FireServer()
                  Backend.trackAction("reroll", { auto_roll = true })
               end
               task.wait(math.max(0.05, SaveFile.AutoRollDelay or 1.5))
            end
         end)
      end
   end,
})

AutoBuy:CreateToggle({
   Name = "Auto Buy Selected Packs",
   CurrentValue = false,
   Flag = "AutoBuyFlag",
   Callback = function(Value)
      SaveFile.AutoBuyPacks = Value
      Backend.trackToggle("AutoBuyPacks", Value, "AutoBuy")
      if SaveFile.AutoBuyPacks then
         task.spawn(function()
            while SaveFile.AutoBuyPacks do
               local myPlot = Workspace.Map.PlotModels:FindFirstChild(Player.Name)
               local station = myPlot
                  and myPlot:FindFirstChild("Systems")
                  and myPlot.Systems:FindFirstChild("ActivePackStation")
                  and myPlot.Systems.ActivePackStation:FindFirstChild("Station")
                  and myPlot.Systems.ActivePackStation.Station:FindFirstChild("PackParts")

               if station then
                  for i = 1, 4 do
                     local packFolder = station:FindFirstChild("Pack" .. i)
                     if packFolder then
                        local slotIndex, itemRank, itemRarity = readPackSlotInfo(packFolder)
                        if slotIndex and itemRank and itemRarity then
                           if SaveFile.SelectedRanks[itemRank] then
                              if SaveFile.SelectedRarities["All"] or SaveFile.SelectedRarities[itemRarity] then
                                 SaveFile.AutoBuyLocked = true
                                 task.wait(math.max(0.1, SaveFile.AutoBuyVerifyDelay or 0.3))

                                 local verifySlot, verifyRank, verifyVariant = readPackSlotInfo(packFolder)
                                 if verifySlot == slotIndex
                                    and verifyRank == itemRank
                                    and verifyVariant == itemRarity
                                    and SaveFile.SelectedRanks[verifyRank]
                                    and (SaveFile.SelectedRarities["All"] or SaveFile.SelectedRarities[verifyVariant])
                                 then
                                    local activePack = findActivePackModel(packFolder)
                                    local priceText = activePack and getPackPriceFromBillboard(activePack) or nil
                                    PackPurchase:FireServer(slotIndex)
                                    notifyDiscordPackPurchase(verifyRank, verifyVariant, slotIndex, priceText)
                                    Rayfield:Notify({
                                       Title = "Auto Buy",
                                       Content = string.format("Bought %s · %s (slot %d)", verifyRank, verifyVariant, slotIndex),
                                       Duration = 3,
                                       Image = 4483362458,
                                    })
                                    SaveFile.AutoBuyLocked = false
                                    task.wait(0.5)
                                    break
                                 end
                                 SaveFile.AutoBuyLocked = false
                              end
                           end
                        end
                     end
                  end
               end
               task.wait(math.max(0.25, SaveFile.AutoBuyDelay or 1))
            end
         end)
      end
   end,
})

local AutoPlace = Window:CreateTab("AutoPlace", 4483362458)

AutoPlace:CreateToggle({
   Name = "Auto Open Ready Packs",
   CurrentValue = false,
   Flag = "AutoOpenFlag",
   Callback = function(Value)
      SaveFile.AutoOpenPacks = Value
      Backend.trackToggle("AutoOpenPacks", Value, "AutoPlace")
      if SaveFile.AutoOpenPacks then
         task.spawn(function()
            while SaveFile.AutoOpenPacks do
               local myPlot = Workspace.Map.PlotModels:FindFirstChild(Player.Name)
               if myPlot and myPlot:FindFirstChild("Systems") and myPlot.Systems:FindFirstChild("PlacedPacks") then
                  for _, pack in ipairs(myPlot.Systems.PlacedPacks:GetChildren()) do
                     local timerLabel = pack:FindFirstChild("PackModel")
                        and pack.PackModel:FindFirstChild("PackTimerBillboardGui")
                        and pack.PackModel.PackTimerBillboardGui:FindFirstChild("Frame")
                        and pack.PackModel.PackTimerBillboardGui.Frame:FindFirstChild("TimerLabel")

                     if timerLabel and timerLabel.Text == "Ready" then
                        CollectRemote:FireServer(pack.Name)
                        Backend.trackAction("pack_open", { pack_id = pack.Name })
                        task.wait(0.1)
                     end
                  end
               end
               task.wait(2)
            end
         end)
      end
   end,
})

local function getPlayerPlot()
   local plotFolder = Workspace:WaitForChild("Map"):WaitForChild("PlotModels")
   local userPlot = plotFolder:FindFirstChild(Player.Name)
   if userPlot then
      return userPlot:FindFirstChild("Base") or userPlot:FindFirstChildWhichIsA("BasePart")
   end
   return nil
end

local function getInventoryFromUI()
   local hotbar = Player.PlayerGui:FindFirstChild("HotbarGui")
   local mainFrame = hotbar and hotbar:FindFirstChild("MainFrame")
   local items = {}

   if not mainFrame then return items end

   for _, obj in pairs(mainFrame:GetChildren()) do
      if obj:IsA("TextButton") and obj.Visible then
         local amountLabel = obj:FindFirstChild("AmountLabel")
         local amount = 1
         if amountLabel then
            local cleanText = amountLabel.Text:gsub("%D", "")
            amount = tonumber(cleanText) or 1
         end

         local splitName = string.split(obj.Name, "_")
         if splitName[1] and splitName[2] then
            local rankName = splitName[1]
            local pType = "_" .. splitName[2]
            if pType == "_Normal" then pType = "Normal" end
            table.insert(items, {Rank = rankName, Type = pType, Quantity = amount})
         end
      end
   end

   return items
end

local function equipAndPlace(rank, pType, position)
   local character = Player.Character or Player.CharacterAdded:Wait()
   local humanoid = character:WaitForChild("Humanoid")
   local hrp = character:WaitForChild("HumanoidRootPart")

   hrp.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))
   task.wait(0.1)
   humanoid:UnequipTools()
   EquipPackTool:FireServer(rank, pType)

   local tool = nil
   local start = tick()
   while not tool and (tick() - start) < 1.2 do
      tool = character:FindFirstChildOfClass("Tool") or Player.Backpack:FindFirstChildWhichIsA("Tool")
      task.wait(0.05)
   end

   if tool then
      if tool.Parent == Player.Backpack then
         humanoid:EquipTool(tool)
      end
      tool:Activate()
      local placementRemote = ReplicatedStorage.Remotes:FindFirstChild("PlaceItem")
      if placementRemote then
         placementRemote:FireServer(tool.Name, position)
         Backend.trackAction("pack_placed", {
            rank = rank,
            variant = pType,
            tool = tool.Name,
         })
      end
   end
end

AutoPlace:CreateToggle({
   Name = "Auto Place Packs",
   CurrentValue = false,
   Flag = "AutoPlaceUI",
   Callback = function(Value)
      SaveFile.AutoPlace = Value
      Backend.trackToggle("AutoPlacePacks", Value, "AutoPlace")
      if SaveFile.AutoPlace then
         task.spawn(function()
            local plotBase = getPlayerPlot()
            if not plotBase then return end

            local size = plotBase.Size
            local margin = 4
            local minX = -(size.X / 2) + margin
            local maxX = (size.X / 2) - margin
            local minZ = -(size.Z / 2) + margin
            local maxZ = (size.Z / 2) - margin

            while SaveFile.AutoPlace do
               local visibleItems = getInventoryFromUI()
               if #visibleItems == 0 then task.wait(2) continue end

               for _, data in pairs(visibleItems) do
                  for i = 1, data.Quantity do
                     if not SaveFile.AutoPlace then break end
                     local targetPos = (plotBase.CFrame * CFrame.new(
                        math.random(minX, maxX),
                        (size.Y / 2) + 0.5,
                        math.random(minZ, maxZ)
                     )).Position
                     equipAndPlace(data.Rank, data.Type, targetPos)
                     task.wait(0.5)
                  end
                  if not SaveFile.AutoPlace then break end
               end
               task.wait(1)
            end
         end)
      end
   end,
})

local AnalyticsTab = Window:CreateTab("Analytics", 4483362458)
AnalyticsTab:CreateSection("Backend dashboard")

AnalyticsTab:CreateParagraph({
   Title = "Analytics",
   Content = "Logging to " .. DEFAULT_BACKEND_URL .. " is always on.",
})

AnalyticsTab:CreateButton({
   Name = "Test backend connection",
   Callback = function()
      local ok, err = Backend.trackSync("ping", { test = true })
      if ok then
         Rayfield:Notify({ Title = "Analytics", Content = "Backend OK - check your dashboard.", Duration = 4, Image = 4483362458 })
      else
         Rayfield:Notify({ Title = "Analytics failed", Content = tostring(err), Duration = 6, Image = 4483362458 })
      end
   end,
})

AnalyticsTab:CreateButton({
   Name = "Show dashboard login",
   Callback = function()
      local auth = loadBackendAuthFromDisk()
      if not auth or not auth.password then
         local ok, err = ensureBackendDashboardAccount(true)
         if not ok then
            Rayfield:Notify({
               Title = "Analytics",
               Content = "Could not create account: " .. tostring(err),
               Duration = 6,
               Image = 4483362458,
            })
            return
         end
         auth = loadBackendAuthFromDisk()
      end
      if not auth or not auth.password then
         return
      end
      Rayfield:Notify({
         Title = "Dashboard login",
         Content = string.format("User: %s\nPass: %s", auth.username or Player.Name, auth.password),
         Duration = 12,
         Image = 4483362458,
      })
   end,
})

AnalyticsTab:CreateButton({
   Name = "Reset dashboard password",
   Callback = function()
      if hasExecutorFilesystem() and isfile(BACKEND_AUTH_FILE) then
         pcall(function() delfile(BACKEND_AUTH_FILE) end)
      end
      local ok, err = ensureBackendDashboardAccount(true)
      if ok then
         Rayfield:Notify({ Title = "Analytics", Content = "New password saved - check notification.", Duration = 5, Image = 4483362458 })
      else
         Rayfield:Notify({ Title = "Analytics failed", Content = tostring(err), Duration = 6, Image = 4483362458 })
      end
   end,
})

AnalyticsTab:CreateParagraph({
   Title = "Dashboard login",
   Content = "Username = your Roblox name. Password is auto-generated on first enable and saved to PotatoScripts/backend_auth.json",
})

AnalyticsTab:CreateParagraph({
   Title = "Discord via server",
   Content = "Set Discord notify mode to Backend in Auto Buy tab. Purchases log here; your Coolify cron sends 30 min summaries to Discord.",
})

local ConfigTab = Window:CreateTab("Config", 4483362458)
ConfigTab:CreateSection("Config")

local ConfigStatus = ConfigTab:CreateParagraph({
   Title = "Status",
   Content = "No action taken yet.",
})

ConfigTab:CreateButton({
   Name = "Save Config",
   Callback = function()
      if not hasExecutorFilesystem() then
         ConfigStatus:Set({
            Title = "Status",
            Content = "Cannot save: executor has no filesystem APIs.",
         })
         Rayfield:Notify({
            Title = "Config",
            Content = "Your executor does not support saving (readfile/writefile).",
            Duration = 4,
            Image = 4483362458,
         })
         return
      end
      local ok, err = saveRayfieldConfigToDisk()
      if ok then
         ConfigStatus:Set({ Title = "Status", Content = "Config saved successfully!" })
         Rayfield:Notify({
            Title = "Config Saved",
            Content = "Your UI settings were written to disk.",
            Duration = 3,
            Image = 4483362458,
         })
      else
         ConfigStatus:Set({ Title = "Status", Content = "Save failed: " .. tostring(err) })
         Rayfield:Notify({
            Title = "Config Save Failed",
            Content = tostring(err),
            Duration = 5,
            Image = 4483362458,
         })
      end
   end,
})

ConfigTab:CreateButton({
   Name = "Load Config",
   Callback = function()
      local ok, err = pcall(function()
         Rayfield:LoadConfiguration()
      end)
      syncSaveFileFromRayfieldFlags()
      if ok then
         ConfigStatus:Set({ Title = "Status", Content = "Config loaded successfully!" })
         Rayfield:Notify({
            Title = "Config Loaded",
            Content = "Saved settings were applied.",
            Duration = 3,
            Image = 4483362458,
         })
      else
         ConfigStatus:Set({ Title = "Status", Content = "Load failed: " .. tostring(err) })
         Rayfield:Notify({
            Title = "Config Load Failed",
            Content = tostring(err),
            Duration = 5,
            Image = 4483362458,
         })
      end
   end,
})

ConfigTab:CreateToggle({
   Name = "Autoload Config",
   CurrentValue = isAutoloadEnabled(),
   Flag = "AutoloadConfigFlag",
   Callback = function(Value)
      Backend.trackToggle("AutoloadConfig", Value, "Config")
      if Value and not hasExecutorFilesystem() then
         Rayfield:Notify({
            Title = "Autoload",
            Content = "Your executor does not support readfile/writefile; autoload cannot be enabled.",
            Duration = 5,
            Image = 4483362458,
         })
         ConfigStatus:Set({
            Title = "Status",
            Content = "Autoload not available on this executor.",
         })
         task.defer(function()
            local f = Rayfield.Flags and Rayfield.Flags.AutoloadConfigFlag
            if f and f.Set then
               pcall(function()
                  f:Set(false)
               end)
            end
         end)
         return
      end
      local okFs, fsErr = setAutoload(Value)
      if not okFs then
         Rayfield:Notify({
            Title = "Autoload",
            Content = tostring(fsErr or "Could not persist autoload on disk."),
            Duration = 6,
            Image = 4483362458,
         })
         ConfigStatus:Set({
            Title = "Status",
            Content = "Autoload not saved — " .. tostring(fsErr),
         })
         task.defer(function()
            local f = Rayfield.Flags and Rayfield.Flags.AutoloadConfigFlag
            if f and f.Set then
               pcall(function()
                  f:Set(false)
               end)
            end
         end)
         return
      end

      if Value then
         local saved, sErr = saveRayfieldConfigToDisk()
         if not saved then
            Rayfield:Notify({
               Title = "Autoload",
               Content = "Autoload saved, but config file failed (" .. tostring(sErr) .. "). Click Save Config once.",
               Duration = 8,
               Image = 4483362458,
            })
            ConfigStatus:Set({
               Title = "Status",
               Content = "Autoload ON — click Save Config to write PotatoScripts/"
                  .. RAYFIELD_CONFIG_NAME
                  .. ".rfld",
            })
         else
            ConfigStatus:Set({
               Title = "Status",
               Content = "Autoload ON — folder "
                  .. RAYFIELD_CONFIG_FOLDER
                  .. " verified. Loads ~5–6s after inject.",
            })
         end
      else
         ConfigStatus:Set({ Title = "Status", Content = "Autoload disabled." })
      end
   end,
})

ConfigTab:CreateParagraph({
   Title = "How it works",
   Content = "Autoload saves a flag inside PotatoScripts/ (Delta-friendly path). Turning Autoload ON also tries to save your hub file there. Expect settings to restore ~5–6s after inject (matches Rayfield’s own load timing). Rayfield autosaves toggle changes whenever possible.",
})

local CreditsTab = Window:CreateTab("Credits", 4483362458)
CreditsTab:CreateSection("Credits")
CreditsTab:CreateParagraph({Title = "Note:", Content = "Screw The Skids, We post Open Sourced."})
CreditsTab:CreateLabel("Developer: PotatoIsCool", 4483362458, Color3.fromRGB(255, 255, 255), false)

local AntiAfkEnabled = false
local AntiAfkThread

CreditsTab:CreateToggle({
   Name = "Anti-AFK",
   CurrentValue = false,
   Flag = "AntiAfkFlag",
   Callback = function(Value)
      AntiAfkEnabled = Value

      if AntiAfkThread then
         task.cancel(AntiAfkThread)
         AntiAfkThread = nil
      end

      if AntiAfkEnabled then
         AntiAfkThread = task.spawn(function()
            while AntiAfkEnabled do
               task.wait(300)
               VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game)
               task.wait(0.01)
               VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
            end
         end)
         Rayfield:Notify({
            Title = "Anti-AFK Active",
            Content = "Spoofing + Movement (W) active.",
            Duration = 3,
            Image = 4483362458,
         })
      else
         VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
         Rayfield:Notify({
            Title = "Anti-AFK Disabled",
            Content = "All anti-afk routines stopped.",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

local Themes = {
   ["Default"] = "Default",
   ["Amber Glow"] = "AmberGlow",
   ["Amethyst"] = "Amethyst",
   ["Bloom"] = "Bloom",
   ["Dark Blue"] = "DarkBlue",
   ["Green"] = "Green",
   ["Light"] = "Light",
   ["Ocean"] = "Ocean",
   ["Serenity"] = "Serenity"
}

local ThemeList = {}
for name in pairs(Themes) do
   table.insert(ThemeList, name)
end

CreditsTab:CreateDropdown({
   Name = "Select UI Theme",
   Options = ThemeList,
   CurrentOption = {"Default"},
   MultipleOptions = false,
   Flag = "ThemeSelector",
   Callback = function(Option)
      local selectedName = Option[1]
      local themeId = Themes[selectedName]
      if themeId then
         Window.ModifyTheme(themeId)
         SaveFile.CurrentTheme = themeId
      end
   end,
})

CreditsTab:CreateInput({
   Name = "Suggested Features",
   PlaceholderText = "Type your idea and press Enter...",
   RemoveTextAfterFocusLost = true,
   Callback = function(Text)
      local trimmed = trimStoredText(tostring(Text or ""))
      if trimmed == "" then
         return
      end
      local ok, err = Backend.trackSync("suggestion", {
         content = trimmed:sub(1, 500),
      })
      if ok then
         Rayfield:Notify({
            Title = "Suggestion sent",
            Content = "Saved to your analytics site — check the Suggestions panel.",
            Duration = 5,
            Image = 4483362458,
         })
      else
         Rayfield:Notify({
            Title = "Suggestion failed",
            Content = tostring(err or "unknown error"),
            Duration = 6,
            Image = 4483362458,
         })
      end
   end,
})

CreditsTab:CreateButton({
   Name = "Destroy UI",
   Callback = function()
      SaveFile.AutoCollect = false
      SaveFile.AutoRoll = false
      SaveFile.AutoOpenPacks = false
      SaveFile.AutoBuyPacks = false
      SaveFile.AutoPlace = false
      SaveFile.AutoGradeToken = false
      SaveFile.AutoServerhop = false
      if #DiscordBuyBuffer.entries > 0 then
         flushDiscordBuySummary("script closed")
      end
      Backend.stopHeartbeat()
      Backend.endSession()
      _G.WaifuWindow = nil
      Rayfield:Destroy()
   end,
})

-- Rayfield waits ~4s before its own LoadConfiguration; wait longer so loaders run after globals are ready,
-- then re-apply hubs + Lua-side SaveFile helpers (helps Delta / slow injectors).
if isAutoloadEnabled() then
   task.spawn(function()
      task.wait(5.75)
      if not isAutoloadEnabled() then
         return
      end
      if not hasExecutorFilesystem() or not isfile(RAYFIELD_CONFIG_PATH) then
         Rayfield:Notify({
            Title = "Autoload",
            Content = "No "
               .. RAYFIELD_CONFIG_PATH
               .. " yet — open Config and click Save Config once.",
            Duration = 12,
            Image = 4483362458,
         })
         ConfigStatus:Set({
            Title = "Status",
            Content = "Missing " .. RAYFIELD_CONFIG_PATH,
         })
         return
      end
      local ok, err = pcall(function()
         Rayfield:LoadConfiguration()
      end)
      syncSaveFileFromRayfieldFlags()
      if ok then
         ConfigStatus:Set({ Title = "Status", Content = "Config autoload reapplied (~5–6s after inject)." })
      else
         ConfigStatus:Set({
            Title = "Status",
            Content = "Autoload reapplied failed: " .. tostring(err),
         })
         Rayfield:Notify({
            Title = "Autoload",
            Content = tostring(err),
            Duration = 6,
            Image = 4483362458,
         })
      end
   end)
end

local function startBackendSession()
   if not Backend.isReady() then
      return
   end
   ensureBackendDashboardAccount(false)
   Backend.startSession()
   Backend.startHeartbeat()
end

pcall(startBackendSession)