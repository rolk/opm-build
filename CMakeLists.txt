# -*- mode: cmake; tab-width: 2; indent-tabs-mode: t; truncate-lines: t; compile-command: "cmake -Wdev" -*-
# vim: set filetype=cmake autoindent tabstop=2 shiftwidth=2 noexpandtab softtabstop=2 nowrap:
cmake_minimum_required (VERSION 2.8)
project (opm-build)

# copy cmake macros to system when installing
install (
  DIRECTORY cmake
  DESTINATION share/opm
  )

# shut up about unused variables for other projects
include ("${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules/OpmKnown.cmake")
