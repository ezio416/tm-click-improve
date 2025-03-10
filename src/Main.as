// c 2023-12-30
// m 2025-03-10

uint64        lastClick   = 0;
const string  pluginColor = "\\$F70";
const string  pluginIcon  = Icons::Kenney::Cursor;
Meta::Plugin@ pluginMeta  = Meta::ExecutingPlugin();
const string  pluginTitle = pluginColor + pluginIcon + "\\$G " + pluginMeta.Name;

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

void Main() {
    CTrackMania@ App = cast<CTrackMania@>(GetApp());
    CTrackManiaNetwork@ Network = cast<CTrackManiaNetwork@>(App.Network);

    while (true) {
        do {
            yield();
        } while (Time::Now - lastClick < 1000);

        if (false
            || !S_Enabled
            || App.RootMap is null
            || App.Editor !is null
            || Network.ClientManiaAppPlayground is null
            || Network.ClientManiaAppPlayground.UI is null
        )
            continue;

        CTrackManiaNetworkServerInfo@ ServerInfo = cast<CTrackManiaNetworkServerInfo@>(Network.ServerInfo);
        if (ServerInfo is null || !ServerInfo.CurGameModeStr.EndsWith("_Local"))
            continue;

        if (ServerInfo.CurGameModeStr.Contains("Stunt")) {
            if (Network.ClientManiaAppPlayground.UI.UISequence != CGamePlaygroundUIConfig::EUISequence::UIInteraction)
                continue;

            MwFastBuffer<wstring> id;
            id.Add(App.LocalPlayerInfo.WebServicesUserId);
            Network.ClientManiaAppPlayground.SendCustomEvent("StuntsResultEvent_Skip", id);
            yield();

        } else if (Network.ClientManiaAppPlayground.UI.UISequence != CGamePlaygroundUIConfig::EUISequence::EndRound)
            continue;

        Network.ClientManiaAppPlayground.SendCustomEvent(
            ServerInfo.CurGameModeStr == "TM_PlayMap_Local"
                ? "playmap-endracemenu-improve"
                : "EndRaceMenuEvent_Improve"  // campaign, platform, stunt
            ,
            MwFastBuffer<wstring>()
        );

        trace("clicked!");
        lastClick = Time::Now;
    }
}

void RenderMenu() {
    if (UI::MenuItem(pluginTitle, "", S_Enabled))
        S_Enabled = !S_Enabled;
}
