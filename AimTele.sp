#pragma semicolon 1

#define PLUGIN_AUTHOR "Simon"
#define PLUGIN_VERSION "1.3"

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

#define LoopClients(%1) for(int %1 = 1;%1 <= MaxClients;%1++) if(IsValidClient(%1))

EngineVersion g_Game;

ConVar TeleCount;
ConVar TeleBonus;
ConVar TeleTeam;

int iTeleCount[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Aim Teleport",
	author = PLUGIN_AUTHOR,
	description = "Teleports player at aim.",
	version = PLUGIN_VERSION,
	url = "yash1441@yahoo.com"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	CreateConVar("sm_aim_tele_version", PLUGIN_VERSION, "Aim Teleport Version", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	TeleTeam = CreateConVar("sm_aim_tele_team", "1", "Team(s) that can use Teleport. 0 = Both, 1 = Terrorists, 2 = Counter-Terrorists", 0, true, 0.0, true, 2.0);
	TeleCount = CreateConVar("sm_aim_tele_count", "3", "Amount of Teleports available at round start.", 0, true, 0.0, false);
	TeleBonus = CreateConVar("sm_aim_tele_bonus", "1", "Amount of Teleports to increase upon getting a kill.", 0, true, 0.0, false);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	AddCommandListener(Command_LookAtWeapon, "+lookatweapon");
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	LoopClients(i)
	{
		if(GetConVarInt(TeleTeam) == 0 || GetClientTeam(i) == (GetConVarInt(TeleTeam) + 1))
		{
			iTeleCount[i] = GetConVarInt(TeleCount);
		}
	}
}

public Action Command_LookAtWeapon(int client, const char[] command, int argc)
{
	if(GetConVarInt(TeleTeam) == 0 || GetClientTeam(client) == (GetConVarInt(TeleTeam) + 1))
	{
		if(iTeleCount[client] > 0)
		{
			SetTeleportEndPoint(client);
			return Plugin_Handled;
		}
		else return Plugin_Continue;
	}
	else return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(GetConVarInt(TeleTeam) == 0 || GetClientTeam(attacker) == (GetConVarInt(TeleTeam) + 1))
	{
		if(GetClientTeam(victim) != GetClientTeam(attacker))
		{
			iTeleCount[attacker] += GetConVarInt(TeleBonus);
		}
	}
}

public void PerformTeleport(int target, float pos[3])
{
	float partpos[3];
	
	GetClientEyePosition(target, partpos);
	partpos[2]-=20.0;	
	
	TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
	pos[2]+=40.0;
	--iTeleCount[target];
}

public void SetTeleportEndPoint(int client)
{
	float vAngles[3];
	float vOrigin[3];
	float vBuffer[3];
	float vStart[3];
	float Distance;
	float g_pos[3];
	
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    	
	if(TR_DidHit(trace))
	{   	 
   	 	TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		Distance = -35.0;
   	 	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
		g_pos[1] = vStart[1] + (vBuffer[1]*Distance);
		g_pos[2] = vStart[2] + (vBuffer[2]*Distance);
	}
	CloseHandle(trace);
	PerformTeleport(client, g_pos);
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > GetMaxClients() || !entity;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}