#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <assert.h>

#define TEST_ORACLE_LUA51 1

#ifdef TEST_ORACLE_LUA51
#include "lua51.h"
#endif /* TEST_ORACLE_LUA51 */

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
	lua_State *L = luaL_newstate();
	if (!L) {
		return 0;
	}
	luaL_openlibs(L);
	// Make compiler really aggressive,
	// see https://luajit.org/running.html
	// and https://luajit.org/ext_c_api.html
	luaL_dostring(L, "jit.opt.start('hotloop=1')");
	luaL_dostring(L, "jit.opt.start('hotexit=1')");
	luaL_dostring(L, "jit.opt.start('recunroll=1')");
	luaL_dostring(L, "jit.opt.start('callunroll=1')");
	int rc_jit = luaL_loadbuffer(L, (const char *)data, size, "fuzz_test");
	if (rc_jit == 0)
		rc_jit = lua_pcall(L, 0, 0, 0);
	lua_settop(L, 0);
	lua_close(L);

	/* JIT-compilation is disabled */

	L = luaL_newstate();
	if (!L) {
		return 0;
	}
	luaL_openlibs(L);
	// https://luajit.org/ext_jit.html
	luaL_dostring(L, "jit.off(true, true)");
	int rc_jitoff = luaL_loadbuffer(L, (const char *)data, size, "fuzz_test");
	if (rc_jitoff == 0)
		rc_jitoff = lua_pcall(L, 0, 0, 0);
	//printf("rc_jit %d, rc_jitoff %d\n", rc_jit, rc_jitoff);
	assert(rc_jit == rc_jitoff);
	lua_settop(L, 0);
	/*lua_close(L);*/

#ifdef TEST_ORACLE_LUA51
	/* PUC Rio Lua 5.1 */
	lua51_lua_State *LUA51_L = lua51_luaL_newstate();
	luaL_openlibs(LUA51_L);
	int rc_lua51 = lua51_luaL_loadbuffer(LUA51_L, (const char *)data, size, "lua51");
	if (rc_lua51 == 0)
		rc_lua51 = lua51_lua_pcall(LUA51_L, 0, 0, 0);
	lua51_lua_settop(LUA51_L, 0);
	/* lua_close(LUA51_L); */
	//printf("rc_lua51 %d, rc_jitoff %d\n", rc_lua51, rc_jitoff);
	assert(rc_lua51 == rc_jitoff);
#endif /* TEST_ORACLE_LUA51 */

	return 0;
}
