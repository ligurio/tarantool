extern "C"
{
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include "lua_grammar.pb.h"
#include "serializer.h"

#include <libprotobuf-mutator/port/protobuf.h>
#include <libprotobuf-mutator/src/libfuzzer/libfuzzer_macro.h>

/**
 * LibFuzzer uses an option rss_limit_mb for setting a maximum limit of RSS.
 * Default value is 2048 Mb.
 */
#define LIBFUZZER_RSS_LIMIT 2147483648
/**
 * Number of simultaneous worker processes to run the jobs.
 * If zero, `min(jobs, NumberOfCpuCores() / 2) is used.
 */
#define LIBFUZZER_WORKERS 10
#define LIBFUZZER_JOBS 10

/* Struct with a Lua and Lua allocator states. */
typedef struct {
	lua_State *L;
	lua_Alloc old_alloc;
	void *state;
} alloc_state;

/**
 * Get an error message from the stack, and report it to std::cerr.
 * Remove the message from the stack.
 */
static inline void
report_error(lua_State *L, const std::string &prefix)
{
	const char *verbose = ::getenv("LUA_FUZZER_VERBOSE");
	if (!verbose)
		return;

	std::string err_str = lua_tostring(L, 1);
	/* Pop error message from stack. */
	lua_pop(L, 1);
	std::cerr << prefix << " error: " << err_str << std::endl;
}

void *
l_alloc(void *ud, void *ptr, size_t osize, size_t nsize) {
	alloc_state *as = (alloc_state *)ud;
	int heap_size_kb = lua_gc(as->L, LUA_GCCOUNT, 0);
	/* We are interested in a new allocations only. */
	if (nsize > osize && heap_size_kb >= 0) {
		size_t new_mem_size = nsize - osize;
		size_t heap_size = heap_size_kb * 1024;
		int rss_per_worker = LIBFUZZER_RSS_LIMIT / LIBFUZZER_WORKERS;
		if (heap_size + new_mem_size >= (size_t)rss_per_worker) {
			printf("ALLOC: heap_size + new_mem_size %lu >= %d\n", heap_size + new_mem_size, rss_per_worker);
			return NULL;
		}
	}

	lua_Alloc old_alloc = as->old_alloc;
	return old_alloc(as->state, ptr, osize, nsize);
}

DEFINE_PROTO_FUZZER(const lua_grammar::Block &message)
{
	lua_State *L = luaL_newstate();
	if (!L)
		return;

	std::string code = luajit_fuzzer::MainBlockToString(message);

	if (::getenv("LPM_DUMP_NATIVE_INPUT") && code.size() != 0) {
		std::cout << "-------------------------" << std::endl;
		std::cout << code << std::endl;
	}

	luaL_openlibs(L);

	/*
	 * See https://luajit.org/running.html.
	 */
	luaL_dostring(L, "jit.opt.start('hotloop=1')");
	luaL_dostring(L, "jit.opt.start('hotexit=1')");
	luaL_dostring(L, "jit.opt.start('recunroll=1')");
	luaL_dostring(L, "jit.opt.start('callunroll=1')");

	if (luaL_loadbuffer(L, code.c_str(), code.size(), "fuzz") != LUA_OK) {
		report_error(L, "luaL_loadbuffer()");
		goto end;
	}

	/*
	 * Using lua_pcall (protected call) to catch errors due to
	 * wrong semantics of some generated code chunks.
	 * Mostly, generated code is not semantically correct, so it is
	 * needed to describe Lua semantics for more interesting
	 * results and fuzzer tests.
	 */
	if (lua_pcall(L, 0, 0, 0) != LUA_OK)
		report_error(L, "lua_pcall()");

end:
	lua_settop(L, 0);
	lua_close(L);
}
