#ifndef LUA51_H_
#define LUA51_H_

typedef struct lua_State lua51_lua_State;
lua51_lua_State * lua51_luaL_newstate(void);
int lua51_luaL_dostring(lua51_lua_State *L, const char *str);
void lua51_luaL_openlibs(lua51_lua_State *L);
int lua51_luaL_loadbuffer(lua51_lua_State *L, const char *buff, size_t sz, const char *name);
int lua51_lua_pcall(lua51_lua_State *L, int nargs, int nresults, int errfunc);
void lua51_lua_settop(lua51_lua_State *L, int index);

#endif /* LUA51_H_ */
