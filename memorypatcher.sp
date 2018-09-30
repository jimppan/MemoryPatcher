#pragma semicolon 1

#define DEBUG
#pragma dynamic 131072

#define PLUGIN_AUTHOR "Rachnus"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <memorypatcher>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Memory Patcher v1.0",
	author = PLUGIN_AUTHOR,
	description = "Patch memory and stuff",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rachnus"
};

bool g_bPatched = false;

int g_iServerOS = OSType_Windows;

ArrayList g_hPatchGamedata =   			null;

ArrayList g_hPatchAddress =  			null;
ArrayList g_hPatchByteCount =  			null;
ArrayList g_hPatchPreviousOPCodes =  	null;

Handle g_hOnMemoryPatcherReady;

public void OnPluginStart()
{
	HookEvent("server_spawn", Event_ServerSpawn);
	
	g_hOnMemoryPatcherReady = CreateGlobalForward("MP_OnMemoryPatcherReady", ET_Ignore);
	
	RegAdminCmd("sm_mp_patchall", 	Command_PatchAll, 		ADMFLAG_ROOT);
	RegAdminCmd("sm_mp_restoreall", Command_RestoreAll, 	ADMFLAG_ROOT);
	
#if defined DEBUG
	RegAdminCmd("sm_mptest", Command_Test, ADMFLAG_ROOT);
	RegAdminCmd("sm_mptest2", Command_Test2, ADMFLAG_ROOT);
#endif
	
	InitPatchLists();
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int err_max)
{
	CreateNative("MP_GetServerOSType", Native_GetServerOSType);
	CreateNative("MP_AddMemoryPatch", Native_AddMemoryPatch);
	CreateNative("MP_AddMemoryPatchEx", Native_AddMemoryPatchEx);
	CreateNative("MP_RemoveMemoryPatch", Native_RemoveMemoryPatch);
	CreateNative("MP_MemoryPatchExists", Native_MemoryPatchExists);
	CreateNative("MP_IsPatched", Native_IsPatched);
	CreateNative("MP_PatchAll", Native_PatchAll);
	CreateNative("MP_RestoreAll", Native_RestoreAll);
	CreateNative("MP_Patch", Native_Patch);
	CreateNative("MP_Restore", Native_Restore);
	CreateNative("MP_GetMemoryPatchCount", Native_GetMemoryPatchCount);
	
	RegPluginLibrary("memorypatcher");
	
	return APLRes_Success;
}

public int Native_GetServerOSType(Handle plugin, int numParams)
{
	return g_iServerOS;
}

public int Native_AddMemoryPatch(Handle plugin, int numParams)
{
	int ostype = GetNativeCell(1);
	if(!MP_IsValidOSType(ostype))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Invalid OSType (%d)", ostype);
		return false;
	}
	
	int libtype = GetNativeCell(2);
	if(!MP_IsValidLIBType(libtype))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Invalid LIBType (%d)", libtype);
		return false;
	}
	
	char siglabel[MP_PATCH_MAX_NAME_LENGTH];
	GetNativeString(3, siglabel, MP_PATCH_MAX_NAME_LENGTH);
		
	char sig[MP_PATCH_MAX_SIG_LENGTH];
	GetNativeString(4, sig, MP_PATCH_MAX_SIG_LENGTH);	
	
	int offset = GetNativeCell(5);
	int patchbytecount = GetNativeCell(7);
	
	int opcodes[MP_PATCH_MAX_OP_CODES];
	GetNativeArray(6, opcodes, patchbytecount);
	
	return AddMemoryPatch(ostype, libtype, siglabel, sig, offset, opcodes, patchbytecount);
}

public int Native_AddMemoryPatchEx(Handle plugin, int numParams)
{
	int ostype = GetNativeCell(1);
	if(!MP_IsValidOSType(ostype))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Invalid OSType (%d)", ostype);
		return false;
	}
	
	int libtype = GetNativeCell(2);
	if(!MP_IsValidLIBType(libtype))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Invalid LIBType (%d)", libtype);
		return false;
	}
	
	char siglabel[MP_PATCH_MAX_NAME_LENGTH];
	GetNativeString(3, siglabel, MP_PATCH_MAX_NAME_LENGTH);
		
	char sig[MP_PATCH_MAX_SIG_LENGTH];
	GetNativeString(4, sig, MP_PATCH_MAX_SIG_LENGTH);	
	
	int offset = GetNativeCell(5);
	int opcode = GetNativeCell(6);
	int patchbytecount = GetNativeCell(7);
	
	return AddMemoryPatchEx(ostype, libtype, siglabel, sig, offset, opcode, patchbytecount);
}

public int Native_RemoveMemoryPatch(Handle plugin, int numParams)
{
	char siglabel[MP_PATCH_MAX_NAME_LENGTH];
	GetNativeString(1, siglabel, MP_PATCH_MAX_NAME_LENGTH);

	return RemoveMemoryPatch(siglabel);
}

public int Native_MemoryPatchExists(Handle plugin, int numParams)
{
	char siglabel[MP_PATCH_MAX_NAME_LENGTH];
	GetNativeString(1, siglabel, MP_PATCH_MAX_NAME_LENGTH);

	return MemoryPatchExists(siglabel);
}

public int Native_IsPatched(Handle plugin, int numParams)
{
	char siglabel[MP_PATCH_MAX_NAME_LENGTH];
	GetNativeString(1, siglabel, MP_PATCH_MAX_NAME_LENGTH);

	return IsPatchedByLabel(siglabel);
}

public int Native_PatchAll(Handle plugin, int numParams)
{
	return ApplyMemoryPatchAll();
}

public int Native_RestoreAll(Handle plugin, int numParams)
{
	return RestoreMemoryPatchAll();
}

public int Native_Patch(Handle plugin, int numParams)
{
	char siglabel[MP_PATCH_MAX_NAME_LENGTH];
	GetNativeString(1, siglabel, MP_PATCH_MAX_NAME_LENGTH);
	
	return ApplyMemoryPatchByLabel(siglabel);
}

public int Native_Restore(Handle plugin, int numParams)
{
	char siglabel[MP_PATCH_MAX_NAME_LENGTH];
	GetNativeString(1, siglabel, MP_PATCH_MAX_NAME_LENGTH);
	
	return RestoreMemoryPatchByLabel(siglabel);
}

public int Native_GetMemoryPatchCount(Handle plugin, int numParams)
{
	return g_hPatchGamedata.Length;
}

public void OnPluginEnd()
{
	RestoreMemoryPatchAll();
}

#if defined DEBUG
public Action Command_Test(int client, int args)
{
	//int opcodes[5] =  { 0x90, 0x90, 0x90, 0x90, 0x90 };
	char sig[] = "\\x55\\x8B\\xEC\\x83\\xEC\\x10\\x53\\x56\\x8B\\xF1\\x8B\\x0D\\x34";
	if(AddMemoryPatchEx(OSType_Windows, LIBType_Server, "CCSBot::Upkeep", "\\x55\\x8B\\xEC\\x83\\xEC\\x10\\x53\\x56\\x8B\\xF1\\x8B\\x0D\\x34", 795, 0x90, 5))
		PrintToServer("Added memory patch %s", "CCSBot::Upkeep");
		
	return Plugin_Handled;
}

public Action Command_Test2(int client, int args)
{
	if(g_hPatchGamedata.Length > 0)
		PrintToServer("CCSBot::Upkeep patched: %s", IsPatchedByLabel("CCSBot::Upkeep") ? "Yes":"No");
	PrintToServer("CCSBot::Upkeep exists: %s", MemoryPatchExists("CCSBot::Upkeep") ? "Yes":"No");
}
#endif

public Action Command_PatchAll(int client, int args)
{
	int succeeded = ApplyMemoryPatchAll();
	PrintToChat(client, "%s \x04Success\x09: \x05%d\x09", MP_PREFIX, succeeded);
	if(succeeded != g_hPatchGamedata.Length)
		PrintToChat(client, "%s \x07Failed\x09: \x05%d\x09", MP_PREFIX, g_hPatchGamedata.Length - succeeded);
	
	return Plugin_Handled;
}

public Action Command_RestoreAll(int client, int args)
{
	int restored = RestoreMemoryPatchAll();
	PrintToChat(client, "%s \x04Restored\x09: \x03%d\x09", MP_PREFIX, restored);
	return Plugin_Handled;
}

public Action Event_ServerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	char os[32];
	event.GetString("os", os, sizeof(os));
	
	if(StrEqual(os, "WIN32", false))
		g_iServerOS = OSType_Windows;
	else if(StrEqual(os, "LINUX", false))
		g_iServerOS = OSType_Linux;
	else
		g_iServerOS = OSType_Mac;
#if defined DEBUG
	MP_Debug("Server OS: %s", os);
#endif
	
	if(!g_bPatched)
	{
		Call_StartForward(g_hOnMemoryPatcherReady);
		Call_Finish();
		g_bPatched = true;
	}
}	

public void InitPatchLists()
{
	g_hPatchGamedata = new ArrayList();
	
	g_hPatchAddress = new ArrayList();
	g_hPatchByteCount = new ArrayList();
	g_hPatchPreviousOPCodes = new ArrayList(MP_PATCH_MAX_OP_CODES);
}

public int RestoreMemoryPatchAll()
{
	int count = g_hPatchAddress.Length;
	for (int i = g_hPatchAddress.Length - 1; i >= 0; --i)
		RestoreMemoryPatchByIndex(i);

	return count;
}

public int ApplyMemoryPatchAll()
{
	int count = 0;
	for (int i = 0; i < g_hPatchGamedata.Length; i++)
	{
		if(ApplyMemoryPatchByIndex(i))
			count++;
	}
	return count;
}

public int AddMemoryPatch(int ostype, int libtype, const char[] siglabel, char[] sig, int offset, int[] opcodes, int patchbytecount)
{
	if(patchbytecount > MP_PATCH_MAX_OP_CODES)
	{
		LogError("Patching over %d bytes is not supported", MP_PATCH_MAX_OP_CODES);
		return MP_PATCH_ADD_ERROR_EXCEEDED_OP_CODE_COUNT;
	}
	
	if(MemoryPatchExists(siglabel))
	{
		LogError("Sig \"%s\" already exists!", siglabel);
		return MP_PATCH_ADD_ERROR_PATCH_EXISTS;
	}
	
	// big lol but works
	KeyValues gamedata = MP_GenerateGameDataKeyvalues(ostype, libtype, siglabel, sig, offset, opcodes, patchbytecount);
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "gamedata/temp.memorypatcher.games.txt");
	gamedata.ExportToFile(path);
	delete gamedata;
	
	Handle gameConfig = LoadGameConfigFile("temp.memorypatcher.games");
	if(gameConfig == INVALID_HANDLE)
	{
		LogError("Can't find temp.memorypatcher.games.txt gamedata.");
		return MP_PATCH_ADD_ERROR_INVALID_TEMP_FILE;
	}

	g_hPatchGamedata.Push(gameConfig);
	return MP_PATCH_ADD_SUCCESS;
}

public int AddMemoryPatchEx(int ostype, int libtype, const char[] siglabel, char[] sig, int offset, int opcode, int patchbytecount)
{
	if(patchbytecount > MP_PATCH_MAX_OP_CODES)
	{
		LogError("Patching over %d bytes is not supported", MP_PATCH_MAX_OP_CODES);
		return MP_PATCH_ADD_ERROR_EXCEEDED_OP_CODE_COUNT;
	}
	
	if(MemoryPatchExists(siglabel))
	{
		LogError("Sig \"%s\" already exists!", siglabel);
		return MP_PATCH_ADD_ERROR_PATCH_EXISTS;
	}
	
	int[] opcodes = new int[patchbytecount];
	for (int i = 0; i < patchbytecount; i++)
		opcodes[i] = opcode;
		
	// big lol but works
	KeyValues gamedata = MP_GenerateGameDataKeyvalues(ostype, libtype, siglabel, sig, offset, opcodes, patchbytecount);
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "gamedata/temp.memorypatcher.games.txt");
	gamedata.ExportToFile(path);
	delete gamedata;
	
	Handle gameConfig = LoadGameConfigFile("temp.memorypatcher.games");
	if(gameConfig == INVALID_HANDLE)
	{
		LogError("Can't find temp.memorypatcher.games.txt gamedata.");
		return MP_PATCH_ADD_ERROR_INVALID_TEMP_FILE;
	}

	g_hPatchGamedata.Push(gameConfig);
	return MP_PATCH_ADD_SUCCESS;
}

public bool RemoveMemoryPatch(const char[] p_sigLabel)
{
	int index = -1;
	for (int i = 0; i < g_hPatchGamedata.Length; i++)
	{
		char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
		GameConfGetKeyValue(g_hPatchGamedata.Get(i), "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH);
		if(StrEqual(sigLabel, p_sigLabel, true))
		{
			index = i;
			break;
		}
	}
	
	if(index == -1)
		return false;
	
	if(IsPatchedByIndex(index))
		RestoreMemoryPatchByIndex(index);
	
	CloseHandle(g_hPatchGamedata.Get(index));
	g_hPatchGamedata.Erase(index);
	return true;
}

public bool MemoryPatchExists(const char[] p_sigLabel)
{
	for (int i = 0; i < g_hPatchGamedata.Length; i++)
	{
		char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
		GameConfGetKeyValue(g_hPatchGamedata.Get(i), "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH);
		if(StrEqual(sigLabel, p_sigLabel, true))
			return true;
	}
	return false;
}

public bool IsPatchedByLabel(const char[] p_sigLabel)
{
	int index = -1;
	for (int i = 0; i < g_hPatchGamedata.Length; i++)
	{
		char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
		GameConfGetKeyValue(g_hPatchGamedata.Get(i), "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH);
		if(StrEqual(sigLabel, p_sigLabel, true))
		{
			index = i;
			break;
		}
	}
	
	if(index == -1)
		return false;
	
	return IsPatchedByIndex(index);
}

public bool IsPatchedByIndex(int index)
{
	char sigLabel[PLATFORM_MAX_PATH];
	GameConfGetKeyValue(g_hPatchGamedata.Get(index), "siglabel", sigLabel, sizeof(sigLabel));
	
	char fullLabel[MP_PATCH_MAX_NAME_LENGTH + 16];
	Format(fullLabel, sizeof(fullLabel), "%s_Label", sigLabel);

	Address address = GameConfGetAddress(g_hPatchGamedata.Get(index), fullLabel);
	if(address == Address_Null)
	{
		LogError("Can't find \"%s\" address.", fullLabel);
		return false;
	}
	
	int offset = GameConfGetOffset(g_hPatchGamedata.Get(index), "PatchOffset");
	if(offset == -1)
	{
		LogError("Can't find \"PatchOffset\" in gamedata. (%s)", sigLabel);
		return false;
	}
	
	address += view_as<Address>(offset);
	
	int patchByteCount = GameConfGetOffset(g_hPatchGamedata.Get(index), "PatchByteCount");
	if(patchByteCount == -1)
	{
		LogError("Can't find \"PatchByteCount\" in gamedata. (%s)", sigLabel);
		return false;
	}

	int opcodes[MP_PATCH_MAX_OP_CODES];
	
	char szOpcodes[MP_PATCH_MAX_OP_CODES * 4];
	GameConfGetKeyValue(g_hPatchGamedata.Get(index), "opcodes", szOpcodes, MP_PATCH_MAX_OP_CODES * 4);
	MP_ByteStringArrayToIntArray(szOpcodes, opcodes, patchByteCount);
	
	int data;
	for(int i = 0; i < patchByteCount; i++)
	{
		data = LoadFromAddress(address, NumberType_Int8);
		if(data != opcodes[i])
			return false;
	}
	return true;
}

public int ApplyMemoryPatchByLabel(const char[] p_sigLabel)
{
	int index = -1;
	for (int i = 0; i < g_hPatchGamedata.Length; i++)
	{
		char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
		GameConfGetKeyValue(g_hPatchGamedata.Get(i), "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH);
		if(StrEqual(sigLabel, p_sigLabel, true))
		{
			index = i;
			break;
		}
	}
	
	if(index == -1)
		return MP_PATCH_APPLY_ERROR_NOT_FOUND;
		
	return ApplyMemoryPatchByIndex(index);
}

public int ApplyMemoryPatchByIndex(int index)
{
	if(IsPatchedByIndex(index))
		return MP_PATCH_APPLY_ERROR_IS_PATCHED;
	
	char sigLabel[PLATFORM_MAX_PATH];
	GameConfGetKeyValue(g_hPatchGamedata.Get(index), "siglabel", sigLabel, sizeof(sigLabel));
	
	char fullLabel[MP_PATCH_MAX_NAME_LENGTH + 16];
	Format(fullLabel, sizeof(fullLabel), "%s_Label", sigLabel);

	Address address = GameConfGetAddress(g_hPatchGamedata.Get(index), fullLabel);
	if(address == Address_Null)
	{
		LogError("Can't find \"%s\" address.", fullLabel);
		return MP_PATCH_APPLY_ERROR_UNKNOWN_ADDRESS;
	}
	
	int offset = GameConfGetOffset(g_hPatchGamedata.Get(index), "PatchOffset");
	if(offset == -1)
	{
		LogError("Can't find \"PatchOffset\" in gamedata. (%s)", sigLabel);
		return MP_PATCH_APPLY_ERROR_UNKNOWN_OFFSET;
	}
	
	address += view_as<Address>(offset);
	g_hPatchAddress.Push(address);
	
	
	int patchByteCount = GameConfGetOffset(g_hPatchGamedata.Get(index), "PatchByteCount");
	if(patchByteCount == -1)
	{
		LogError("Can't find \"PatchByteCount\" in gamedata. (%s)", sigLabel);
		return MP_PATCH_APPLY_ERROR_UNKNOWN_COUNT;
	}
	
	g_hPatchByteCount.Push(patchByteCount);
	
	int previousOpcodes[MP_PATCH_MAX_OP_CODES];
	int opcodes[MP_PATCH_MAX_OP_CODES];
	
	char szOpcodes[MP_PATCH_MAX_OP_CODES * 4];
	GameConfGetKeyValue(g_hPatchGamedata.Get(index), "opcodes", szOpcodes, MP_PATCH_MAX_OP_CODES * 4);
	
	MP_ByteStringArrayToIntArray(szOpcodes, opcodes, patchByteCount);
	
	int data;
	for(int i = 0; i < patchByteCount; i++)
	{
		data = LoadFromAddress(address, NumberType_Int8);
		previousOpcodes[i] = data;

		StoreToAddress(address, opcodes[i], NumberType_Int8);
		address++;
	}
	
	g_hPatchPreviousOPCodes.PushArray(previousOpcodes, patchByteCount);
	return MP_PATCH_APPLY_SUCCESS;
}

public bool RestoreMemoryPatchByLabel(const char[] p_sigLabel)
{
	int index = -1;
	for (int i = 0; i < g_hPatchGamedata.Length; i++)
	{
		char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
		GameConfGetKeyValue(g_hPatchGamedata.Get(i), "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH);
		if(StrEqual(sigLabel, p_sigLabel, true))
		{
			index = i;
			break;
		}
	}
	
	if(index == -1)
		return false;
		
	RestoreMemoryPatchByIndex(index);
	return true;
}

public void RestoreMemoryPatchByIndex(int index)
{
	Address addr = g_hPatchAddress.Get(index);
	int byteCount = g_hPatchByteCount.Get(index);
	
	int opcodes[MP_PATCH_MAX_OP_CODES];
	g_hPatchPreviousOPCodes.GetArray(index, opcodes, byteCount);
	
	if(addr != Address_Null)
	{
		for(int j = 0; j < byteCount; j++)
			StoreToAddress(addr + view_as<Address>(j), opcodes[j], NumberType_Int8);
	}
	
	g_hPatchAddress.Erase(index);
	g_hPatchByteCount.Erase(index);
	g_hPatchPreviousOPCodes.Erase(index);
}
