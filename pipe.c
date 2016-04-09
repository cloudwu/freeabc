#include <windows.h>
#include <Lmcons.h> // for UNLEN
#include <Winnt.h> // for security attributes constants
#include <aclapi.h> // for ACL
#include <string.h>
#include <stdio.h>

static PSECURITY_DESCRIPTOR g_securittyDescriptor = NULL;
static SECURITY_ATTRIBUTES g_securityAttributes = {0};
static PACL g_acl = NULL;
static EXPLICIT_ACCESSA g_explicitAccesses[2];
static PSID g_everyoneSID = NULL;
static PSID g_allAppsSID = NULL;

static void
init() {
	// create security attributes for the pipe
	// http://msdn.microsoft.com/en-us/library/windows/desktop/hh448449(v=vs.85).aspx
	// define new Win 8 app related constants
	memset(&g_explicitAccesses, 0, sizeof(g_explicitAccesses));
	// Create a well-known SID for the Everyone group.
	// FIXME: we should limit the access to current user only
	// See this article for details: https://msdn.microsoft.com/en-us/library/windows/desktop/hh448493(v=vs.85).aspx

	SID_IDENTIFIER_AUTHORITY worldSidAuthority = {SECURITY_WORLD_SID_AUTHORITY};
	AllocateAndInitializeSid(&worldSidAuthority, 1,
		SECURITY_WORLD_RID, 0, 0, 0, 0, 0, 0, 0, &g_everyoneSID);

	// https://services.land.vic.gov.au/ArcGIS10.1/edESRIArcGIS10_01_01_3143/Python/pywin32/PLATLIB/win32/Demos/security/explicit_entries.py

	g_explicitAccesses[0].grfAccessPermissions = GENERIC_ALL;
	g_explicitAccesses[0].grfAccessMode = SET_ACCESS;
	g_explicitAccesses[0].grfInheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT;
	g_explicitAccesses[0].Trustee.pMultipleTrustee = NULL;
	g_explicitAccesses[0].Trustee.MultipleTrusteeOperation = NO_MULTIPLE_TRUSTEE;
	g_explicitAccesses[0].Trustee.TrusteeForm = TRUSTEE_IS_SID;
	g_explicitAccesses[0].Trustee.TrusteeType = TRUSTEE_IS_WELL_KNOWN_GROUP;
	g_explicitAccesses[0].Trustee.ptstrName = (LPTSTR)g_everyoneSID;

	// FIXME: will this work under Windows 7 and Vista?
	// create SID for app containers
	SID_IDENTIFIER_AUTHORITY appPackageAuthority = {SECURITY_APP_PACKAGE_AUTHORITY};
	AllocateAndInitializeSid(&appPackageAuthority,
		SECURITY_BUILTIN_APP_PACKAGE_RID_COUNT,
		SECURITY_APP_PACKAGE_BASE_RID,
		SECURITY_BUILTIN_PACKAGE_ANY_PACKAGE,
		0, 0, 0, 0, 0, 0, &g_allAppsSID);

	g_explicitAccesses[1].grfAccessPermissions = GENERIC_ALL;
	g_explicitAccesses[1].grfAccessMode = SET_ACCESS;
	g_explicitAccesses[1].grfInheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT;
	g_explicitAccesses[1].Trustee.pMultipleTrustee = NULL;
	g_explicitAccesses[1].Trustee.MultipleTrusteeOperation = NO_MULTIPLE_TRUSTEE;
	g_explicitAccesses[1].Trustee.TrusteeForm = TRUSTEE_IS_SID;
	g_explicitAccesses[1].Trustee.TrusteeType = TRUSTEE_IS_GROUP;
	g_explicitAccesses[1].Trustee.ptstrName = (LPTSTR)g_allAppsSID;

	// create DACL
	DWORD err = SetEntriesInAcl(2, g_explicitAccesses, NULL, &g_acl);
	if (0 == err) {
		// security descriptor
		g_securittyDescriptor = (PSECURITY_DESCRIPTOR)LocalAlloc(LPTR, SECURITY_DESCRIPTOR_MIN_LENGTH);
		InitializeSecurityDescriptor(g_securittyDescriptor, SECURITY_DESCRIPTOR_REVISION);

		// Add the ACL to the security descriptor. 
		SetSecurityDescriptorDacl(g_securittyDescriptor, TRUE, g_acl, FALSE);
	}

	g_securityAttributes.nLength = sizeof(SECURITY_ATTRIBUTES);
	g_securityAttributes.lpSecurityDescriptor = g_securittyDescriptor;
	g_securityAttributes.bInheritHandle = TRUE;
}

static void 
cleanup() {
	if(g_everyoneSID != NULL)
		FreeSid(g_everyoneSID);
	if (g_allAppsSID != NULL)
		FreeSid(g_allAppsSID);
	if (g_securittyDescriptor != NULL)
		LocalFree(g_securittyDescriptor);
	if (g_acl != NULL)
		LocalFree(g_acl);
}

// References:
// https://msdn.microsoft.com/en-us/library/windows/desktop/aa365588(v=vs.85).aspx
static HANDLE
connect_pipe(const char* app_name) {
	HANDLE pipe = INVALID_HANDLE_VALUE;
	char username[UNLEN + 1];
	DWORD unlen = UNLEN + 1;
	if (GetUserNameA(username, &unlen)) {
		// add username to the pipe path so it will not clash with other users' pipes.
		char pipe_name[MAX_PATH];
		sprintf(pipe_name, "\\\\.\\pipe\\%s\\%s_pipe", username, app_name);
		const size_t buffer_size = 1024;
		// create the pipe
		pipe = CreateNamedPipeA(pipe_name,
			PIPE_ACCESS_DUPLEX,
			PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
			PIPE_UNLIMITED_INSTANCES,
			buffer_size,
			buffer_size,
			NMPWAIT_USE_DEFAULT_WAIT,
			&g_securityAttributes);

		if (pipe != INVALID_HANDLE_VALUE) {
			// try to connect to the named pipe
			// NOTE: this is a blocking call
			if (FALSE == ConnectNamedPipe(pipe, NULL)) {
				// fail to connect the pipe
				CloseHandle(pipe);
				pipe = INVALID_HANDLE_VALUE;
			}
		}
	}
	return pipe;
}

static void
close_pipe(HANDLE pipe) {
	FlushFileBuffers(pipe);
	DisconnectNamedPipe(pipe);
	CloseHandle(pipe);
}

static int
read_pipe(HANDLE pipe, char* buf, unsigned long len, unsigned long* error) {
	DWORD read_len = 0;
	BOOL success = ReadFile(pipe, buf, len, &read_len, NULL);
	if (error != NULL)
		*error = success ? 0 : (unsigned long)GetLastError();
	return (int)read_len;
}

static int
write_pipe(HANDLE pipe, const char* data, unsigned long len, unsigned long* error) {
	DWORD write_len = 0;
	BOOL success = WriteFile(pipe, data, len, &write_len, NULL);
	if (error != NULL)
		*error = success ? 0 : (unsigned long)GetLastError();
	return (int)write_len;
}

BOOL APIENTRY
DllMain(HMODULE hModule, DWORD  ul_reason_for_call, LPVOID lpReserved) {
	switch (ul_reason_for_call) {
	case DLL_PROCESS_ATTACH:
		DisableThreadLibraryCalls(hModule); // disable DllMain calls due to new thread creation
		init();
		break;
	case DLL_PROCESS_DETACH:
		cleanup();
		break;
	}
	return TRUE;
}

#include <lua.h>
#include <lauxlib.h>

static int
lconnect(lua_State *L) {
	HANDLE pipe = connect_pipe(luaL_checkstring(L,1));
	if (pipe == INVALID_HANDLE_VALUE)
		return luaL_error(L, "connect failed");
	lua_pushlightuserdata(L, pipe);
	return 1;
}

static int
lclose(lua_State *L) {
	HANDLE pipe = lua_touserdata(L, 1);
	if (pipe == NULL)
		return luaL_error(L, "invalid pipe");
	close_pipe(pipe);
	return 0;
}

#define READ_SIZE 1024

static int
lread(lua_State *L) {
	HANDLE pipe = lua_touserdata(L, 1);
	unsigned long error = 0;
	char tmp[READ_SIZE];
	int rd = read_pipe(pipe, tmp, READ_SIZE, &error);
	if (error == ERROR_MORE_DATA) {
		luaL_Buffer b;
		luaL_buffinitsize(L, &b, 2*READ_SIZE);
		luaL_addlstring(&b, tmp, rd);
		for (;;) {
			char * tmp = luaL_prepbuffsize(&b, READ_SIZE);
			int rd = read_pipe(pipe, tmp, READ_SIZE, &error);
			if (error == ERROR_MORE_DATA) {
				luaL_addsize(&b, rd);
			} else if (error == ERROR_IO_PENDING) {
				continue;
			} else if (error != 0) {
				return luaL_error(L, "read error: %d", error);
			} else {
				luaL_pushresult(&b);
				return 1;
			}
		}
	} else if (error != 0) {
		return luaL_error(L, "read error: %d", error);
	}
	lua_pushlstring(L, tmp, rd);
	return 1;
}

static int
lwrite(lua_State *L) {
	HANDLE pipe = lua_touserdata(L, 1);
	size_t sz = 0;
	const char * data = luaL_checklstring(L, 2, &sz);
	int offset = luaL_optinteger(L, 3, 0);
	if (offset >= sz) {
		return luaL_error(L, "invalid offset");
	}
	data += offset;
	sz -= offset;
	unsigned long error = 0;
	int wt = write_pipe(pipe, data, sz, &error);
	if (error != 0) {
		return luaL_error(L, "write error : %u", error);
	}
	if (wt == sz)
		return 0;
	lua_pushinteger(L, offset + wt);
	return 1;
}

int
luaopen_pipe(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{"connect", lconnect },
		{"close", lclose },
		{"read", lread },
		{"write", lwrite },
		{ NULL, NULL },
	};

	luaL_newlib(L,l);

	return 1;
}

