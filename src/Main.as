uint64        lastClick   = 0;
const string  pluginColor = "\\$F70";
const string  pluginIcon  = Icons::Kenney::Cursor;
Meta::Plugin@ pluginMeta  = Meta::ExecutingPlugin();
const string  pluginTitle = pluginColor + pluginIcon + "\\$G " + pluginMeta.Name;

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

void Main() {
    auto App = cast<CTrackMania>(GetApp());

    while (true) {
        do {
            yield();
        } while (Time::Now - lastClick < 1000);

        if (false
            or !S_Enabled
            or App.RootMap is null
            or App.Editor !is null
            or App.Network.ClientManiaAppPlayground is null
            or App.Network.ClientManiaAppPlayground.UI is null
        ) {
            continue;
        }

        auto ServerInfo = cast<CTrackManiaNetworkServerInfo>(App.Network.ServerInfo);
        if (false
            or ServerInfo is null
            or !ServerInfo.CurGameModeStr.EndsWith("_Local")
        ) {
            continue;
        }

        if (false
            or ServerInfo.CurGameModeStr.Contains("Stunt")
            or ServerInfo.CurGameModeStr.Contains("Royal")
        ) {
            if (App.Network.ClientManiaAppPlayground.UI.UISequence != CGamePlaygroundUIConfig::EUISequence::UIInteraction) {
                continue;
            }

            MwFastBuffer<wstring> id;
            id.Add(App.LocalPlayerInfo.WebServicesUserId);
            App.Network.ClientManiaAppPlayground.SendCustomEvent("StuntsResultEvent_Skip", id);
            yield();

        } else if (App.Network.ClientManiaAppPlayground.UI.UISequence != CGamePlaygroundUIConfig::EUISequence::EndRound) {
            continue;
        }

        App.Network.ClientManiaAppPlayground.SendCustomEvent(
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
    if (UI::MenuItem(pluginTitle, "", S_Enabled)) {
        S_Enabled = !S_Enabled;
    }
}
