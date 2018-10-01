#pragma semicolon 1

//#define DEBUG
#pragma dynamic 131072

#define PLUGIN_AUTHOR "Rachnus"
#define PLUGIN_VERSION "1.01"

#include <sourcemod>
#include <sdktools>
#include <memorypatcher>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Memory Patcher v1.01",
	author = PLUGIN_AUTHOR,
	description = "Patch memory and stuff",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rachnus"
};


StringMap g_hPatchIndices = 			null;				// Used to map patchgamedata siglabels with restore arraylists
bool g_bPatched = 						false;				// Used to check if we've already patched everything on OnMemoryPatcherReady forward

int g_iServerOS = 						OSType_Invalid;		// Servers OS 					(Cached in temp.memorypatcher.txt by default)

ArrayList g_hPatchGamedata =   			null;				// Stores all gamedata handles 	(IGameConfig)

ArrayList g_hPatchAddress =  			null;				// Patch addresses 				(Used to restore patches)
ArrayList g_hPatchByteCount =  			null;				// Patch byte count 			(Used to restore patches)
ArrayList g_hPatchPreviousOPCodes =  	null;				// Patch previous op codes		(Used to restore patches)

Handle g_hOnMemoryPatcherReady;								// Forward used to patch from other plugins

public void OnPluginStart()
{
	HookEvent("server_spawn", Event_ServerSpawn);
	
	g_hOnMemoryPatcherReady = CreateGlobalForward("MP_OnMemoryPatcherReady", ET_Ignore);
	
	RegAdminCmd("sm_mp_patchall", 	Command_PatchAll, 		ADMFLAG_ROOT, "Patch all existing memory patches");
	RegAdminCmd("sm_mp_restoreall", Command_RestoreAll, 	ADMFLAG_ROOT, "Restore all existing memory patches");
	RegAdminCmd("sm_mp_patch", 		Command_Patch, 			ADMFLAG_ROOT, "Patch a single memory patch by siglabel");
	RegAdminCmd("sm_mp_restore", 	Command_Restore, 		ADMFLAG_ROOT, "Restore a single memory patch by siglabel");
	RegAdminCmd("sm_mp_status", 	Command_Status, 		ADMFLAG_ROOT, "Print out status of existing memory patches");
	RegAdminCmd("sm_mp_refresh", 	Command_Refresh, 		ADMFLAG_ROOT, "Read from gamedata folder (gamedata/memorypatcher.games/)");
	InitPatchLists();
	
	g_hPatchIndices = new StringMap();
}

public void OnAllPluginsLoaded()
{
	GetServerOS();
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
	CreateNative("MP_GetMemoryPatchSigLabel", Native_GetMemoryPatchSigLabel);
	
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
	PrintToServer("wat6");
	char siglabel[MP_PATCH_MAX_NAME_LENGTH];
	GetNativeString(1, siglabel, MP_PATCH_MAX_NAME_LENGTH);
	PrintToServer("wat5");
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

public int Native_GetMemoryPatchSigLabel(Handle plugin, int numParams)
{
	char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
	GameConfGetKeyValue(g_hPatchGamedata.Get(GetNativeCell(1)), "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH);
	SetNativeString(2, sigLabel, GetNativeCell(3));
}

public void OnPluginEnd()
{
	RestoreMemoryPatchAll();
}

public Action Command_Patch(int client, int args)
{
	if(args <= 0)
	{
		ReplyToCommand(client, "%s Usage: \x04sm_mp_patch <siglabel>", MP_PREFIX);
		return Plugin_Handled;
	}
	
	char arg[MP_PATCH_MAX_SIG_LENGTH];
	GetCmdArgString(arg, MP_PATCH_MAX_SIG_LENGTH);
	PrintToServer("wat1");
	int errorCode = ApplyMemoryPatchByLabel(arg);
	PrintToServer("wat2");
	char szCode[32];
	MP_GetApplyErrorCodeString(errorCode, szCode, sizeof(szCode));
	PrintToChat(client, "%s APPLY PATCH: \x03%s \x09(\x04code: %d\x09) %s", MP_PREFIX, arg, errorCode, szCode);
	
	return Plugin_Handled;
}

public Action Command_PatchAll(int client, int args)
{
	ApplyMemoryPatchAll();
	Command_Status(client, 0);
	
	return Plugin_Handled;
}

public Action Command_Restore(int client, int args)
{
	if(args <= 0)
	{
		ReplyToCommand(client, "%s Usage: \x04sm_mp_restore <siglabel>", MP_PREFIX);
		return Plugin_Handled;
	}
	
	char arg[MP_PATCH_MAX_SIG_LENGTH];
	GetCmdArgString(arg, MP_PATCH_MAX_SIG_LENGTH);
	
	int errorCode = RestoreMemoryPatchByLabel(arg);
	
	char szCode[32];
	MP_GetRestoreErrorCodeString(errorCode, szCode, sizeof(szCode));
	PrintToChat(client, "%s RESTORE PATCH: \x03%s \x09(\x04code: %d\x09) %s", MP_PREFIX, arg, errorCode, szCode);
	
	return Plugin_Handled;
}

public Action Command_RestoreAll(int client, int args)
{
	RestoreMemoryPatchAll();
	Command_Status(client, 0);
	
	return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
	if(g_hPatchGamedata.Length <= 0)
	{
		ReplyToCommand(client, "%s No memory patches found", MP_PREFIX);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < g_hPatchGamedata.Length; i++)
	{
		bool patched = IsPatchedByIndex(i);
		char siglabel[MP_PATCH_MAX_NAME_LENGTH];
		GameConfGetKeyValue(g_hPatchGamedata.Get(i), "siglabel", siglabel, MP_PATCH_MAX_NAME_LENGTH);
		
		ReplyToCommand(client, "%s \x03%s\x09 - %s%s", MP_PREFIX, siglabel, patched ? "\x04":"\x07", patched ? "PATCHED":"NOT PATCHED");
	}
	return Plugin_Handled;
}

public Action Command_Refresh(int client, int args)
{
	LoadPredefinedMemoryPatches();
	ReplyToCommand(client, "%s Predefined memory patches refreshed", MP_PREFIX);
	return Plugin_Handled;
}

public Action Event_ServerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	char os[32];
	event.GetString("os", os, sizeof(os));
	OnServerOSKnown(os);
}	

public void InitPatchLists()
{
	g_hPatchGamedata = new ArrayList();
	
	g_hPatchAddress = new ArrayList();
	g_hPatchByteCount = new ArrayList();
	g_hPatchPreviousOPCodes = new ArrayList(MP_PATCH_MAX_OP_CODES);
}

public void GetServerOS()
{
	if(!FileExists(MP_TEMP_FILE, true))
		return;
	
	File serverOsFile = OpenFile(MP_TEMP_FILE, "r");
	if(!serverOsFile)
	{
#if defined DEBUG
		MP_Debug("Could not find temp file \"%s\"", MP_TEMP_FILE);
#endif
		return;
	}
	
	char os[32];
	ReadFileLine(serverOsFile, os, sizeof(os));
	delete serverOsFile;
	
	OnServerOSKnown(os);
}

public void OnServerOSKnown(const char[] os)
{
	g_iServerOS = MP_GetOSTypeByName(os);
	
#if defined DEBUG
	MP_Debug("Server OS KNOWN: %s", os);
#endif
	if(!g_bPatched)
	{
		File serverOsFile = OpenFile(MP_TEMP_FILE, "w");
		if(!serverOsFile)
		{
#if defined DEBUG
			MP_Debug("Could not find temp file \"%s\"", MP_TEMP_FILE);
#endif
			return;
		}
		
		WriteFileLine(serverOsFile, os);
		delete serverOsFile;
		
		LoadPredefinedMemoryPatches();
		Call_StartForward(g_hOnMemoryPatcherReady);
		Call_Finish();
		g_bPatched = true;
	}
}

public int LoadPredefinedMemoryPatches()
{
	char memoryPatcherDir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, memoryPatcherDir, sizeof(memoryPatcherDir), "gamedata/%s/", MP_GAMEDATA_DIR);
	
	if(!DirExists(memoryPatcherDir, true))
	{
		PrintToServer("%s Path \"%s\" does not exist.", MP_DEBUG_PREFIX, memoryPatcherDir);
		PrintToServer("%s Skipping reading predefined memory patches", MP_DEBUG_PREFIX, memoryPatcherDir);
		return -1;
	}
	
	DirectoryListing dirList = OpenDirectory(memoryPatcherDir, true);
	if(dirList == INVALID_HANDLE)
	{
		LogError("%s Invalid directory \"%s\"", MP_DEBUG_PREFIX, ".");
		return -1;
	}
	
	char fileName[PLATFORM_MAX_PATH];
	FileType type;
	
	int count = 0;

	while(dirList.GetNext(fileName, PLATFORM_MAX_PATH, type))
	{
		if(type == FileType_File && (StrContains(fileName, ".games.txt", false) != -1))
		{
			ReplaceString(fileName, sizeof(fileName), ".txt", "", true);
			
			char fullPath[PLATFORM_MAX_PATH];
			Format(fullPath, sizeof(fullPath), "%s/%s", MP_GAMEDATA_DIR, fileName);

			Handle gameConfig = LoadGameConfigFile(fullPath);
			if(gameConfig == INVALID_HANDLE)
			{
				delete gameConfig;
				LogError("Can't find \"%s\" gamedata.", fullPath);
				continue;
			}
			
#if defined DEBUG
			MP_Debug("Gamedata \"%s\" found!", fullPath);
#endif
			
			char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
			if(!GameConfGetKeyValue(gameConfig, "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH))
			{
				delete gameConfig;
				LogError("Can't find \"siglabel\" key");
				continue;
			}
			
			char opcodesLabel[32];
			MP_GetOSTypeName(g_iServerOS, opcodesLabel, sizeof(opcodesLabel));
			Format(opcodesLabel, sizeof(opcodesLabel), "opcodes_%s", opcodesLabel);
			
			char temp[16];
			if(!GameConfGetKeyValue(gameConfig, opcodesLabel, temp, sizeof(temp)))
			{
				delete gameConfig;
				LogError("Can't find \"%s\" key", opcodesLabel);
				continue;
			}
#if defined DEBUG
			MP_Debug("Found memory patch \"%s\"", sigLabel);
#endif
			if(MemoryPatchExists(sigLabel))
			{
#if defined DEBUG
				MP_Debug("Memory patch \"%s\" already exists", sigLabel);
#endif
				delete gameConfig;
				continue;
			}
			
			g_hPatchGamedata.Push(gameConfig);
			if(ApplyMemoryPatchByLabel(sigLabel) >= MP_PATCH_APPLY_SUCCESS)
			{
#if defined DEBUG
				MP_Debug("Memory patch \"%s\" applied!", sigLabel);
#endif
				count++;
			}
		}
	}
	
#if defined DEBUG
	if(count <= 0)
		MP_Debug("No predefined memory patches found");
#endif
	return count;
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
		if(ApplyMemoryPatchByIndex(i) >= MP_PATCH_APPLY_SUCCESS)
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
	
	char opcodesLabel[32];
	MP_GetOSTypeName(g_iServerOS, opcodesLabel, sizeof(opcodesLabel));
	Format(opcodesLabel, sizeof(opcodesLabel), "opcodes_%s", opcodesLabel);
	
	char szOpcodes[MP_PATCH_MAX_OP_CODES * 4];
	GameConfGetKeyValue(g_hPatchGamedata.Get(index), opcodesLabel, szOpcodes, MP_PATCH_MAX_OP_CODES * 4);
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
	PrintToServer("wat3");
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
	
	
	int patchByteCount = GameConfGetOffset(g_hPatchGamedata.Get(index), "PatchByteCount");
	if(patchByteCount == -1)
	{
		LogError("Can't find \"PatchByteCount\" in gamedata. (%s)", sigLabel);
		return MP_PATCH_APPLY_ERROR_UNKNOWN_COUNT;
	}

	g_hPatchAddress.Push(address);
	g_hPatchByteCount.Push(patchByteCount);
	
	int previousOpcodes[MP_PATCH_MAX_OP_CODES];
	int opcodes[MP_PATCH_MAX_OP_CODES];
	
	char opcodesLabel[32];
	MP_GetOSTypeName(g_iServerOS, opcodesLabel, sizeof(opcodesLabel));
	Format(opcodesLabel, sizeof(opcodesLabel), "opcodes_%s", opcodesLabel);
	
	char szOpcodes[MP_PATCH_MAX_OP_CODES * 4];
	GameConfGetKeyValue(g_hPatchGamedata.Get(index), opcodesLabel, szOpcodes, MP_PATCH_MAX_OP_CODES * 4);

#if defined DEBUG
	MP_Debug("(%s) OPCODE LENGTH: %d/%d", sigLabel, strlen(szOpcodes), MP_PATCH_MAX_OP_CODES * 4);
#endif
	
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
	g_hPatchIndices.SetValue(sigLabel, g_hPatchAddress.Length - 1);
	return MP_PATCH_APPLY_SUCCESS;
}

public int RestoreMemoryPatchByLabel(const char[] p_sigLabel)
{
	int gamedataIndex = -1;
	
	for (int i = 0; i < g_hPatchGamedata.Length; i++)
	{
		char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
		GameConfGetKeyValue(g_hPatchGamedata.Get(i), "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH);
		if(StrEqual(sigLabel, p_sigLabel, true))
		{
			gamedataIndex = i;
			break;
		}
	}
	
	if(gamedataIndex == -1)
		return MP_PATCH_RESTORE_ERROR_NOT_FOUND;
		
	return RestoreMemoryPatchByIndex(gamedataIndex);
}

public int RestoreMemoryPatchByIndex(int index)
{
	if(!IsPatchedByIndex(index))
		return MP_PATCH_RESTORE_ERROR_IS_RESTORED;
		
	char sigLabel[MP_PATCH_MAX_NAME_LENGTH];
	GameConfGetKeyValue(g_hPatchGamedata.Get(index), "siglabel", sigLabel, MP_PATCH_MAX_NAME_LENGTH);
	
	int restoreIndex = -1;
	if(!g_hPatchIndices.GetValue(sigLabel, restoreIndex))
	{
		LogError("Could not find patch index for siglabel \"%s\"", sigLabel);
		return MP_PATCH_RESTORE_ERROR_INDEX_NOT_FOUND;
	}
	
	Address addr = g_hPatchAddress.Get(restoreIndex);
	int byteCount = g_hPatchByteCount.Get(restoreIndex);
	
	int opcodes[MP_PATCH_MAX_OP_CODES];
	g_hPatchPreviousOPCodes.GetArray(restoreIndex, opcodes, byteCount);
	
	if(addr != Address_Null)
	{
		for(int j = 0; j < byteCount; j++)
			StoreToAddress(addr + view_as<Address>(j), opcodes[j], NumberType_Int8);
	}

	g_hPatchAddress.Erase(restoreIndex);
	g_hPatchByteCount.Erase(restoreIndex);
	g_hPatchPreviousOPCodes.Erase(restoreIndex);
	
	g_hPatchIndices.Remove(sigLabel);
	
	return MP_PATCH_RESTORE_SUCCESS;
}
