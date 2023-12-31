// c 2023-12-30
// m 2023-12-31

uint64 lastClick = 0;
string title = "\\$F70" + Icons::Kenney::Cursor + "\\$G Click Improve";
uint waitTimeMs = 100;

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

[Setting category="General" name="Try showing UI when hidden" description="May crash the game when there's an update!"]
bool S_ShowUI = false;

void RenderMenu() {
    if (UI::MenuItem(title, "", S_Enabled))
        S_Enabled = !S_Enabled;
}

void Main() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());

    while (true) {
        Loop(App);
        yield();
    }
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
                if (!S_ShowUI)
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
// working as of game version 2023-11-24_17_34
void SetUIVisibility(CTrackMania@ App, bool shown) {
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
    } catch { }
}