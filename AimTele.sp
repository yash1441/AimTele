#pragma semicolon 1

#define PLUGIN_AUTHOR "Simon"
#define PLUGIN_VERSION "1.4"

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

#define LoopClients(%1) for(int %1 = 1;%1 <= MaxClients;%1++) if(IsValidClient(%1))

EngineVersion g_Game;

ConVar TeleCount;
ConVar TeleBonus;
ConVar TeleTeam;
//ConVar TeleCD;

int iTeleCount[MAXPLAYERS + 1];
bool isStuck[MAXPLAYERS+1];
float Ground_Velocity[3] = {0.0, 0.0, -300.0};

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
	//TeleCD = CreateConVar("sm_aim_tele_cooldown", "5", "Seconds to wait before using another Teleport.", 0, true, 0.0, false);
	
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
	CheckStuck(target);
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

public void CheckStuck(int client)
{
	isStuck[client] = false;
	isStuck[client] = CheckIfPlayerIsStuck(client);
	CheckIfPlayerCanMove(client, 0, 500.0, 0.0, 0.0);
}

stock bool CheckIfPlayerIsStuck(int client)
{
	float vecMin[3];
	float vecMax[3];
	float vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	GetClientAbsOrigin(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceEntityFilterSolid);
	return TR_DidHit();
}

public void CheckIfPlayerCanMove(int client, int testID, float X, float Y, float Z)
{
	float vecVelo[3];
	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);
	
	vecVelo[0] = X;
	vecVelo[1] = Y;
	vecVelo[2] = Z;
	
	SetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", vecVelo);
	
	DataPack TimerDataPack;
	CreateDataTimer(0.1, TimerWait, TimerDataPack); 
	WritePackCell(TimerDataPack, client);
	WritePackCell(TimerDataPack, testID);
	WritePackFloat(TimerDataPack, vecOrigin[0]);
	WritePackFloat(TimerDataPack, vecOrigin[1]);
	WritePackFloat(TimerDataPack, vecOrigin[2]);
}

public Action TimerWait(Handle timer, Handle data)
{	
	float vecOrigin[3];
	float vecOriginAfter[3];
	
	ResetPack(data, false);
	int client 		= ReadPackCell(data);
	int testID 			= ReadPackCell(data);
	vecOrigin[0]		= ReadPackFloat(data);
	vecOrigin[1]		= ReadPackFloat(data);
	vecOrigin[2]		= ReadPackFloat(data);
	
	
	GetClientAbsOrigin(client, vecOriginAfter);
	
	if(GetVectorDistance(vecOrigin, vecOriginAfter, false) < 10.0) // Can't move
	{
		if(testID == 0)
			CheckIfPlayerCanMove(client, 1, 0.0, 0.0, -500.0);	// Jump
		else if(testID == 1)
			CheckIfPlayerCanMove(client, 2, -500.0, 0.0, 0.0);
		else if(testID == 2)
			CheckIfPlayerCanMove(client, 3, 0.0, 500.0, 0.0);
		else if(testID == 3)
			CheckIfPlayerCanMove(client, 4, 0.0, -500.0, 0.0);
		else if(testID == 4)
			CheckIfPlayerCanMove(client, 5, 0.0, 0.0, 300.0);
		else
			FixPlayerPosition(client);
	}
}

public void FixPlayerPosition(int client)
{
	if(isStuck[client])
	{
		float pos_Z = 0.1;
		
		while(pos_Z <= 200 && !TryFixPosition(client, 10.0, pos_Z))
		{	
			pos_Z = -pos_Z;
			if(pos_Z > 0.0)
				pos_Z += 20;
		}
		
		if(!CheckIfPlayerIsStuck(client))
			CheckStuck(client);
	}
	else
	{
		Handle trace = INVALID_HANDLE;
		float vecOrigin[3];
		float vecAngle[3];
		
		GetClientAbsOrigin(client, vecOrigin);
		vecAngle[0] = 90.0;
		trace = TR_TraceRayFilterEx(vecOrigin, vecAngle, MASK_SOLID, RayType_Infinite, TraceEntityFilterSolid);		
		if(!TR_DidHit(trace)) 
		{
			CloseHandle(trace);
			return;
		}
		
		TR_GetEndPosition(vecOrigin, trace);
		CloseHandle(trace);
		vecOrigin[2] += 10.0;
		TeleportEntity(client, vecOrigin, NULL_VECTOR, Ground_Velocity);
		
		CheckStuck(client);
	}
}

public bool TryFixPosition(int client, float Radius, float pos_Z)
{
	float DegreeAngle;
	float vecPosition[3];
	float vecOrigin[3];
	float vecAngle[3];
	
	GetClientAbsOrigin(client, vecOrigin);
	GetClientEyeAngles(client, vecAngle);
	vecPosition[2] = vecOrigin[2] + pos_Z;

	DegreeAngle = -180.0;
	while(DegreeAngle < 180.0)
	{
		vecPosition[0] = vecOrigin[0] + Radius * Cosine(DegreeAngle * FLOAT_PI / 180); // convert angle in radian
		vecPosition[1] = vecOrigin[1] + Radius * Sine(DegreeAngle * FLOAT_PI / 180);
		
		TeleportEntity(client, vecPosition, vecAngle, Ground_Velocity);
		if(!CheckIfPlayerIsStuck(client))
			return true;
		
		DegreeAngle += 10.0; // + 10°
	}
	
	TeleportEntity(client, vecOrigin, vecAngle, Ground_Velocity);
	if(Radius <= 200)
		return TryFixPosition(client, Radius + 20, pos_Z);
	
	return false;
}

public bool TraceEntityFilterSolid(int entity, int contentsMask) 
{
	return entity > 1;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}