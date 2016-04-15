#pragma semicolon 1
#include <sourcemod>
#include <updater>
#include <socket>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#define RED 0
#define BLU 1
#define TEAM_OFFSET 2

#define PLUGIN_VERSION "1.2.2"

#define MAX_URL_LENGTH 256
#define UPDATE_URL "http://miggthulu.com/POVminder/updatefile.txt"


public Plugin:myinfo =
{
	name 		= "POVminder",
	author 		= "Miggy",
	description = "Remind players to record POVs during matches",
	version		= PLUGIN_VERSION,
	url 		= "miggthulu.com"
};

//Lots of credit should go to Carbon as this is based heavily off of his code: https://forums.alliedmods.net/showthread.php?t=92716

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

new bool:teamReadyState[2] = { false, false };
new bool:RemindOnRestart = false;
new bool:reminding = false;
new Handle:g_hPOVEnabled;
new bool:g_bPOVEnabled;
new Handle:gH_AdminMenu = INVALID_HANDLE;



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
	
	CreateConVar("sm_pov_version", PLUGIN_VERSION, "POVminder version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	
	g_hPOVEnabled = CreateConVar("sm_POVminder", "0", "Enable POVminder?(As if you'd want if off)\n0 = Disabled\n1 = Enabled", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bPOVEnabled = GetConVarBool(g_hPOVEnabled);
	HookConVarChange(g_hPOVEnabled, OnConVarChange);
	
	RegAdminCmd("sm_reminder", RemindCmd, ADMFLAG_GENERIC, "Turns on POV Reminder");
	
	AutoExecConfig(true, "plugin.pov");
	
	new Handle:topmenu;
	if(LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	
}

public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar == g_hPOVEnabled)
	{
		SetConVarBool(g_hPOVEnabled, bool:StringToInt(newValue), true, false);
		g_bPOVEnabled = GetConVarBool(g_hPOVEnabled);
	}
		
	if(!g_bPOVEnabled)
	{
		PrintToChatAll("[SM] POVMinder Disabled");
	}
	else
	{
        PrintToChatAll("[SM] POVMinder Enabled");
	} 
	
}

public OnLibraryRemoved(const String:name[])
{
	if(StrEqual(name, "adminmenu"))
	{
		gH_AdminMenu = INVALID_HANDLE;
	}
}

public OnAdminMenuReady(Handle: topmenu)
{	
	new TopMenuObject:server_commands = FindTopMenuCategory(topmenu, ADMINMENU_SERVERCOMMANDS);
	
	if(server_commands == INVALID_TOPMENUOBJECT)
		return;
		
	if(topmenu == gH_AdminMenu)
	{
		return;
	}
	
	gH_AdminMenu = topmenu;
	
	AddToTopMenu(gH_AdminMenu, "sm_reminder", TopMenuObject_Item, AdminMenu_Reminder, server_commands, "sm_reminder", ADMFLAG_GENERIC);
}

public AdminMenu_Reminder(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlength, "Turn On/Off POV Reminders");
	}
	
	else if(action == TopMenuAction_SelectOption)
	{
		SetConVarBool(g_hPOVEnabled, !GetConVarBool(g_hPOVEnabled), true, false);
	}
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
			if (g_bPOVEnabled)
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
public Action:RemindCmd(client, args)
{
	//if(IsFakeClient(client) || !IsClientConnected(client))
		//return Plugin_Handled;
	
	if(args > 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_reminder [0/1]");
		return Plugin_Handled;
	}
	
	if(args == 0)
	{
		SetConVarBool(g_hPOVEnabled, !GetConVarBool(g_hPOVEnabled), true, false);
		g_bPOVEnabled = !g_bPOVEnabled;
		return Plugin_Handled;
	}
	
	new String:arg1[16];
	GetCmdArg(1, arg1, 16);
	new arg = StringToInt(arg1);
	
	if(arg > 1 || arg < 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_reminder [0/1]");
		return Plugin_Handled;
	}
	
	if(arg == 1)
	{
		if(GetConVarBool(g_hPOVEnabled))
		{
			ReplyToCommand(client, "[SM] Plugin is already Enabled.");
			return Plugin_Handled;
		}
		
		SetConVarBool(g_hPOVEnabled, bool:arg, true, false);
	}
	
	else if(arg == 0)
	{
		if(!GetConVarBool(g_hPOVEnabled))
		{
			ReplyToCommand(client, "[SM] Plugin is already Disabled.");
			return Plugin_Handled;
		}
		
		SetConVarBool(g_hPOVEnabled, bool:arg, true, false);
	}
	
	return Plugin_Handled;
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