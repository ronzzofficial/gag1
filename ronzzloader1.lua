--==================================================
-- HOLY LOADER v2
-- Server-auth key gate runs before HolyV3.lua is fetched/executed.
-- Supports:
-- - Backend key verification
-- - 10-account key plans
-- - Saved key autoload
-- - Feature flags
-- - Usage tracker heartbeat
--==================================================

local HttpService =
    game:GetService("HttpService")

local Players =
    game:GetService("Players")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer =
    Players.LocalPlayer
    or Players.PlayerAdded:Wait()

--==================================================
-- MAIN SCRIPT URL
--==================================================

local MAIN_URL =
    "https://raw.githubusercontent.com/ronzzofficial/gag1/refs/heads/main/ronzzholy1.lua?v="
    .. tostring(os.time())

--==================================================
-- LOADER AUTH CONFIG
--==================================================

local HOLY_LOADER_KEY_STATE = {
    Enabled = true,

    SaveFile = "HolyV2/holy_access_key.txt",

    -- Paste your NEW auth Google Apps Script Web App URL here.
    -- This is NOT the usage tracker URL.
    AuthURL = "https://script.google.com/macros/s/AKfycbz940kY8xU0x5NiVmX33rcmT5EPRiTq7WGzZpEx5_17jJ98HWmoQwHmPfmHgp0Ynv9rTg/exec",

    -- Must match the secret inside your auth Apps Script.
    Secret = "HOLY-AUTH-BEN-CHANGE-THIS",

    Accepted = false,
    Owner = "Unknown",
    CurrentKey = "",

    LastAuth = nil,
}

--==================================================
-- SMALL HELPERS
--==================================================

local function NormalizeHolyAccessKey(value)

    return tostring(value or "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local function EnsureHolyFolder()

    if makefolder
    and not isfolder("HolyV2") then

        pcall(function()
            makefolder("HolyV2")
        end)
    end
end

local function SaveHolyAccessKey(key)

    key =
        NormalizeHolyAccessKey(key)

    if key == ""
    or not writefile then
        return false
    end

    local ok =
        pcall(function()
            EnsureHolyFolder()

            writefile(
                HOLY_LOADER_KEY_STATE.SaveFile,
                key
            )
        end)

    return ok
end

local function ReadSavedHolyAccessKey()

    if not isfile
    or not readfile then
        return ""
    end

    local filePath =
        HOLY_LOADER_KEY_STATE.SaveFile

    local ok, result =
        pcall(function()

            if not isfile(filePath) then
                return ""
            end

            return readfile(filePath)
        end)

    if not ok then
        return ""
    end

    return NormalizeHolyAccessKey(result)
end

local function ResolveHolyRequestFunction()

    return
        (
            syn
            and syn.request
        )
        or http_request
        or request
end

local function DecodeHolyJson(body)

    if type(body) ~= "string"
    or body == "" then
        return nil, "Empty response."
    end

    local ok, decoded =
        pcall(function()
            return HttpService:JSONDecode(body)
        end)

    if not ok
    or type(decoded) ~= "table" then
        return nil, "Invalid JSON response."
    end

    return decoded, nil
end

--==================================================
-- SERVER AUTH REQUEST
--==================================================

local function UrlEncode(value)

    value =
        tostring(value or "")

    return value:gsub(
        "([^%w%-%_%.%~])",
        function(char)
            return string.format(
                "%%%02X",
                string.byte(char)
            )
        end
    )
end

local function RequestHolyKeyAuth(key)

    key =
        NormalizeHolyAccessKey(key)

    if key == "" then
        return false, "Enter a key."
    end

    local authURL =
        tostring(HOLY_LOADER_KEY_STATE.AuthURL or "")

    if authURL == ""
    or authURL == "PASTE_YOUR_AUTH_WEB_APP_URL_HERE" then
        return false, "Auth URL is not configured."
    end

    local params = {
        "secret=" .. UrlEncode(HOLY_LOADER_KEY_STATE.Secret),
        "action=verify",
        "key=" .. UrlEncode(key),
        "userId=" .. UrlEncode(LocalPlayer.UserId),
        "username=" .. UrlEncode(LocalPlayer.Name),
        "displayName=" .. UrlEncode(LocalPlayer.DisplayName),
        "placeId=" .. UrlEncode(game.PlaceId),
        "jobId=" .. UrlEncode(game.JobId),
        "version=holy-loader-v2-get",
    }

    local separator =
        authURL:find("?", 1, true)
        and "&"
        or "?"

    local finalURL =
        authURL
        .. separator
        .. table.concat(params, "&")

    local ok, body =
        pcall(function()
            return game:HttpGet(finalURL, true)
        end)

    if not ok then
        return false, "Auth GET failed: " .. tostring(body)
    end

    local decoded, decodeErr =
        DecodeHolyJson(body)

    if not decoded then
        return false, tostring(decodeErr)
            .. " | Body: "
            .. tostring(body):sub(1, 150)
    end

    if decoded.allowed ~= true then

        return false,
            tostring(
                decoded.message
                or decoded.reason
                or decoded.error
                or "Access denied."
            )
    end

    HOLY_LOADER_KEY_STATE.LastAuth =
        decoded

    return true, decoded
end

local function ValidateHolyAccessKey(key)

    key =
        NormalizeHolyAccessKey(key)

    local allowed, result =
        RequestHolyKeyAuth(key)

    if allowed ~= true then
        return false, tostring(result or "Invalid key.")
    end

    local auth =
        result

    local owner =
        tostring(
            auth.owner
            or auth.discord
            or auth.username
            or "Premium User"
        )

    HOLY_LOADER_KEY_STATE.Accepted =
        true

    HOLY_LOADER_KEY_STATE.Owner =
        owner

    HOLY_LOADER_KEY_STATE.CurrentKey =
        key

    HOLY_LOADER_KEY_STATE.LastAuth =
        auth

    SaveHolyAccessKey(key)

    return true, owner
end

--==================================================
-- KEY UI
--==================================================

local function ResolveHolyUIParent()

    local ok, hui =
        pcall(function()

            if type(gethui) == "function" then
                return gethui()
            end

            return nil
        end)

    if ok
    and hui then
        return hui
    end

    return LocalPlayer:WaitForChild(
        "PlayerGui",
        10
    )
end

local function CreateHolyLoaderKeyUI()

    local parent =
        ResolveHolyUIParent()

    if not parent then
        warn("[HOLY LOADER] No UI parent")
        return false
    end

    local existing =
        parent:FindFirstChild("HolyLoaderKeyUI")

    if existing then
        existing:Destroy()
    end

    local screenGui =
        Instance.new("ScreenGui")

    screenGui.Name =
        "HolyLoaderKeyUI"

    screenGui.ResetOnSpawn =
        false

    screenGui.IgnoreGuiInset =
        true

    screenGui.DisplayOrder =
        100000

    screenGui.Parent =
        parent

    local dim =
        Instance.new("Frame")

    dim.Name =
        "Dim"

    dim.BackgroundColor3 =
        Color3.fromRGB(0, 0, 0)

    dim.BackgroundTransparency =
        0.35

    dim.Size =
        UDim2.fromScale(1, 1)

    dim.Parent =
        screenGui

    local frame =
        Instance.new("Frame")

    frame.Name =
        "Main"

    frame.AnchorPoint =
        Vector2.new(0.5, 0.5)

    frame.Position =
        UDim2.fromScale(0.5, 0.5)

    frame.Size =
        UDim2.fromOffset(350, 225)

    frame.BackgroundColor3 =
        Color3.fromRGB(12, 12, 18)

    frame.BorderSizePixel =
        0

    frame.Parent =
        dim

    local corner =
        Instance.new("UICorner")

    corner.CornerRadius =
        UDim.new(0, 8)

    corner.Parent =
        frame

    local stroke =
        Instance.new("UIStroke")

    stroke.Color =
        Color3.fromRGB(110, 80, 180)

    stroke.Thickness =
        1

    stroke.Transparency =
        0.1

    stroke.Parent =
        frame

    local title =
        Instance.new("TextLabel")

    title.Name =
        "Title"

    title.BackgroundTransparency =
        1

    title.Position =
        UDim2.fromOffset(0, 15)

    title.Size =
        UDim2.new(1, 0, 0, 30)

    title.Font =
        Enum.Font.GothamBlack

    title.Text =
        "HOLY"

    title.TextColor3 =
        Color3.fromRGB(255, 235, 170)

    title.TextSize =
        23

    title.TextStrokeTransparency =
        0.65

    title.Parent =
        frame

    local subtitle =
        Instance.new("TextLabel")

    subtitle.Name =
        "Subtitle"

    subtitle.BackgroundTransparency =
        1

    subtitle.Position =
        UDim2.fromOffset(0, 46)

    subtitle.Size =
        UDim2.new(1, 0, 0, 22)

    subtitle.Font =
        Enum.Font.Gotham

    subtitle.Text =
        "Enter your access key"

    subtitle.TextColor3 =
        Color3.fromRGB(195, 190, 215)

    subtitle.TextSize =
        13

    subtitle.Parent =
        frame

    local input =
        Instance.new("TextBox")

    input.Name =
        "KeyInput"

    input.Position =
        UDim2.fromOffset(30, 84)

    input.Size =
        UDim2.new(1, -60, 0, 36)

    input.BackgroundColor3 =
        Color3.fromRGB(22, 22, 32)

    input.BorderSizePixel =
        0

    input.ClearTextOnFocus =
        false

    input.Font =
        Enum.Font.Gotham

    input.PlaceholderText =
        "HOLY-XXXX-XXXX"

    input.PlaceholderColor3 =
        Color3.fromRGB(110, 110, 130)

    input.Text =
        ReadSavedHolyAccessKey()

    input.TextColor3 =
        Color3.fromRGB(240, 240, 255)

    input.TextSize =
        14

    input.Parent =
        frame

    local inputCorner =
        Instance.new("UICorner")

    inputCorner.CornerRadius =
        UDim.new(0, 6)

    inputCorner.Parent =
        input

    local inputStroke =
        Instance.new("UIStroke")

    inputStroke.Color =
        Color3.fromRGB(65, 55, 95)

    inputStroke.Thickness =
        1

    inputStroke.Parent =
        input

    local status =
        Instance.new("TextLabel")

    status.Name =
        "Status"

    status.BackgroundTransparency =
        1

    status.Position =
        UDim2.fromOffset(30, 126)

    status.Size =
        UDim2.new(1, -60, 0, 34)

    status.Font =
        Enum.Font.Gotham

    status.Text =
        ""

    status.TextColor3 =
        Color3.fromRGB(255, 95, 120)

    status.TextSize =
        12

    status.TextWrapped =
        true

    status.TextXAlignment =
        Enum.TextXAlignment.Left

    status.TextYAlignment =
        Enum.TextYAlignment.Top

    status.Parent =
        frame

    local verify =
        Instance.new("TextButton")

    verify.Name =
        "Verify"

    verify.Position =
        UDim2.fromOffset(30, 170)

    verify.Size =
        UDim2.new(0.5, -35, 0, 34)

    verify.BackgroundColor3 =
        Color3.fromRGB(75, 45, 135)

    verify.BorderSizePixel =
        0

    verify.AutoButtonColor =
        true

    verify.Font =
        Enum.Font.GothamBold

    verify.Text =
        "Verify"

    verify.TextColor3 =
        Color3.fromRGB(255, 255, 255)

    verify.TextSize =
        14

    verify.Parent =
        frame

    local verifyCorner =
        Instance.new("UICorner")

    verifyCorner.CornerRadius =
        UDim.new(0, 6)

    verifyCorner.Parent =
        verify

    local close =
        Instance.new("TextButton")

    close.Name =
        "Close"

    close.Position =
        UDim2.new(0.5, 5, 0, 170)

    close.Size =
        UDim2.new(0.5, -35, 0, 34)

    close.BackgroundColor3 =
        Color3.fromRGB(20, 20, 28)

    close.BorderSizePixel =
        0

    close.AutoButtonColor =
        true

    close.Font =
        Enum.Font.GothamBold

    close.Text =
        "Close UI"

    close.TextColor3 =
        Color3.fromRGB(185, 185, 205)

    close.TextSize =
        14

    close.Parent =
        frame

    local closeCorner =
        Instance.new("UICorner")

    closeCorner.CornerRadius =
        UDim.new(0, 6)

    closeCorner.Parent =
        close

    local finished =
        false

    local accepted =
        false

    local verifying =
        false

    local function TryVerify()

        if verifying then
            return
        end

        verifying =
            true

        verify.Text =
            "Checking..."

        status.Text =
            "Checking key..."

        status.TextColor3 =
            Color3.fromRGB(235, 215, 120)

        local ok, result =
            ValidateHolyAccessKey(
                input.Text
            )

        if ok then

            local auth =
                HOLY_LOADER_KEY_STATE.LastAuth
                or {}

            local slotsText =
                tostring(auth.slotsUsed or "?")
                .. "/"
                .. tostring(auth.maxAccounts or "?")

            status.Text =
                "Access granted • "
                .. tostring(result)
                .. " • "
                .. tostring(auth.plan or "premium")
                .. " • "
                .. slotsText
                .. " slots"

            status.TextColor3 =
                Color3.fromRGB(90, 255, 150)

            accepted =
                true

            task.wait(0.35)

            finished =
                true

            screenGui:Destroy()

            return
        end

        status.Text =
            tostring(result or "Invalid key.")

        status.TextColor3 =
            Color3.fromRGB(255, 95, 120)

        verify.Text =
            "Verify"

        verifying =
            false
    end

    verify.MouseButton1Click:Connect(TryVerify)

    input.FocusLost:Connect(function(enterPressed)

        if enterPressed then
            TryVerify()
        end
    end)

    close.MouseButton1Click:Connect(function()

        finished =
            true

        accepted =
            false

        screenGui:Destroy()
    end)

    input:CaptureFocus()

    while not finished do
        task.wait(0.05)
    end

    return accepted
end

--==================================================
-- KEY GATE
--==================================================

local function RunHolyLoaderKeyGate()

    if HOLY_LOADER_KEY_STATE.Enabled ~= true then
        return true
    end

    local savedKey =
        ReadSavedHolyAccessKey()

    if savedKey ~= "" then

        local valid, owner =
            ValidateHolyAccessKey(
                savedKey
            )

        if valid then

            local auth =
                HOLY_LOADER_KEY_STATE.LastAuth
                or {}

            print(
                "[HOLY LOADER] Saved key accepted:",
                tostring(owner),
                "| Plan:",
                tostring(auth.plan or "unknown"),
                "| Slots:",
                tostring(auth.slotsUsed or "?")
                    .. "/"
                    .. tostring(auth.maxAccounts or "?")
            )

            return true
        end
    end

    return CreateHolyLoaderKeyUI()
end

if not RunHolyLoaderKeyGate() then
    warn("[HOLY LOADER] Access denied. Loader stopped.")
    return
end

--==================================================
-- EXPORT AUTH TO MAIN SCRIPT
--==================================================

local root =
    type(getgenv) == "function"
    and getgenv()
    or _G

local auth =
    HOLY_LOADER_KEY_STATE.LastAuth
    or {}

root.HOLY_LOADER_AUTHORIZED =
    true

root.HOLY_LOADER_OWNER =
    HOLY_LOADER_KEY_STATE.Owner

root.HOLY_LOADER_KEY =
    HOLY_LOADER_KEY_STATE.CurrentKey

root.HOLY_LOADER_PLAN =
    tostring(auth.plan or "premium_30d")

root.HOLY_LOADER_EXPIRES_AT =
    tonumber(auth.expiresAt) or 0

root.HOLY_LOADER_MAX_ACCOUNTS =
    tonumber(auth.maxAccounts) or 1

root.HOLY_LOADER_SLOTS_USED =
    tonumber(auth.slotsUsed) or 1

root.HOLY_LOADER_FEATURES =
    type(auth.features) == "table"
    and auth.features
    or {
        sniper = true,
        marketTracker = true,
        ageBreaker = true,
        webhooks = true,
        boothTools = true,
    }

print(
    "[HOLY LOADER] Access granted:",
    tostring(HOLY_LOADER_KEY_STATE.Owner),
    "| Plan:",
    tostring(root.HOLY_LOADER_PLAN),
    "| Slots:",
    tostring(root.HOLY_LOADER_SLOTS_USED)
        .. "/"
        .. tostring(root.HOLY_LOADER_MAX_ACCOUNTS)
)

--==================================================
-- HOLY USAGE TRACKER
-- Tracks validated loader users through Google Apps Script.
--==================================================

local HOLY_USAGE_TRACKER = {
    Enabled = true,

    URL = "https://script.google.com/macros/s/AKfycbz_Vz9IPWZ0xJxn-LIPeyWEzT896aDhEE4XxWcGXKFRBFnIrM59JleiV41BZ0kL8EOp/exec",

    -- Must match the SECRET in your usage tracker Apps Script.
    Secret = "HOLY-TRACK-BEN-94582",

    Version = "v3.4.5",

    SessionId =
        tostring(game.PlaceId)
        .. "_"
        .. tostring(game.JobId)
        .. "_"
        .. tostring(LocalPlayer.UserId)
        .. "_"
        .. tostring(os.time())
        .. "_"
        .. tostring(math.random(100000, 999999)),

    HeartbeatInterval = 45,
}

local function SendHolyUsageHeartbeat(action)

    if HOLY_USAGE_TRACKER.Enabled ~= true then
        return false
    end

    local url =
        tostring(HOLY_USAGE_TRACKER.URL or "")

    if url == ""
    or url == "PASTE_YOUR_WEB_APP_URL_HERE" then

        warn("[HOLY TRACKER] Missing tracker URL")

        return false
    end

    local requestFunction =
        ResolveHolyRequestFunction()

    if type(requestFunction) ~= "function" then

        warn("[HOLY TRACKER] No HTTP request function found")

        return false
    end

    local payload = {
        secret =
            tostring(HOLY_USAGE_TRACKER.Secret),

        action =
            tostring(action or "heartbeat"),

        sessionId =
            tostring(HOLY_USAGE_TRACKER.SessionId),

        userId =
            tostring(LocalPlayer.UserId),

        username =
            tostring(LocalPlayer.Name),

        displayName =
            tostring(LocalPlayer.DisplayName),

        owner =
            tostring(HOLY_LOADER_KEY_STATE.Owner or "Unknown"),

        key =
            tostring(HOLY_LOADER_KEY_STATE.CurrentKey or ""),

        plan =
            tostring(root.HOLY_LOADER_PLAN or "unknown"),

        slotsUsed =
            tostring(root.HOLY_LOADER_SLOTS_USED or ""),

        maxAccounts =
            tostring(root.HOLY_LOADER_MAX_ACCOUNTS or ""),

        version =
            tostring(HOLY_USAGE_TRACKER.Version),

        placeId =
            tostring(game.PlaceId),

        jobId =
            tostring(game.JobId),
    }

    local encoded =
        HttpService:JSONEncode(payload)

    local ok, result =
        pcall(function()

            return requestFunction({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                },
                Body = encoded,
            })
        end)

    if not ok then

        warn(
            "[HOLY TRACKER] Heartbeat failed:",
            tostring(result)
        )

        return false
    end

    local statusCode =
        result
        and (
            result.StatusCode
            or result.status_code
            or result.Status
        )

    local body =
        result
        and (
            result.Body
            or result.body
            or result.ResponseBody
        )

    print(
        "[HOLY TRACKER] Sent:",
        tostring(action or "heartbeat"),
        "| Status:",
        tostring(statusCode or "unknown"),
        "| Body:",
        tostring(body or "no body")
    )

    return true
end

local function StartHolyUsageTracker()

    task.spawn(function()

        task.wait(2)

        SendHolyUsageHeartbeat("start")

        while true do

            task.wait(
                math.max(
                    15,
                    tonumber(HOLY_USAGE_TRACKER.HeartbeatInterval)
                    or 45
                )
            )

            SendHolyUsageHeartbeat("heartbeat")
        end
    end)
end

StartHolyUsageTracker()

--==================================================
-- FETCH + RUN MAIN SCRIPT
--==================================================

print("[HOLY LOADER] Fetching:", MAIN_URL)

local ok, source =
    pcall(function()
        return game:HttpGet(MAIN_URL, true)
    end)

if not ok then
    error("[HOLY LOADER] HttpGet failed: " .. tostring(source))
end

if type(source) ~= "string" then
    error("[HOLY LOADER] Source is not string: " .. typeof(source))
end

print("[HOLY LOADER] Loaded bytes:", #source)
print("[HOLY LOADER] First 80 chars:", string.sub(source, 1, 80))

local fn, compileErr =
    loadstring(source)

if not fn then
    error("[HOLY LOADER] Compile failed: " .. tostring(compileErr))
end

print("[HOLY LOADER] Compile OK, running...")

local okRun, runtimeErr =
    xpcall(fn, function(err)
        return tostring(err) .. "\n" .. debug.traceback()
    end)

if not okRun then
    error("[HOLY LOADER] Runtime failed:\n" .. tostring(runtimeErr))
end

print("[HOLY LOADER] Runtime OK")
