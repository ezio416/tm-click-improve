// c 2023-12-30
// m 2024-01-10

bool checkingApi = false;
uint64 lastClick = 0;
string title = "\\$F70" + Icons::Kenney::Cursor + "\\$G Click Improve";
string version;
bool versionSafe = false;
uint versionSafeRetries = 0;
uint waitTimeMs = 100;

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Try showing game UI when hidden" description="If disabled, the plugin will work when you show the UI yourself. If this doesn't work after a game update, wait for the plugin author (\\$1D4Ezio\\$G) to confirm it doesn't crash the game."]
bool S_ShowUI = false;

[Setting category="General" name="Override game version check (unsafe)" description="If you don't want to wait for the plugin author to test the current game version, try this setting. \\$FA0It may crash your game."]
bool S_OverrideCheck = false;

void RenderMenu() {
    if (UI::MenuItem(title + (versionSafe ? "" : "\\$AAA (showing UI disabled" + (checkingApi ? ", checking..." : "") + ")"), "", S_Enabled))
        S_Enabled = !S_Enabled;
}

void Main() {
    versionSafe = GameVersionSafe();
    S_OverrideCheck = false;

    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    while (true) {
        Loop(App);
        yield();
    }
}

void OnSettingsChanged() {
    if (S_OverrideCheck)
        versionSafe = true;
}

void Loop(CTrackMania@ App) {
    if (!S_Enabled || App.RootMap is null || App.Editor !is null)
        return;

    uint64 now = Time::Now;
    if (now - lastClick < waitTimeMs)
        return;

    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    if (Network is null)
        return;

    CGameManiaAppPlayground@ CMAP = Network.ClientManiaAppPlayground;
    if (CMAP is null)
        return;

    CGamePlaygroundUIConfig@ Config = CMAP.UI;
    if (Config is null || Config.UISequence != CGamePlaygroundUIConfig::EUISequence::EndRound)
        return;

    CTrackManiaNetworkServerInfo@ ServerInfo = cast<CTrackManiaNetworkServerInfo@>(Network.ServerInfo);
    if (ServerInfo is null || !ServerInfo.CurGameModeStr.EndsWith("_Local"))
        return;

    for (uint i = 0; i < CMAP.UILayers.Length; i++) {
        CGameUILayer@ Layer = CMAP.UILayers[i];
        if (Layer is null)
            continue;

        if (string(Layer.ManialinkPage).Trim().SubStr(0, 64).Contains("_EndRaceMenu")) {
            if (Layer.LocalPage is null)
                return;

            CGameManialinkControl@ Control = Layer.LocalPage.GetFirstChild("ComponentTrackmania_Button_quad-background");
            if (Control is null)
                return;

            CControlQuad@ Quad = cast<CControlQuad@>(Control.Control);
            if (Quad is null)
                return;

            bool uiWasHidden = false;

            if (!UI::IsGameUIVisible()) {
                if (!S_ShowUI || !versionSafe)
                    return;

                uiWasHidden = true;
                SetUIVisibility(App, true);
            }

            while (!UI::IsGameUIVisible())
                yield();

            Quad.OnAction();

            if (uiWasHidden) {
                yield();
                SetUIVisibility(App, false);
            }

            lastClick = now;

            return;
        }
    }
}

// courtesy of "Auto-hide Opponents" plugin - https://github.com/XertroV/tm-autohide-opponents
void SetUIVisibility(CTrackMania@ App, bool shown) {
    string action = (shown ? "show" : "hid") + "ing game UI";
    trace(action);

    uint InterfaceUIOffset = 0x158;
    uint UIVisKeyOffset = 0x1C;
    uint UIVisOffset = 0x3C;

    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);
    if (Network is null)
        return;

    CSmArenaInterfaceUI@ InterfaceUI = cast<CSmArenaInterfaceUI@>(Dev::GetOffsetNod(Network, InterfaceUIOffset));
    if (InterfaceUI is null)
        return;

    Dev::SetOffset(InterfaceUI, UIVisKeyOffset, uint(shown ? 1 : 0));
    Dev::SetOffset(InterfaceUI, UIVisOffset,    uint(shown ? 1 : 0));

    try {
        App.CurrentPlayground.Interface.InterfaceRoot.Childs[2].IsVisible = shown;
    } catch {
        trace("partial success " + action);
        return;
    }

    trace("success " + action);
}

bool GameVersionSafe() {
    string[] knownGood = {
        "2023-11-24_17_34",
        "2023-12-21_23_50"  // released 2024-01-09
    };

    version = GetApp().SystemPlatform.ExeVersion;

    if (knownGood.Find(version) > -1)
        return true;

    return GetStatusFromOpenplanet();
}

// courtesy of "Auto-hide Opponents" plugin - https://github.com/XertroV/tm-autohide-opponents
bool GetStatusFromOpenplanet() {
    checkingApi = true;

    trace("GetStatusFromOpenplanet starting");

    Net::HttpRequest@ req = Net::HttpGet("https://openplanet.dev/plugin/clickimprove/config/version-compat");
    while (!req.Finished())
        yield();

    int code = req.ResponseCode();
    if (code != 200) {
        warn("GetStatusFromOpenplanet error: code: " + code + "; error: " + req.Error() + "; body: " + req.String());
        checkingApi = false;
        return RetryGetStatus();
    }

    try {
        string pluginVersion = Meta::ExecutingPlugin().Version;
        Json::Value@ response = Json::Parse(req.String());

        if (response.GetType() == Json::Type::Object) {
            if (response.HasKey(pluginVersion)) {
                if (response[pluginVersion].HasKey(version) && bool(response[pluginVersion][version])) {
                    checkingApi = false;
                    trace("GetStatusFromOpenplanet good");
                    return true;
                }  else
                    warn("GetStatusFromOpenplanet warning: game version " + version + " not marked good with plugin version " + pluginVersion);
            } else
                warn("GetStatusFromOpenplanet warning: plugin version " + pluginVersion + " not specified");
        } else
            warn("GetStatusFromOpenplanet error: wrong JSON type received");

        checkingApi = false;
        return false;
    } catch {
        warn("GetStatusFromOpenplanet exception: " + getExceptionInfo());
        checkingApi = false;
        return RetryGetStatus();
    }
}

// courtesy of "Auto-hide Opponents" plugin - https://github.com/XertroV/tm-autohide-opponents
bool RetryGetStatus() {
    checkingApi = true;

    trace("retrying GetStatusFromOpenplanet in 1000 ms");

    sleep(1000);

    if (versionSafeRetries++ > 5) {
        warn("not retrying GetStatusFromOpenplanet anymore, too many failures");
        checkingApi = false;
        return false;
    }

    trace("retrying GetStatusFromOpenplanet...");

    checkingApi = false;
    return GetStatusFromOpenplanet();
}