#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

/*
#define func_def_2(func_name, type1, type2)             \
        int                                             \
        lua51##func_name(type1 arg1, type2 arg2) {      \
                return func_name(arg1, arg2);           \
        }

func_def_2(luaL_dostring, struct lua_State *, const char *)
*/

lua_State *lua51_luaL_newstate(void) {
	return luaL_newstate();
}

int lua51_luaL_dostring(lua_State *L, const char *str) {
	return luaL_dostring(L, str);
}

/*
void lua51_luaL_openlibs(lua_State *L) {
	luaL_openlibs(L);
}
*/

int lua51_luaL_loadbuffer(lua_State *L, const char *buff, size_t sz, const char *name) {
	return luaL_loadbuffer(L, buff, sz, name);
}

int lua51_lua_pcall(lua_State *L, int nargs, int nresults, int errfunc) {
	return lua_pcall(L, nargs, nresults, errfunc);
}

void lua51_lua_pop(lua_State *L, int n) {
	lua_pop(L, n);
}

void lua51_lua_settop(lua_State *L, int index) {
	lua_settop(L, index);

}
