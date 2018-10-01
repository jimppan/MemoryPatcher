#if defined _memorypatcher_included
 #endinput
#endif

#define _memorypatcher_included

#define MP_PREFIX						" \x09[\x04MemoryPatcher\x09]"
#define MP_GAMEDATA_DIR					"memorypatcher.games"
#define MP_DEBUG_PREFIX					"[memorypatcher.smx]"
#define MP_TEMP_FILE					"temp.memorypatcher.txt"
#define MP_PATCH_MAX_NAME_LENGTH 		32
#define MP_PATCH_MAX_SIG_LENGTH 		256
#define MP_PATCH_MAX_OP_CODES			2048

enum//OSType
{
	OSType_Invalid = 0,
	OSType_Windows,
	OSType_Linux,
	OSType_Mac,
	
	OSType_MAX,
}

enum//LIBType
{
	LIBType_Server = 0,
	LIBType_Engine,
	
	LIBType_MAX,
}

enum//AddMemoryPatchError
{
	MP_PATCH_ADD_ERROR_EXCEEDED_OP_CODE_COUNT = 	-2,			// Memory patch is too large
	MP_PATCH_ADD_ERROR_PATCH_EXISTS = 				-1,			// Memory patch already exists
	MP_PATCH_ADD_ERROR_INVALID_TEMP_FILE = 			0,			// Should never happend, temp file could not be created (no permissions?)
	MP_PATCH_ADD_SUCCESS = 							1,			// If memory patch was successfully added
}

enum//ApplyMemoryPatchError
{
	MP_PATCH_APPLY_ERROR_NOT_FOUND = 				-4,			// Memory patch sig label was not found
	MP_PATCH_APPLY_ERROR_IS_PATCHED = 				-3,			// Memory patch was already applied
	MP_PATCH_APPLY_ERROR_UNKNOWN_ADDRESS = 			-2,			// Could not find the sig
	MP_PATCH_APPLY_ERROR_UNKNOWN_OFFSET = 			-1,			// Should never happend, could not find offset in config file
	MP_PATCH_APPLY_ERROR_UNKNOWN_COUNT = 			0,			// Should never happend, could not find patch byte count
	MP_PATCH_APPLY_SUCCESS = 						1			// If memory patch was successfully applied
}

enum//RestoreMemoryPatchError
{
	MP_PATCH_RESTORE_ERROR_INDEX_NOT_FOUND =		-2,			// Should never happend, patch index was not found in stringmap
	MP_PATCH_RESTORE_ERROR_NOT_FOUND = 				-1,			// Memory patch sig label was not found
	MP_PATCH_RESTORE_ERROR_IS_RESTORED = 			0,			// Memory patch was already restored
	MP_PATCH_RESTORE_SUCCESS = 						1			// If memory patch was successfully restored

}

/**
 * Get server Operating System
 * 
 * @return int				ostype
 */
native int MP_GetServerOSType();

/**
 * Add a memory patch which can be patched or restored at any time
 * 
 * @param ostype			which OS is this sig for (see OSType above)
 * @param libtype			which libtype is this sig for (see LIBType above)
 * @param siglabel			label of your sig
 * @param sig				function signature
 * @param offset			offset inside the function
 * @param opcodes			an array containing all opcodes you want to patch the function with
 * @param patchbytecount	amount of bytes to patch
 * @return int				memory patch error code (see MemoryPatchError above)
 */
native int MP_AddMemoryPatch(int ostype, int libtype, const char[] siglabel, char[] sig, int offset, int[] opcodes, int patchbytecount);

/**
 * Add a memory patch which can be patched or restored at any time (Single OP code instead of array of opcodes)
 * 
 * @param ostype			which OS is this sig for (see OSType above)
 * @param libtype			which libtype is this sig for (see LIBType above)
 * @param siglabel			label of your sig
 * @param sig				function signature
 * @param offset			offset inside the function
 * @param opcode			the opcode you wanna patch with
 * @param patchbytecount	amount of bytes to patch
 * @return int				memory patch error code (see MemoryPatchError above)
 */
native int MP_AddMemoryPatchEx(int ostype, int libtype, const char[] siglabel, char[] sig, int offset, int opcode, int patchbytecount);

/**
 * Remove a memory patch (this also restores it to its previous state automatically)
 * 
 * @param siglabel			label of your sig
 * @return bool				true if removed, false if not found
 */
native bool MP_RemoveMemoryPatch(const char[] siglabel);

/**
 * Check if memory patch exists by label
 * 
 * @param siglabel			siglabel string
 * @return bool				true if exist
 */
native bool MP_MemoryPatchExists(const char[] siglabel);

/**
 * Check if existing memory patch was patched
 * 
 * @param siglabel			siglabel string
 * @return bool				true if patched, false if not found or if not patched
 */
native bool MP_IsPatched(const char[] siglabel);

/**
 * Patch all existing memory patches
 *
 * @return int				amount patched
 */
native int MP_PatchAll();

/**
 * Restores all patches to their original state
 *
 * @return int				amount restored
 */
native int MP_RestoreAll();

/**
 * Patch existing memory patch by sig label
 *
 * @return int				patch error code (see ApplyMemoryPatchError above)
 */
native int MP_Patch(const char[] siglabel);

/**
 * Restores existing memory patch by sig label
 *
 * @return bool				true if restored, false if not found
 */
native bool MP_Restore(const char[] siglabel);

/**
 * Returns amount of existing memory patches added to the plugin
 *
 * @return int				memory patch count
 */
native int MP_GetMemoryPatchCount();

/**
 * Returns amount of existing memory patches added to the plugin
 *
 * @return int				memory patch count
 */
native int MP_GetMemoryPatchSigLabel(int index, char[] buffer, int maxlen);

/**
 * AddMemoryPatch or AddMemoryPatchEx should be called here or later (This is called server_spawn event)
 *
 * @return void
 */
forward void MP_OnMemoryPatcherReady();

public KeyValues MP_GenerateGameDataKeyvalues(int ostype, int libtype, const char[] siglabel, char[] sig, int offset, int[] opcodes, int opcodecount)
{
	KeyValues conf = new KeyValues("Games");
	
	char game[32];
	GetGameFolderName(game, sizeof(game));
	conf.JumpToKey(game, true);
	conf.JumpToKey("Addresses", true);
	
	char sigNameLabel[MP_PATCH_MAX_NAME_LENGTH + 16];
	Format(sigNameLabel, sizeof(sigNameLabel), "%s_Label", siglabel);
	conf.JumpToKey(sigNameLabel, true);
	
	char szOsType[16], szLibType[16];
	MP_GetOSTypeName(ostype, szOsType, sizeof(szOsType));
	MP_GetLIBTypeName(libtype, szLibType, sizeof(szLibType));
	
	conf.JumpToKey(szOsType, true);
	conf.SetString("signature", siglabel);
	
	// Go back to SigLabel
	conf.GoBack();
	
	// Go back to Addresses
	conf.GoBack();
	
	// Go back to game version
	conf.GoBack();
	
	conf.JumpToKey("Signatures", true);
	conf.JumpToKey(siglabel, true);
	conf.SetString("library", szLibType);
	conf.SetString(szOsType, sig);
	
	// Go back to Signatures
	conf.GoBack();
	
	// Go back to game version
	conf.GoBack();
	
	conf.JumpToKey("Offsets", true);
	conf.JumpToKey("PatchOffset", true);
	conf.SetNum(szOsType, offset);
	
	// Go back to Offsets
	conf.GoBack();
	
	conf.JumpToKey("PatchByteCount", true);
	conf.SetNum(szOsType, opcodecount);
	
	// Go back to Offsets
	conf.GoBack();
	
	// Go back to game version
	conf.GoBack();
	
	conf.JumpToKey("Keys", true);
	
	char[] szOPcodes = new char[opcodecount * 4 + 1]; // One OP code is 2 characters (NOP = 90) add 2 more characters to that '\x'
	for (int i = 0; i < opcodecount; i++)
		Format(szOPcodes[i * 4], opcodecount * 4, "\\x%x", opcodes[i]);
	szOPcodes[opcodecount * 4] = '\0';

	char opcodesLabel[32];
	Format(opcodesLabel, sizeof(opcodesLabel), "opcodes_%s", szOsType);

	conf.SetString(opcodesLabel, szOPcodes);
	conf.SetString("siglabel", siglabel);
	conf.Rewind();
	return conf;
}

public void MP_ByteStringArrayToIntArray(const char[] byteStringArray, int[] opcodes, int opcodeLength)
{
	int byteStringLength = strlen(byteStringArray);
#if defined DEBUG#
	MP_Debug("(BYTE STRLEN: %d) (OPCODELENGTH: %d)", byteStringLength, opcodeLength);
#endif	
	int opcode = 0;
	for (int i = 0; i < byteStringLength; i++)
	{
		if(byteStringArray[i] == 'x')
		{
			char szHex[3];
			szHex[0] = byteStringArray[i + 1];
			szHex[1] = byteStringArray[i + 2];
			szHex[2] = '\0';
			opcode = StringToInt(szHex, 16);
			opcodes[RoundToFloor(float(i) / 4.0)] = opcode;
#if defined DEBUG
			MP_Debug("OPCODE: %x (%d)", opcode, opcode);
#endif
		}
	}
	
	int itMax = opcodeLength * 4;
	if(byteStringLength < itMax)
	{
#if defined DEBUG
		MP_Debug("Not enough OPcodes to satisfy array, extending last op code (%x)", opcode);
#endif
		for (int i = RoundToFloor(float(byteStringLength) / float(4)); i < opcodeLength; i++)
		{
			opcodes[i] = opcode;
#if defined DEBUG
			MP_Debug("EXTENDED OPCODE: %x (%d)", opcode, opcode);
#endif
		}
	}
}

public void MP_GetRestoreErrorCodeString(int errorCode, char[] buffer, int maxlen)
{
	switch(errorCode)
	{
		case MP_PATCH_RESTORE_ERROR_INDEX_NOT_FOUND:
		{
			Format(buffer, maxlen, "Invalid patch index");
		}
		case MP_PATCH_RESTORE_ERROR_NOT_FOUND:
		{
			Format(buffer, maxlen, "Not found");
		}
		case MP_PATCH_RESTORE_ERROR_IS_RESTORED:
		{
			Format(buffer, maxlen, "Already restored");
		}
		case MP_PATCH_RESTORE_SUCCESS:
		{
			Format(buffer, maxlen, "Success");
		}
	}
}

public void MP_GetApplyErrorCodeString(int errorCode, char[] buffer, int maxlen)
{
	switch(errorCode)
	{
		case MP_PATCH_APPLY_ERROR_NOT_FOUND:
		{
			Format(buffer, maxlen, "Not found");
		}
		case MP_PATCH_APPLY_ERROR_IS_PATCHED:
		{
			Format(buffer, maxlen, "Already patched");
		}
		case MP_PATCH_APPLY_ERROR_UNKNOWN_ADDRESS:
		{
			Format(buffer, maxlen, "Invalid address");
		}
		case MP_PATCH_APPLY_ERROR_UNKNOWN_OFFSET:
		{
			Format(buffer, maxlen, "Offset not found");
		}
		case MP_PATCH_APPLY_ERROR_UNKNOWN_COUNT:
		{
			Format(buffer, maxlen, "Patch byte count not found");
		}
		case MP_PATCH_APPLY_SUCCESS:
		{
			Format(buffer, maxlen, "Success");
		}
	}
}

public int MP_GetOSTypeByName(const char[] os)
{
	if(StrContains(os, "WIN32", false) != -1)
		return OSType_Windows;
	else if(StrContains(os, "LINUX", false) != -1)
		return OSType_Linux;
	else
		return OSType_Mac;
}

public void MP_GetOSTypeName(int ostype, char[] buffer, int maxlen)
{
	switch(ostype)
	{
		case OSType_Windows:
		{
			Format(buffer, maxlen, "windows");
		}
		case OSType_Linux:
		{
			Format(buffer, maxlen, "linux");
		}
		case OSType_Mac:
		{
			Format(buffer, maxlen, "mac");
		}
		default:
		{
			LogError("OSType: %d is invalid", ostype);
		}
	}
}

public void MP_GetLIBTypeName(int libtype, char[] buffer, int maxlen)
{
	switch(libtype)
	{
		case LIBType_Server:
		{
			Format(buffer, maxlen, "server");
		}
		case LIBType_Engine:
		{
			Format(buffer, maxlen, "engine");
		}
		default:
		{
			LogError("LIBType: %d is invalid", libtype);
		}
	}
}

public bool MP_IsValidOSType(int ostype)
{
	return ostype >= 0 && ostype < OSType_MAX;
}

public bool MP_IsValidLIBType(int libtype)
{
	return libtype >= 0 && libtype < LIBType_MAX;
}

public void MP_Debug(const char[] message, any ...)
{
	char szBuffer[254];
	VFormat(szBuffer, sizeof(szBuffer), message, 2);
	
	PrintToChatAll("%s %s", MP_DEBUG_PREFIX, szBuffer);
	PrintToServer("%s %s", MP_DEBUG_PREFIX, szBuffer);
}

public SharedPlugin __pl_memorypatcher  =
{
	name = "memorypatcher",
	file = "memorypatcher.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_memorypatcher_SetNTVOptional()
{	
	MarkNativeAsOptional("MP_GetServerOSType");
	MarkNativeAsOptional("MP_AddMemoryPatch");
	MarkNativeAsOptional("MP_AddMemoryPatchEx");
	MarkNativeAsOptional("MP_RemoveMemoryPatch");
	MarkNativeAsOptional("MP_MemoryPatchExists");
	MarkNativeAsOptional("MP_IsPatched");
	MarkNativeAsOptional("MP_PatchAll");
	MarkNativeAsOptional("MP_Patch");
	MarkNativeAsOptional("MP_Restore");
	MarkNativeAsOptional("MP_GetMemoryPatchCount");
	MarkNativeAsOptional("MP_GetMemoryPatchSigLabel");
}
#endif