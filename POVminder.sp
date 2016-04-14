#pragma semicolon 1
#include <sourcemod>

#define RED 0
#define BLU 1
#define TEAM_OFFSET 2

#define PLUGIN_VERSION "1.0"


public Plugin:myinfo =
{
	name 		= "POVminder",
	author 		= "Miggy",
	description = "Remind players to record POVs during matches",
	version		= PLUGIN_VERSION,
	url 		= "miggthulu.com"
};

//Credit should really go to Carbon as this is 98% his code: https://forums.alliedmods.net/showthread.php?t=92716

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

new bool:teamReadyState[2] = { false, false };
new bool:RemindOnRestart = false;
new bool:reminding = false;
new Handle:g_hPOVEnabled;	//NOT YET FUNCTIONAL
new bool:g_bPOVEnabled;	//NOT YET FUNCTIONAL  



//------------------------------------------------------------------------------
// Startup
//------------------------------------------------------------------------------


public OnPluginStart()
{
	// Team status updates
	HookEvent("tournament_stateupdate", TeamStateEvent);

	// Game restart
	HookEvent("teamplay_restart_round", GameRestartEvent);

	// Win conditions met (maxrounds, timelimit)
	HookEvent("teamplay_game_over", GameOverEvent);

	// Win conditions met (windifference)
	HookEvent("tf_game_over", GameOverEvent);

	// Hook into mp_tournament_restart
	RegServerCmd("mp_tournament_restart", TournamentRestartHook);
	
	
	g_hPOVEnabled = CreateConVar("sm_POVminder", "0", "Enable POVminder?(As if you'd want if off)\n0 = Disabled\n1 = Enabled", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bPOVEnabled = GetConVarBool(g_hPOVEnabled);
	HookConVarChange(g_hPOVEnabled, OnConVarChange);
	
	//RegAdminCmd("sm_reminder", RemindCmd, ADMFLAG_GENERIC, "Turns on POV Reminder"); Non functional :(
	
}

public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar == g_hPOVEnabled)
		g_bPOVEnabled = bool:StringToInt(newValue);
		
	/* Non functional :(
	if (!g_bPOVEnabled(1))
    {
        PrintToChatAll("[SM] POVMinder Enabled");
    }
    else
    {
        PrintToChatAll("[SM] POVMinder Disabled");
    } 
	*/
}



//------------------------------------------------------------------------------
// Callbacks
//------------------------------------------------------------------------------

public TeamStateEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new team = GetClientTeam(GetEventInt(event, "userid")) - TEAM_OFFSET;
	new bool:nameChange = GetEventBool(event, "namechange");
	new bool:readyState = GetEventBool(event, "readystate");

	if (!nameChange)
	{
		teamReadyState[team] = readyState;

		// If both teams are ready wait for round restart to start reminding players to record
		if (teamReadyState[RED] && teamReadyState[BLU])
		{
			RemindOnRestart = true;
		}
		else
		{
			RemindOnRestart = false;
		}
	}
}

public GameRestartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Start reminding only if both team are in ready state
		if (RemindOnRestart)
		{
			if (GetConVarBool(g_bPOVEnabled))
			{
				StartReminding();
				RemindOnRestart = false;
				teamReadyState[RED] = false;
				teamReadyState[BLU] = false;
			}
		}
}

public GameOverEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	Stopreminding();
}

public Action:TournamentRestartHook(args)
{
	// If mp_tournament_restart is called, stop reminding
	if (reminding)
	{
		Stopreminding();
	}

	return Plugin_Continue;
}

public OnMapStart()
{
	ResetVariables();

	// Check every 30secs if there are still players on the server
	CreateTimer(30.0, CheckPlayers, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapEnd()
{
}

// Stop reminding if there are no players on the server
public Action:CheckPlayers(Handle:timer)
{
	if (reminding)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && !IsFakeClient(i))
			{
				return;
			}
		}

		Stopreminding();
	}
}

//------------------------------------------------------------------------------
// Commands
//------------------------------------------------------------------------------
/* Non functional :(
public Action:RemindCmd(client, args)
{
	if(!g_bPOVEnabled || !IsValidClient(client))
		return Plugin_Continue;

	if(args != 0 && args != 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_reminder [0/1]");
		return Plugin_Handled;
	}
}
*/


//------------------------------------------------------------------------------
// Private functions
//------------------------------------------------------------------------------

ResetVariables()
{
	teamReadyState[RED] = false;
	teamReadyState[BLU] = false;
	RemindOnRestart = false;
	reminding = false;
}

StartReminding()
{
	// Start reminding
	ServerCommand("sm_csay [POVminder]: Don't forget to record POVs during official matches");
	PrintToChatAll("[POVminder]: All players are required to record POVs during official matches");
	PrintToChatAll("[POVminder]: Failure to record POVs could result in a 1 week suspension and/or Match Overturn");
	reminding = true;
}

Stopreminding()
{
	if (reminding)
	{
		// Stop reminding
		PrintToChatAll("[POVminder]: Remember, players are required to keep all POVs for the duration of the season");
		reminding = false;
	}
}
