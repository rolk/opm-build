# - Find routine for OPM-like modules
#
# Synopsis:
#
#   find_opm_package (module deps header lib defs prog conf)
#
# where
#
#   module    Name of the module, e.g. "dune-common"; this will be the
#             stem of all variables defined (see below).
#   deps      Semi-colon-separated list of dependent modules which must
#             be present; those that are required must be marked as such
#	          explicitly. Quote if more than one word is necessary to
#	          describe the dependency.
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
#	${module}_QUIET           Verbosity of last find of this module
#   HAVE_${MODULE}            Binary value to use in config.h
#
# Note: Arguments should be quoted, otherwise a list will spill into the
#       next argument!

# Copyright (C) 2012 Uni Research AS
# This file is licensed under the GNU General Public License v3.0

# <http://www.vtk.org/Wiki/CMake:How_To_Find_Libraries>

include (OpmFind)

option (SIBLING_SEARCH "Search sibling directories before system paths" ON)
mark_as_advanced (SIBLING_SEARCH)

# append all items from src into dst; both must be *names* of lists
macro (append_found src dst)
  foreach (_item IN LISTS ${src})
	if (NOT "${_item}" MATCHES "-NOTFOUND$")
	  list (APPEND ${dst} ${_item})
	endif (NOT "${_item}" MATCHES "-NOTFOUND$")
  endforeach (_item)
endmacro (append_found src dst)

macro (find_opm_package module deps header lib defs prog conf)
  # variables to pass on to other packages
  if (FIND_QUIETLY)
	set (${module}_QUIET "QUIET")
  else (FIND_QUIETLY)
	set (${module}_QUIET "")
  endif (FIND_QUIETLY)

  # if someone else has included this test, don't do it again
  if (${${module}_FOUND})
	return ()
  endif (${${module}_FOUND})

  # see if there is a pkg-config entry for this package, and use those
  # settings as a starting point
  find_package (PkgConfig)
  pkg_check_modules (PkgConf_${module} QUIET ${module})

  # these variables have non-standard names in FindPkgConfig (sic)
  set (${module}_DEFINITIONS ${PkgConf_${module}_CFLAGS_OTHER})
  set (${module}_LINKER_FLAG ${PkgConf_${module}_LDFLAGS_OTHER})

  # in addition to accepting mod-ule_ROOT, we also accept the somewhat
  # more idiomatic MOD_ULE_ROOT variant
  string (TOUPPER ${module} MODULE_UPPER)
  string (REPLACE "-" "_" MODULE ${MODULE_UPPER})

  # if the user hasn't specified any location, and it isn't found
  # in standard system locations either, then start to wander
  # about and look for it in proximity to ourself. Qt Creator likes
  # to put the build-directories as siblings to the source trees,
  # but with a -build suffix, DUNE likes to have the the build tree
  # in a "build-cmake" sub-directory of each module
  if (NOT (${module}_DIR OR ${module}_ROOT OR ${MODULE}_ROOT))
	string (TOLOWER "${module}" _module_lower)
	set (_guess
	  "../${module}"
	  "../${_module_lower}"
	  )
	set (_guess_bin_only
	  "../${module}-build"
	  "../${_module_lower}-build"
	  )
	# try to figure out whether we are in a subdir build tree, and attempt
	# to put the same name as the appropriate build tree for the module
	get_filename_component (_build_dir "${CMAKE_CURRENT_BINARY_DIR}" NAME)

	# don't bother if we are in a project specific directory already
	# (assuming no-one wants to name the build dir after another module!)
	if ("${_build_dir}" STREQUAL "${PROJECT_NAME}")
	  set (_build_dir "")
	endif ("${_build_dir}" STREQUAL "${PROJECT_NAME}")

	# look in similar dirs for the other module
	list (APPEND _guess_bin_only
	  "../../${module}/${_build_dir}"
	  "../../${_module_lower}/${_build_dir}"
	  )

	# generate items that are in the build, not source dir
	set (_guess_bin)
	foreach (_item IN ITEMS ${_guess} ${_guess_bin_only})
	  list (APPEND _guess_bin "${PROJECT_BINARY_DIR}/${_item}")
	endforeach (_item)
	set (_no_system "")
  else (NOT (${module}_DIR OR ${module}_ROOT OR ${MODULE}_ROOT))
	# start looking at the paths in this order
	set (_guess_bin
	  ${${module}_DIR}
	  ${${module}_ROOT}
	  ${${MODULE}_ROOT}
	  )
	# if every package is installed directly in the "suite" directory
	# (e.g. /usr) then allow us to back-track one directory from the
	# module sub-dir that was added by OpmFind (this happens incidently
	# already for the source do to the out-of-source support)
	if ("${${MODULE}_ROOT}" MATCHES "/${module}$")
	  get_filename_component (_suite_parent ${${MODULE}_ROOT} PATH)
	  list (APPEND _guess_bin
		${_suite_parent}
		${_suite_parent}/${module}
		${_suite_parent}/${module}/${_build_dir}
		)
	endif ("${${MODULE}_ROOT}" MATCHES "/${module}$")
	# when we look for the source, it may be that we have been specified
	# a build directory which is a sub-dir of the source, so we look in
	# the parent also
	set (_guess
	  ${${module}_DIR}
	  ${${module}_ROOT}
	  ${${MODULE}_ROOT}
	  ${${module}_DIR}/..
	  ${${module}_ROOT}/..
	  ${${MODULE}_ROOT}/..
	  )
	# don't search the system paths! that would be dangerous; if there
	# is a problem in our own specified directory, we don't necessarily
	# want an old version that is left in one of the system paths!
	set (_no_system "NO_DEFAULT_PATH")
  endif (NOT (${module}_DIR OR ${module}_ROOT OR ${MODULE}_ROOT))

  # by specifying _guess in the HINTS section, it gets searched before
  # the system locations as well. the CMake documentation has a cloudy
  # recommendation, but it ends up like this: if NO_DEFAULT_PATH is
  # specified, then PATHS is used. Otherwise, it looks in HINTS, then in
  # system paths, and the finally in PATHS (!)
  if (SIBLING_SEARCH)
	set (_guess_hints ${_guess})
	set (_guess_hints_bin ${_guess_bin})
  else (SIBLING_SEARCH)
	set (_guess_hints)
	set (_guess_hints_bin)
  endif (SIBLING_SEARCH)

  # search for this include and library file to get the installation
  # directory of the package; hints are searched before the system locations,
  # paths are searched afterwards
  find_path (${module}_INCLUDE_DIR
	NAMES "${header}"
	PATHS ${_guess}
	HINTS ${PkgConf_${module}_INCLUDE_DIRS} ${_guess_hints}
	PATH_SUFFIXES "include"
	${_no_system}
	)

  # some modules are all in headers
  if (NOT "${lib}" STREQUAL "")
	if (CMAKE_SIZEOF_VOID_P)
	  math (EXPR _BITS "8 * ${CMAKE_SIZEOF_VOID_P}")
	endif (CMAKE_SIZEOF_VOID_P)
	find_library (${module}_LIBRARY
	  NAMES "${lib}"
	  PATHS ${_guess_bin}
	  HINTS ${PkgConf_${module}_LIBRARY_DIRS} ${_guess_hints_bin}
	  PATH_SUFFIXES "lib" "lib/.libs" ".libs" "lib${_BITS}" "lib/${CMAKE_LIBRARY_ARCHITECTURE}" "build-cmake/lib"
	  ${_no_system}
	  )
  else (NOT "${lib}" STREQUAL "")
	set (${module}_LIBRARY "")
  endif (NOT "${lib}" STREQUAL "")

  # add dependencies so that our result variables are complete
  # list of necessities to build with the software
  set (${module}_INCLUDE_DIRS "${${module}_INCLUDE_DIR}")
  set (${module}_LIBRARIES "${${module}_LIBRARY}")
  set (_deps)
  foreach (_dep IN ITEMS ${deps})
	separate_arguments (_args UNIX_COMMAND ${_dep})
	if (_args)
	  find_and_append_package_to (${module} ${_args} ${${module}_QUIET})
	  list (GET _args 0 _name_only)
	  list (APPEND _deps ${_name_only})
	else (_args)
	  message (WARNING "Empty dependency in find module for ${module} (check for trailing semi-colon)")
	endif (_args)
  endforeach (_dep)

  # since find_and_append_package_to is a macro, this variable have
  # probably been overwritten (due to its common name); it is now
  # this module's last dependency instead of the name of the module
  # itself, so it must be restored
  string (TOUPPER ${module} MODULE_UPPER)
  string (REPLACE "-" "_" MODULE ${MODULE_UPPER})

  # compile with this option to avoid avalanche of warnings
  set (${module}_DEFINITIONS "${${module}_DEFINITIONS}")
  foreach (_def IN ITEMS ${defs})
	list (APPEND ${module}_DEFINITIONS "-D${_def}")
  endforeach (_def)

  # tidy the lists before returning them
  remove_dup_deps (${module})

  # these defines are used in dune/${module} headers, and should be put
  # in config.h when we include those
  foreach (_var IN ITEMS ${conf})
	# massage the name to remove source code formatting
	string (REGEX REPLACE "^[\n\t\ ]+" "" _var "${_var}")
	string (REGEX REPLACE "[\n\t\ ]+$" "" _var "${_var}")
	list (APPEND ${module}_CONFIG_VARS ${_var})
  endforeach (_var)

  # these are the defines that should be set when compiling
  # without config.h
  config_cmd_line (${module}_CMD_CONFIG ${module}_CONFIG_VARS)

  # check that we can compile a small test-program
  include (CMakePushCheckState)
  cmake_push_check_state ()
  include (CheckCXXSourceCompiles)
  # only add these if they are actually found; otherwise it won't
  # compile and the variable won't be set
  append_found (${module}_INCLUDE_DIRS CMAKE_REQUIRED_INCLUDES)
  append_found (${module}_LIBRARIES CMAKE_REQUIRED_LIBRARIES)
  # since we don't have any config.h yet
  list (APPEND CMAKE_REQUIRED_DEFINITIONS ${${module}_DEFINITIONS})
  list (APPEND CMAKE_REQUIRED_DEFINITIONS ${${module}_CMD_CONFIG})
  check_cxx_source_compiles ("${prog}" HAVE_${MODULE})
  cmake_pop_check_state ()

  # write status message in the same manner as everyone else
  include (FindPackageHandleStandardArgs)
  if ("${lib}" STREQUAL "")
	set (_lib_var "")
	set (_and_lib_var)
  else ("${lib}" STREQUAL "")
	set (_lib_var "${module}_LIBRARY")
	set (_and_lib_var AND ${_lib_var})
  endif ("${lib}" STREQUAL "")
  # if the search is going to fail, then write these variables to
  # the console as well as a diagnostics
  if ((NOT (${module}_INCLUDE_DIR ${_and_lib_var} AND HAVE_${MODULE}))
	  AND (${module}_FIND_REQUIRED OR NOT ${module}_FIND_QUIETLY))
	if (DEFINED ${module}_DIR)
	  message ("${module}_DIR = ${${module}_DIR}")
	elseif (DEFINED ${module}_ROOT)
	  message ("${module}_ROOT = ${${module}_ROOT}")
	elseif (DEFINED ${MODULE}_ROOT)
	  message ("${MODULE}_ROOT = ${${MODULE}_ROOT}")
	endif (DEFINED ${module}_DIR)
  endif ((NOT (${module}_INCLUDE_DIR ${_and_lib_var} AND HAVE_${MODULE}))
	AND (${module}_FIND_REQUIRED OR NOT ${module}_FIND_QUIETLY))
  find_package_handle_standard_args (
	${module}
	DEFAULT_MSG
	${module}_INCLUDE_DIR ${_lib_var} HAVE_${MODULE}
	)

  # allow the user to override these from user interface
  mark_as_advanced (${module}_INCLUDE_DIR)
  mark_as_advanced (${module}_LIBRARY)

  # some genius that coded the FindPackageHandleStandardArgs figured out
  # that the module name should be in uppercase (?!)
  set (${module}_FOUND "${${MODULE_UPPER}_FOUND}")

  # print everything out if we're asked to
  if (${module}_DEBUG)
	debug_find_vars (${module})
  endif (${module}_DEBUG)
endmacro (find_opm_package module deps header lib defs prog conf)

# print all variables defined by the above macro
function (debug_find_vars module)
  message (STATUS "${module}_FOUND        = ${${module}_FOUND}")
  message (STATUS "${module}_INCLUDE_DIRS = ${${module}_INCLUDE_DIRS}")
  message (STATUS "${module}_LIBRARIES    = ${${module}_LIBRARIES}")
  message (STATUS "${module}_DEFINITIONS  = ${${module}_DEFINITIONS}")
  message (STATUS "${module}_CONFIG_VARS  = ${${module}_CONFIG_VARS}")
  message (STATUS "${module}_LINKER_FLAGS = ${${module}_LINKER_FLAGS}")
  message (STATUS "${module}_QUIET        = ${${module}_QUIET}")
  string (TOUPPER ${module} MODULE)
  string (REPLACE "-" "_" MODULE ${MODULE})  
  message (STATUS "HAVE_${MODULE}         = ${HAVE_${MODULE}}")
endfunction (debug_find_vars module)

# generate a command-line that can be used to pass variables before
# config.h is available (such as probe tests). varname is the *name*
# of the variable to receive the result, defs is a list of the *names*
# which should be passed
function (config_cmd_line varname defs)
  # process each variable
  foreach (_var IN LISTS ${defs})
	# only generate an entry if the define was actually set
	if ((DEFINED ${_var}) AND (NOT "${${_var}}" STREQUAL ""))
	  # numbers are not quoted, strings are
	  if (${_var} MATCHES "[0-9]+")
		set (_quoted "${${_var}}")
	  else (${_var} MATCHES "[0-9]+")
		set (_quoted "\"${${_var}}\"")
	  endif (${_var} MATCHES "[0-9]+")
	  # add command-line option to define this variable
	  list (APPEND _cmdline "-D${_var}=${_quoted}")
	endif ((DEFINED ${_var}) AND (NOT "${${_var}}" STREQUAL ""))
  endforeach (_var)
  # return the resulting command-line options for defining vars
  set (${varname} "${_cmdline}" PARENT_SCOPE)
endfunction (config_cmd_line)
