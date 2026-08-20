--==================================================
-- ZANJI PUBLIC LOADER
-- Put this file in your public GitHub repository.
-- The actual ZANJI source is never stored in this file.
--==================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer =
    Players.LocalPlayer
    or Players.PlayerAdded:Wait()

--==================================================
-- LEGACY ALLOWED PLACE IDS
--==================================================

local LEGACY_ALLOWED_PLACE_IDS = {
    [126884695634066] =
        true,

    [129954712878723] =
        true,
}

--==================================================
-- ENVIRONMENT
--==================================================

local function GetEnvironment()
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)

        if ok and type(env) == "table" then
            return env
        end
    end

    return _G
end

local Environment = GetEnvironment()

--==================================================
-- EXECUTE ONCE PER JOB
--==================================================

local existingLoaderRuntime =
    Environment.ZANJI_LOADER_RUNTIME

if type(existingLoaderRuntime) == "table"
and existingLoaderRuntime.JobId == game.JobId
and (
    existingLoaderRuntime.Loading == true
    or existingLoaderRuntime.Loaded == true
) then

    warn(
        "[ZANJI]",
        "ZANJI is already loading or loaded.",
        "Channel:",
        tostring(
            existingLoaderRuntime.Channel
            or "unknown"
        )
    )

    return
end

Environment.ZANJI_LOADER_RUNTIME = {
    JobId = game.JobId,
    Loading = true,
    Loaded = false,
    Channel = "public",
}

local API =
    "https://zanji-license-api.ronzz191002.workers.dev"

local PRODUCT =
    "zanji_v2"

local SOURCE_ROUTE =
    "/v1/source/zanji_v2"

local VALIDATE_ROUTE =
    "/v1/license/validate"

local KEY_FILE =
    "ZanjiHub_Key.txt"

--==================================================
-- CLEAN
--==================================================

local function Clean(value)
    return tostring(value or "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

--==================================================
-- REQUEST
--==================================================

local function GetRequestFunction()

    if type(syn) == "table"
    and type(syn.request) == "function" then

        return syn.request
    end

    if type(http_request) == "function" then
        return http_request
    end

    if type(request) == "function" then
        return request
    end

    if type(fluxus) == "table"
    and type(fluxus.request) == "function" then

        return fluxus.request
    end

    if type(Environment.request) == "function" then
        return Environment.request
    end

    if type(Environment.http_request) == "function" then
        return Environment.http_request
    end

    return nil
end

local function SendRequest(options)

    local requestFunction =
        GetRequestFunction()

    if type(requestFunction) ~= "function" then

        return nil,
            "Your executor does not support request/http_request."
    end

    local ok, response =
        pcall(
            requestFunction,
            options
        )

    if not ok then
        return nil, tostring(response)
    end

    if type(response) == "string" then

        return {
            Success = true,
            StatusCode = 200,
            Body = response,
        }
    end

    if type(response) ~= "table" then

        return nil,
            "Executor returned an invalid HTTP response."
    end

    local statusCode =
        tonumber(
            response.StatusCode
            or response.Status
            or response.status_code
            or response.status
            or 0
        ) or 0

    local success =
        response.Success

    if success == nil then

        success =
            statusCode >= 200
            and statusCode < 300
    end

    return {
        Success = success == true,
        StatusCode = statusCode,

        Body =
            tostring(
                response.Body
                or response.body
                or response.ResponseBody
                or response.responseBody
                or ""
            ),
    }
end

--==================================================
-- JSON
--==================================================

local function DecodeJson(body)

    if type(body) ~= "string"
    or body == "" then

        return nil
    end

    local ok, result =
        pcall(function()

            return HttpService:
                JSONDecode(body)
        end)

    if ok
    and type(result) == "table" then

        return result
    end

    return nil
end

--==================================================
-- KEY FILE
--==================================================

local function ReadSavedKey()

    if type(readfile) ~= "function" then
        return ""
    end

    local ok, value =
        pcall(
            readfile,
            KEY_FILE
        )

    if not ok then
        return ""
    end

    return Clean(value):upper()
end

local function SaveKey(key)

    if type(writefile) ~= "function" then
        return false
    end

    local ok =
        pcall(
            writefile,
            KEY_FILE,
            Clean(key):upper()
        )

    return ok
end

--==================================================
-- API ERROR
--==================================================

local function FormatApiError(
    decoded,
    fallback
)

    if type(decoded) ~= "table" then

        return tostring(
            fallback
            or "Unknown API error."
        )
    end

    local messages = {

        invalid_key =
            "The ZANJI key is invalid.",

        key_not_found =
            "The ZANJI key is invalid.",

        missing_key =
            "Enter your ZANJI key.",

        license_expired =
            "This ZANJI key has expired.",

        license_revoked =
            "This ZANJI key has been revoked.",

        license_paused =
            "This ZANJI key is paused.",

        license_not_found =
            "This ZANJI license no longer exists.",

        account_limit_reached =
            "This key has no Roblox account slots remaining.",

        account_not_linked =
            "This Roblox account is not linked to this key.",

        product_not_allowed =
            "This key cannot access ZanjiHub.",

        invalid_access_token =
            "The temporary access token was rejected.",

        access_token_expired =
            "The temporary access token expired.",

        unsupported_place =
            "ZANJI does not support this Roblox experience.",

        source_not_configured =
            "The private ZANJI source is not configured.",

        source_fetch_failed =
            "The private ZANJI source could not be downloaded.",

        internal_server_error =
            "The ZANJI license service had a server error.",
    }

    local code =
        Clean(
            decoded.error
            or decoded.code
        ):lower()

    return
        messages[code]
        or Clean(decoded.message)
        or code
        or tostring(
            fallback
            or "Unknown API error."
        )
end

--==================================================
-- ACTIVATE KEY
--==================================================

local function ActivateKey(key)

    key =
        Clean(key):upper()

    if key == "" then

        return nil,
            "Enter your ZANJI Premium key."
    end

    local body =
        HttpService:JSONEncode({

            Key = key,

            Product = PRODUCT,

            RobloxUserId =
                tonumber(
                    LocalPlayer.UserId
                ) or 0,

            RobloxUsername =
                tostring(
                    LocalPlayer.Name
                ),

            PlaceId =
                tostring(
                    game.PlaceId
                ),

            UniverseId =
                tostring(
                    game.GameId
                ),
        })

    local response, requestError =
        SendRequest({

            Url =
                API
                .. "/v1/license/activate",

            Method = "POST",

            Headers = {

                ["Content-Type"] =
                    "application/json",

                ["Accept"] =
                    "application/json",

                ["Accept-Encoding"] =
                    "identity",

                ["Cache-Control"] =
                    "no-cache",
            },

            Body = body,
        })

    if not response then

        return nil,
            "Activation request failed: "
            .. tostring(requestError)
    end

    local decoded =
        DecodeJson(
            response.Body
        )

    if not response.Success
    or type(decoded) ~= "table"
    or decoded.ok ~= true then

        return nil,
            FormatApiError(
                decoded,

                "Activation failed with HTTP "
                .. tostring(
                    response.StatusCode
                )
            )
    end

    local token =
        Clean(
            decoded.accessToken
            or decoded.access_token
            or decoded.token
        )

    if token == "" then

        return nil,
            "The API did not return an access token."
    end

    return {
        Token = token,
        Activation = decoded,
    }
end

--==================================================
-- DOWNLOAD SOURCE
--==================================================

local function DownloadSource(session)

    local response, requestError =
        SendRequest({

            Url =
                API
                .. SOURCE_ROUTE,

            Method = "GET",

            Headers = {

                ["Authorization"] =
                    "Bearer "
                    .. tostring(
                        session.Token
                    ),

                ["Accept"] =
                    "text/plain",

                ["Accept-Encoding"] =
                    "identity",

                ["Cache-Control"] =
                    "no-cache",
            },
        })

    if not response then

        return nil,
            "Source request failed: "
            .. tostring(requestError)
    end

    if not response.Success then

        return nil,
            FormatApiError(
                DecodeJson(
                    response.Body
                ),

                "Source request failed with HTTP "
                .. tostring(
                    response.StatusCode
                )
            )
    end

    local source =
        tostring(
            response.Body
            or ""
        )

    if source == "" then

        return nil,
            "The private source was empty."
    end

    local marker =
        "-- ZANJI PRIVATE SOURCE"

    if source:sub(
        1,
        #marker
    ) ~= marker then

        return nil,
            "The private source marker is missing."
    end

    local endMarker =
        "-- ZANJI_PRIVATE_END_MARKER"

    if source:find(
        endMarker,
        1,
        true
    ) == nil then

        return nil,
            "The private source is incomplete."
    end

    return source
end

--==================================================
-- INSTALL AUTH
--==================================================

local function InstallAuth(session)

    local activation =
        session.Activation
        or {}

    local features = {}

    if type(
        activation.features
    ) == "table" then

        for name, enabled
        in pairs(
            activation.features
        ) do

            features[name] =
                enabled == true
        end
    end

    Environment.ZANJI_LOADER_AUTHORIZED =
        true

    Environment.ZANJI_LOADER_OWNER =
        tostring(
            activation.owner
            or "License"
        )

    Environment.ZANJI_LOADER_PLAN =
        tostring(
            activation.role
            or "premium"
        )

    Environment.ZANJI_LOADER_EXPIRES_AT =
        tonumber(
            activation.expiresAt
            or 0
        ) or 0

    Environment.ZANJI_LOADER_MAX_ACCOUNTS =
        tonumber(
            activation.maxAccounts
            or 1
        ) or 1

    Environment.ZANJI_LOADER_SLOTS_USED =
        tonumber(
            activation.accountsUsed
            or 1
        ) or 1

    Environment.ZANJI_LOADER_FEATURES =
        features

    local authSession = {
        Token =
            tostring(
                session.Token
                or ""
            ),

        API =
            API,

        ValidateRoute =
            VALIDATE_ROUTE,

        Product =
            PRODUCT,

        RobloxUserId =
            tonumber(
                LocalPlayer.UserId
            ) or 0,

        JobId =
            tostring(
                game.JobId
            ),

        Valid =
            true,

        LeaseSeconds =
            tonumber(
                activation.leaseSeconds
                or 180
            ) or 180,

        LastValidatedAt =
            os.time(),
    }

    Environment.ZANJI_AUTH_SESSION =
        authSession

    _G.ZANJI_AUTH_SESSION =
        authSession

    _G.ZANJI_LOADER_AUTHORIZED =
        true

    _G.ZANJI_LOADER_OWNER =
        Environment.ZANJI_LOADER_OWNER

    _G.ZANJI_LOADER_PLAN =
        Environment.ZANJI_LOADER_PLAN

    _G.ZANJI_LOADER_EXPIRES_AT =
        Environment.ZANJI_LOADER_EXPIRES_AT

    _G.ZANJI_LOADER_MAX_ACCOUNTS =
        Environment.ZANJI_LOADER_MAX_ACCOUNTS

    _G.ZANJI_LOADER_SLOTS_USED =
        Environment.ZANJI_LOADER_SLOTS_USED

    _G.ZANJI_LOADER_FEATURES =
        features
end

local function ClearAuth()

    Environment.ZANJI_LOADER_AUTHORIZED =
        false

    _G.ZANJI_LOADER_AUTHORIZED =
        false

    local authSession =
        Environment.ZANJI_AUTH_SESSION
        or _G.ZANJI_AUTH_SESSION

    if type(authSession) == "table" then

        authSession.Valid =
            false

        authSession.Token =
            nil
    end

    Environment.ZANJI_AUTH_SESSION =
        nil

    _G.ZANJI_AUTH_SESSION =
        nil
end

--==================================================
-- COMPILE / RUN
--==================================================

local function CompileAndRun(source)

    local compiler =
        loadstring
        or load

    if type(compiler) ~= "function" then

        return false,
            "loadstring/load is unavailable."
    end

    local ok, chunk, compileError =
        pcall(
            compiler,
            source
        )

    if not ok
    or type(chunk) ~= "function" then

        return false,
            "Compile failed: "
            .. tostring(
                compileError
                or chunk
            )
    end

    local runOk, runError =
        pcall(chunk)

    if not runOk then

        return false,
            "Runtime failed: "
            .. tostring(
                runError
            )
    end

    return true
end

--==================================================
-- RUN WITH KEY
--==================================================

local function RunWithKey(key)

    local session, activationError =
        ActivateKey(key)

    if not session then

        return false,
            activationError
    end

    local source, sourceError =
        DownloadSource(session)

    if not source then

        session.Token =
            nil

        return false,
            sourceError
    end

    InstallAuth(session)

    -- The private source receives a short-lived rolling
    -- lease through ZANJI_AUTH_SESSION. The local activation
    -- table itself does not keep another token copy.
    session.Token =
        nil

    SaveKey(key)

    local success, errorMessage =
        CompileAndRun(source)

    if success then

        Environment.ZANJI_LOADER_RUNTIME = {
            JobId = game.JobId,
            Loading = false,
            Loaded = true,
            Channel = "public",
        }

    else

        ClearAuth()

        -- Allow retry if loading failed.
        Environment.ZANJI_LOADER_RUNTIME = {
            JobId = game.JobId,
            Loading = false,
            Loaded = false,
            Channel = "public",
        }
    end

    return success, errorMessage
end

--==================================================
-- UI PARENT
--==================================================

local function GetUiParent()

    if type(gethui) == "function" then

        local ok, result =
            pcall(gethui)

        if ok
        and typeof(result) == "Instance" then

            return result
        end
    end

    if typeof(CoreGui) == "Instance" then
        return CoreGui
    end

    return LocalPlayer:
        WaitForChild(
            "PlayerGui"
        )
end

--==================================================
-- UI CORNER
--==================================================

local ZANJI_UI = {
    Background = Color3.fromRGB(5, 9, 15),
    Surface = Color3.fromRGB(8, 14, 23),
    Field = Color3.fromRGB(10, 18, 29),
    Border = Color3.fromRGB(38, 56, 77),
    Accent = Color3.fromRGB(39, 140, 255),
    AccentHover = Color3.fromRGB(62, 154, 255),
    Text = Color3.fromRGB(232, 237, 245),
    Muted = Color3.fromRGB(135, 147, 163),
}

local function AddCorner(
    instance,
    radius
)

    local corner =
        Instance.new(
            "UICorner"
        )

    corner.CornerRadius =
        UDim.new(
            0,
            radius
        )

    corner.Parent =
        instance
end

local function AddStroke(
    instance,
    color,
    thickness,
    transparency
)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = color or ZANJI_UI.Border
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = instance
    return stroke
end

--==================================================
-- KEY WINDOW
--==================================================

local function CreateKeyWindow(
    initialKey,
    initialMessage
)

    local parent =
        GetUiParent()

    local old =
        parent:FindFirstChild(
            "ZANJI_Public_Key_UI"
        )

    if old then
        old:Destroy()
    end

    local gui =
        Instance.new(
            "ScreenGui"
        )

    gui.Name =
        "ZANJI_Public_Key_UI"

    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999

    gui.Parent =
        parent

    --==================================================
    -- WINDOW
    --==================================================

    local window =
        Instance.new(
            "Frame"
        )

    window.AnchorPoint =
        Vector2.new(
            0.5,
            0.5
        )

    window.Position =
        UDim2.fromScale(
            0.5,
            0.5
        )

    window.Size =
        UDim2.fromOffset(
            470,
            275
        )

    window.BackgroundColor3 =
        ZANJI_UI.Surface

    window.BorderSizePixel = 0
    window.Active = true
    window.Draggable = true
    window.ClipsDescendants = true

    window.Parent =
        gui

    AddCorner(
        window,
        9
    )

    AddStroke(window, ZANJI_UI.Border, 1, 0.05)

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 68)
    header.BackgroundColor3 = ZANJI_UI.Background
    header.BorderSizePixel = 0
    header.Parent = window

    local headerDivider = Instance.new("Frame")
    headerDivider.Name = "Divider"
    headerDivider.Position = UDim2.new(0, 0, 1, -1)
    headerDivider.Size = UDim2.new(1, 0, 0, 1)
    headerDivider.BackgroundColor3 = ZANJI_UI.Border
    headerDivider.BorderSizePixel = 0
    headerDivider.Parent = header

    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Position = UDim2.fromOffset(18, 20)
    accent.Size = UDim2.fromOffset(3, 27)
    accent.BackgroundColor3 = ZANJI_UI.Accent
    accent.BorderSizePixel = 0
    accent.Parent = header
    AddCorner(accent, 2)

    local secureLabel = Instance.new("TextLabel")
    secureLabel.Name = "SecureLabel"
    secureLabel.AnchorPoint = Vector2.new(1, 0.5)
    secureLabel.Position = UDim2.new(1, -20, 0.5, 0)
    secureLabel.Size = UDim2.fromOffset(112, 26)
    secureLabel.BackgroundColor3 = ZANJI_UI.Field
    secureLabel.BorderSizePixel = 0
    secureLabel.Font = Enum.Font.GothamMedium
    secureLabel.Text = "SECURE ACCESS"
    secureLabel.TextColor3 = ZANJI_UI.Accent
    secureLabel.TextSize = 11
    secureLabel.Parent = header
    AddCorner(secureLabel, 5)
    AddStroke(secureLabel, ZANJI_UI.Border, 1, 0.15)

    --==================================================
    -- TITLE
    --==================================================

    local title =
        Instance.new(
            "TextLabel"
        )

    title.Position =
        UDim2.fromOffset(
            31,
            13
        )

    title.Size =
        UDim2.new(
            1,
            -170,
            0,
            24
        )

    title.BackgroundTransparency = 1

    title.Font =
        Enum.Font.GothamBold

    title.Text =
        "ZANJIHUB PREMIUM ACCESS"

    title.TextColor3 =
        ZANJI_UI.Text

    title.TextSize = 18

    title.TextXAlignment =
        Enum.TextXAlignment.Left

    title.Parent =
        header

    local titleHint = Instance.new("TextLabel")
    titleHint.Position = UDim2.fromOffset(31, 37)
    titleHint.Size = UDim2.new(1, -190, 0, 17)
    titleHint.BackgroundTransparency = 1
    titleHint.Font = Enum.Font.Gotham
    titleHint.Text = "License authentication"
    titleHint.TextColor3 = ZANJI_UI.Muted
    titleHint.TextSize = 11
    titleHint.TextXAlignment = Enum.TextXAlignment.Left
    titleHint.Parent = header

    --==================================================
    -- SUBTITLE
    --==================================================

    local subtitle =
        Instance.new(
            "TextLabel"
        )

    subtitle.Position =
        UDim2.fromOffset(
            24,
            80
        )

    subtitle.Size =
        UDim2.new(
            1,
            -48,
            0,
            32
        )

    subtitle.BackgroundTransparency = 1

    subtitle.Font =
        Enum.Font.Gotham

    subtitle.Text =
        "Enter your ZANJI key. A valid key is saved automatically."

    subtitle.TextColor3 =
        ZANJI_UI.Muted

    subtitle.TextSize = 13

    subtitle.TextWrapped = true

    subtitle.TextXAlignment =
        Enum.TextXAlignment.Left

    subtitle.Parent =
        window

    --==================================================
    -- KEY BOX
    --==================================================

    local keyBox =
        Instance.new(
            "TextBox"
        )

    keyBox.Position =
        UDim2.fromOffset(
            24,
            116
        )

    keyBox.Size =
        UDim2.new(
            1,
            -48,
            0,
            44
        )

    keyBox.BackgroundColor3 =
        ZANJI_UI.Field

    keyBox.BorderSizePixel = 0

    keyBox.ClearTextOnFocus = false

    keyBox.Font =
        Enum.Font.Code

    keyBox.PlaceholderText =
        "ZANJI-XXXX-XXXX-XXXX"

    keyBox.PlaceholderColor3 =
        ZANJI_UI.Muted

    keyBox.Text =
        Clean(
            initialKey
        ):upper()

    keyBox.TextColor3 =
        ZANJI_UI.Text

    keyBox.TextSize = 15

    keyBox.Parent =
        window

    AddCorner(
        keyBox,
        6
    )

    local keyBoxStroke = AddStroke(keyBox, ZANJI_UI.Border, 1, 0.05)

    keyBox.Focused:Connect(function()
        keyBoxStroke.Color = ZANJI_UI.Accent
        keyBoxStroke.Transparency = 0
    end)

    keyBox.FocusLost:Connect(function()
        keyBoxStroke.Color = ZANJI_UI.Border
        keyBoxStroke.Transparency = 0.05
    end)

    --==================================================
    -- BUTTON
    --==================================================

    local button =
        Instance.new(
            "TextButton"
        )

    button.Position =
        UDim2.fromOffset(
            24,
            172
        )

    button.Size =
        UDim2.new(
            1,
            -48,
            0,
            42
        )

    button.BackgroundColor3 =
        ZANJI_UI.Accent

    button.BorderSizePixel = 0

    button.Font =
        Enum.Font.GothamBold

    button.Text =
        "ACTIVATE ZANJI KEY"

    button.TextColor3 =
        Color3.fromRGB(
            255,
            255,
            255
        )

    button.TextSize = 14

    button.Parent =
        window

    AddCorner(
        button,
        6
    )

    AddStroke(button, Color3.fromRGB(94, 176, 255), 1, 0.35)

    button.MouseEnter:Connect(function()
        if button.Active then
            button.BackgroundColor3 = ZANJI_UI.AccentHover
        end
    end)

    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = ZANJI_UI.Accent
    end)

    --==================================================
    -- STATUS
    --==================================================

    local status =
        Instance.new(
            "TextLabel"
        )

    status.Position =
        UDim2.fromOffset(
            24,
            225
        )

    status.Size =
        UDim2.new(
            1,
            -48,
            0,
            24
        )

    status.BackgroundTransparency = 1

    status.Font =
        Enum.Font.Gotham

    status.Text =
        tostring(
            initialMessage
            or ""
        )

    status.TextColor3 =
        ZANJI_UI.Muted

    status.TextSize = 12

    status.TextTruncate =
        Enum.TextTruncate.AtEnd

    status.TextXAlignment =
        Enum.TextXAlignment.Left

    status.Parent =
        window

    --==================================================
    -- SUBMIT
    --==================================================

    local busy = false

    local function submit()

        if busy then
            return
        end

        local key =
            Clean(
                keyBox.Text
            ):upper()

        if key == "" then

            status.Text =
                "Enter your ZANJI key."

            return
        end

        busy = true

        button.Active = false

        button.Text =
            "AUTHENTICATING..."

        status.Text =
            "Checking license..."

        task.spawn(function()

            local success, err =
                RunWithKey(key)

            if success then

                status.Text =
                    "Authenticated. Loading ZANJI..."

                task.wait(0.1)

                gui:Destroy()

                return
            end

            busy = false

            button.Active = true

            button.Text =
                "ACTIVATE ZANJI KEY"

            status.Text =
                tostring(err)

            warn(
                "[ZANJI]",
                tostring(err)
            )
        end)
    end

    button.MouseButton1Click:Connect(
        submit
    )

    keyBox.FocusLost:Connect(
        function(enterPressed)

            if enterPressed then
                submit()
            end
        end
    )
end

--==================================================
-- START
--==================================================

local savedKey =
    ReadSavedKey()

if savedKey ~= "" then

    local success, err =
        RunWithKey(
            savedKey
        )

    if success then
        return
    end

    warn(
        "[ZANJI] Saved key failed:",
        tostring(err)
    )

    CreateKeyWindow(
        savedKey,
        tostring(err)
    )

    return
end

CreateKeyWindow(
    "",
    "Paste your ZANJI Premium key to continue."
)
