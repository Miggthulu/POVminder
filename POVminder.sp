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
		StartReminding();
		RemindOnRestart = false;
		teamReadyState[RED] = false;
		teamReadyState[BLU] = false;
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
	PrintToChatAll("[POVminder]: Failure to record POVs could result in a 1 week suspension");
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