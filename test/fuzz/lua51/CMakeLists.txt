find_package(Lua 5.1 REQUIRED)
message(STATUS "Found Lua ${LUA_VERSION_STRING}")
set(LIBLUA51_SOURCES lua51.c)
add_library(liblua51 SHARED ${LIBLUA51_SOURCES})
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99 -fPIC -fstrict-aliasing")
target_include_directories(liblua51 PRIVATE
	${LUA_INCLUDE_DIR}
)
target_link_libraries(liblua51 PRIVATE
	${LUA_LIBRARIES}
)
target_compile_options(liblua51 PRIVATE
	-Wall
	-Wextra
	-Wpedantic
	-Wno-unused-parameter
	-g
)
