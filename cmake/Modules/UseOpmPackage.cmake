# - Find routine for OPM-like modules
#
# Synopsis:
#
#   find_opm_package (module deps opts header lib defs prog conf)
#
# where
#
#   module    Name of the module, e.g. "dune-common"; this will be the
#             stem of all variables defined (see below).
#   reqs      Semi-colon-separated list of dependent modules which must
#             be present; all are required.
#   opts      Semi-colon-separated list of dependent modules which not
#             necessarily must be present but should be included if they
#             are.
#   header    Name of the header file to probe for, e.g.
#             "dune/common/fvector.hh". Note that you should have to same
#             relative path here as is used in the header files.
#   lib       Name of the library to probe for, e.g. "dunecommon"
#   defs      Symbols that should be passed to compilations
#   prog      Program that should compile if library is present
#   conf      Symbols that should be present in config.h
#
# It will provide these standard Find-module variables:
#
#   ${module}_INCLUDE_DIRS    Directory of header files
#   ${module}_LIBRARIES       Directory of shared object files
#   ${module}_DEFINITIONS     Defines that must be set to compile
#   ${module}_CONFIG_VARS     List of defines that should be in config.h
#   HAVE_${MODULE}            Binary value to use in config.h
#
# Note: Arguments should be quoted, otherwise a list will spill into the
#       next argument!

# Copyright (C) 2012 Uni Research AS
# This file is licensed under the GNU General Public License v3.0

# <http://www.vtk.org/Wiki/CMake:How_To_Find_Libraries>

# libraries should always be trimmed from the beginning, so that also
# missing functions in those later in the list will be resolved
macro (remove_duplicate_libraries module)
  if (DEFINED ${module}_LIBRARIES)
	list (REVERSE ${module}_LIBRARIES)
	list (REMOVE_DUPLICATES ${module}_LIBRARIES)
	list (REVERSE ${module}_LIBRARIES)
  endif (DEFINED ${module}_LIBRARIES)
endmacro (remove_duplicate_libraries module)

function (find_opm_package module reqs opts header lib defs prog conf)
  # if someone else has included this test, don't do it again
  if (${${module}_FOUND})
	return ()
  endif (${${module}_FOUND})

  # dependencies on other packages
  foreach (_dep IN LISTS reqs)
	find_package (${_dep} QUIET REQUIRED)
  endforeach (_dep)
  foreach (_dep IN LISTS opts)
	find_package (${_dep} QUIET)
  endforeach (_dep)
  set (_deps ${reqs} ${opts})

  # compile with C++0x/11 support if available
  find_package (CXX11Features REQUIRED)

  # see if there is a pkg-config entry for this package, and use those
  # settings as a starting point
  find_package (PkgConfig)
  pkg_check_modules (PkgConf_${module} QUIET ${module})
  set (${module}_DEFINITIONS ${PkgConf_${module}_CFLAGS_OTHER})

  # search for this include and library file to get the installation
  # directory of the package
  find_path (${module}_INCLUDE_DIR
	NAMES "${header}"
	PATHS ${${module}_DIR}
	HINTS ${PkgConf_${module}_INCLUDE_DIRS}
	)

  # some modules are all in headers
  if (NOT "${lib}" STREQUAL "")
	find_library (${module}_LIBRARY
	  NAMES "${lib}"
	  PATHS ${${module}_DIR}
	  HINTS ${PkgConf_${module}_LIBRARY_DIRS}
	  PATH_SUFFIXES ".libs" "lib" "lib32" "lib64"
	  )
  else (NOT "${lib}" STREQUAL "")
	set (${module}_LIBRARY "")
  endif (NOT "${lib}" STREQUAL "")

  # add dependencies so that our result variables are complete
  # list of necessities to build with the software
  set (${module}_INCLUDE_DIRS "${${module}_INCLUDE_DIR}")
  set (${module}_LIBRARIES "${${module}_LIBRARY}")
  foreach (_dep IN LISTS _deps)
	list (APPEND ${module}_INCLUDE_DIRS ${${_dep}_INCLUDE_DIRS})
	list (APPEND ${module}_LIBRARIES ${${_dep}_LIBRARIES})
	list (APPEND ${module}_DEFINITIONS ${${_dep}_DEFINITIONS})
	list (APPEND ${module}_CONFIG_VARS ${${_dep}_CONFIG_VARS})
  endforeach (_dep)

  # compile with this option to avoid avalanche of warnings
  set (${module}_DEFINITIONS "${${module}_DEFINITIONS}")
  foreach (_def IN LISTS defs)
	list (APPEND ${module}_DEFINITIONS "-D${_def}")
  endforeach (_def)

  # tidy the lists before returning them
  list (REMOVE_DUPLICATES ${module}_INCLUDE_DIRS)
  remove_duplicate_libraries (${module})
  list (REMOVE_DUPLICATES ${module}_DEFINITIONS)

  # check that we can compile a small test-program
  include (CMakePushCheckState)
  cmake_push_check_state ()
  include (CheckCXXSourceCompiles)
  list (APPEND CMAKE_REQUIRED_INCLUDES ${${module}_INCLUDE_DIR})
  list (APPEND CMAKE_REQUIRED_LIBRARIES ${${module}_LIBRARIES})
  # since we don't have any config.h yet
  list (APPEND CMAKE_REQUIRED_DEFINITIONS ${${module}_DEFINITIONS})
  list (APPEND CMAKE_REQUIRED_DEFINITIONS "-DHAVE_NULLPTR=${HAVE_NULLPTR}")
  string (TOUPPER ${module} MODULE)
  string (REPLACE "-" "_" MODULE ${MODULE})
  check_cxx_source_compiles ("${prog}" HAVE_${MODULE})
  cmake_pop_check_state ()

  # these defines are used in dune/${module} headers, and should be put
  # in config.h when we include those
  foreach (_var IN LISTS conf)
	# massage the name to remove source code formatting
	string (REGEX REPLACE "^[\n\t\ ]+" "" _var "${_var}")
	string (REGEX REPLACE "[\n\t\ ]+$" "" _var "${_var}")
	list (APPEND ${module}_CONFIG_VARS ${_var})
  endforeach (_var)
  foreach (_dep in _deps)
	if (DEFINED ${_dep}_CONFIG_VARS)
	  list (APPEND ${module}_CONFIG_VARS ${_dep}_CONFIG_VARS)
	endif (DEFINED ${_dep}_CONFIG_VARS)
  endforeach (_dep)
  list (REMOVE_DUPLICATES ${module}_CONFIG_VARS)

  # write status message in the same manner as everyone else
  include (FindPackageHandleStandardArgs)
  set (_req_vars "${${module}_INCLUDE_DIR}")
  if (NOT "${lib}" STREQUAL "")
	list (APPEND _req_vars "${${module}_LIBRARY}")
  endif (NOT "${lib}" STREQUAL "")
  find_package_handle_standard_args (
	${module}
	DEFAULT_MSG
	_req_vars
	)

  # allow the user to override these from user interface
  mark_as_advanced (${module}_INCLUDE_DIR)
  mark_as_advanced (${module}_LIBRARY)

  # some genius that coded the FindPackageHandleStandardArgs figured out
  # that the module name should be in uppercase (?!)
  string (TOUPPER ${module} MODULE_UPPER)
  set (${module}_FOUND "${${MODULE_UPPER}_FOUND}" PARENT_SCOPE)

  # return these variables to the caller
  set (${module}_INCLUDE_DIRS "${${module}_INCLUDE_DIRS}" PARENT_SCOPE)
  set (${module}_LIBRARIES "${${module}_LIBRARIES}" PARENT_SCOPE)
  set (${module}_DEFINITIONS "${${module}_DEFINITIONS}" PARENT_SCOPE)
  set (${module}_CONFIG_VARS "${${module}_CONFIG_VARS}" PARENT_SCOPE)
  set (HAVE_${MODULE} "${HAVE_${MODULE}}" PARENT_SCOPE)
endfunction (find_opm_package module reqs opts header lib defs prog conf)

# print all variables defined by the above macro
function (debug_find_vars module)
  message (STATUS "${module}_FOUND        = ${${module}_FOUND}")
  message (STATUS "${module}_INCLUDE_DIRS = ${${module}_INCLUDE_DIRS}")
  message (STATUS "${module}_LIBRARIES    = ${${module}_LIBRARIES}")
  message (STATUS "${module}_DEFINITIONS  = ${${module}_DEFINITIONS}")
  message (STATUS "${module}_CONFIG_VARS  = ${${module}_CONFIG_VARS}")
  string (TOUPPER ${module} MODULE)
  string (REPLACE "-" "_" MODULE ${MODULE})  
  message (STATUS "HAVE_${MODULE}         = ${HAVE_${MODULE}}")
endfunction (debug_find_vars module)
