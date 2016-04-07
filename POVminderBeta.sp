#pragma semicolon 1
#include <sourcemod>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = {
	name        = "POVminder",
	author      = "Miggy",
	description = "Plugin that reminds player to record demos",
	version		= PLUGIN_VERSION,
	url         = "miggthulu.com"
};
/**
public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	PrintToChatAll("[POVminder]: All players are required to record demo's during official matches");
	PrintToChatAll("[POVminder]: Failure to record demo's could result in a 1 week suspension");
	return Plugin_Continue;
}
**/
/**
public void OnPluginStart() 
{ 
    HookEvent("teamplay_round_start", EventRoundStart);
} 

public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast) 
{ 
    static bool firstRound = true; 
    if(firstRound) 
    { 
        firstRound = false; 
		ServerCommand("sm_csay [POVminder]: Don't forget to record demo's during official matches");
		PrintToChatAll("[POVminder]: All players are required to record demo's during official matches");
		PrintToChatAll("[POVminder]: Failure to record demo's could result in a 1 week suspension");
    } 
}  
**/

