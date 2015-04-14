
set(NAME gala-lockscreen)
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

project(${NAME})
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

enable_testing()

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.22" MINIMUM)
include (ValaPrecompile)

find_package (PkgConfig)
pkg_check_modules(DEPS REQUIRED gala granite)
add_definitions (${DEPS_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS})

vala_precompile(VALA_C
	src/DBus.vala
	src/LoginBox.vala
	src/Main.vala
	src/Settings.vala
	src/Interfaces/GnomePresence.vala
	src/Interfaces/LoginManager.vala
PACKAGES
	gala
	granite
	xfixes-4.0
OPTIONS
	--target-glib=2.32
	--define=HAS_MUTTER310
	--vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi
)

add_library(${NAME} SHARED ${VALA_C} src/pam-auth.c)
target_link_libraries(${NAME} ${DEPS_LIBRARY} m pam)

install(TARGETS ${NAME} DESTINATION lib/gala/plugins)

include(GSettings)
# add_schema("data/org.pantheon.desktop.gala.plugins.lockscreen.gschema.xml")
