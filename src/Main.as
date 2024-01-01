// c 2023-12-30
// m 2023-12-31

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
    if (UI::MenuItem(title + (versionSafe ? "" : "\\$AAA (disabled)"), "", S_Enabled))
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

    CGameManiaAppPlayground@ Playground = cast<CGameManiaAppPlayground@>(Network.ClientManiaAppPlayground);
    if (Playground is null)
        return;

    CGamePlaygroundUIConfig@ Config = Playground.UI;
    if (Config is null || Config.UISequence != CGamePlaygroundUIConfig::EUISequence::EndRound)
        return;

    CTrackManiaNetworkServerInfo@ ServerInfo = cast<CTrackManiaNetworkServerInfo@>(Network.ServerInfo);
    if (ServerInfo is null || !ServerInfo.CurGameModeStr.EndsWith("_Local"))
        return;

    for (uint i = 0; i < Playground.UILayers.Length; i++) {
        CGameUILayer@ Layer = Playground.UILayers[i];
        if (Layer is null)
            continue;

        if (Layer.ManialinkPage.Contains("EndRaceMenu")) {
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
        "2023-11-24_17_34"
    };

    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    version = App.SystemPlatform.ExeVersion;

    if (knownGood.Find(version) > -1)
        return true;

    return GetStatusFromOpenplanet();
}

// courtesy of "Auto-hide Opponents" plugin - https://github.com/XertroV/tm-autohide-opponents
bool GetStatusFromOpenplanet() {
    trace("starting GetStatusFromOpenplanet");

    Net::HttpRequest@ req = Net::HttpGet("https://openplanet.dev/plugin/clickimprove/config/version-compat");
    while (!req.Finished())
        yield();

    if (req.ResponseCode() != 200) {
        warn("GetStatusFromOpenplanet: code: " + req.ResponseCode() + "; error: " + req.Error() + "; body: " + req.String());
        return RetryGetStatus();
    }

    try {
        Json::Value@ j = Json::Parse(req.String());
        string myVer = Meta::ExecutingPlugin().Version;

        if (!j.HasKey(myVer) || j[myVer].GetType() != Json::Type::Object)
            return false;

        return j[myVer].HasKey(version);
    } catch {
        warn("GetStatusFromOpenplanet exception: " + getExceptionInfo());
        return RetryGetStatus();
    }
}

// courtesy of "Auto-hide Opponents" plugin - https://github.com/XertroV/tm-autohide-opponents
bool RetryGetStatus() {
    trace("retrying GetStatusFromOpenplanet in 1000 ms");

    sleep(1000);

    if (versionSafeRetries++ > 5) {
        warn("not retrying GetStatusFromOpenplanet anymore, too many failures");
        return false;
    }

    trace("retrying GetStatusFromOpenplanet...");

    return GameVersionSafe();
}