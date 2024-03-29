# - Find version of a DUNE package
#
# Synopsis:
#
#	find_dune_version (suite module)
#
# where:
# 	suite   Name of the suite; this should always be "dune"
# 	module  Name of the module, e.g. "common"
#
# Finds the content of DUNE_${MODULE}_VERSION_{MAJOR,MINOR,REVISION}
# from the installation.
#
# Add these variables to ${project}_CONFIG_IMPL_VARS in CMakeLists.txt
# if you need these in the code.

include (UseMultiArch)

function (find_dune_version suite module)
  # the _ROOT variable may or may not be set, but the include
  # variable should always be; get the prefix from the header path
  # if we have a multilib installation where the package maintainer
  # have installed it in e.g. /usr/include/dune-2.2/dune/istl, then
  # stash this extra indirection and add it back later in lib/
  set (_inc_path "${${suite}-${module}_INCLUDE_DIR}")
  file (TO_CMAKE_PATH _inc_path "${_inc_path}")
  set (_multilib_regexp "(.*)/include(/${suite}[^/]+)?")
  if (_inc_path MATCHES "${_multilib_regexp}")
	set (_orig_inc "${_inc_path}")
	string (REGEX REPLACE "${_multilib_regexp}" "\\1" _inc_path "${_orig_inc}")
	# only get the second group if it is really there (there is
	# probably a better way to do this in CMake)
	if ("${_inc_path}/include" STREQUAL "${_orig_inc}")
	  set (_multilib "")
	else ()
	  string (REGEX REPLACE "${_multilib_regexp}" "\\2" _multilib "${_orig_inc}")
	endif ()
  else ()
	set (_multilib "")
  endif ()

  # some modules does not have a library, use the directory of the
  # header files to find what would be the library dir.
  if (NOT ${suite}-${module}_LIBRARY)
	# this suffix is gotten from UseMultiArch.cmake
	set (_lib_path "${_inc_path}/${CMAKE_INSTALL_LIBDIR}")
  else ()
	get_filename_component (_lib_path "${${suite}-${module}_LIBRARY}" PATH)
  endif ()

  # if we have a source tree, dune.module is available there
  set (_dune_mod "${_inc_path}/dune.module")
  if (NOT EXISTS "${_dune_mod}")
	set (_dune_mod "")
  endif ()

  if (NOT _dune_mod)
	# look for the build tree; if we found the library, then the
	# dune.module file should be in a sub-directory  
	get_filename_component (_immediate "${_lib_path}" NAME)
	if ("${_immediate}" STREQUAL "${CMAKE_LIBRARY_ARCHITECTURE}")
	  # remove multi-arch part of the library path to get parent
	  get_filename_component (_lib_path "${_lib_path}" PATH)
	endif ()
	set (_dune_mod "${_lib_path}${_multilib}/dunecontrol/${suite}-${module}/dune.module")
	if (NOT EXISTS "${_dune_mod}")
	  # use the name itself as a flag for whether it was found or not
	  set (_dune_mod "")
	endif ()
  endif ()

  # if it is not available, it may make havoc having empty defines in the source
  # code later, so we bail out early
  if (${suite}-${module}_FIND_REQUIRED AND NOT _dune_mod)
	message (FATAL_ERROR "Failed to locate dune.module for ${suite}-${module}")
  endif ()

  # parse the file for the Version: field
  set (_ver_regexp "[ ]*Version:[ ]*([0-9]+)\\.([0-9]+)(.*)")
  file (STRINGS "${_dune_mod}" _ver_field REGEX "${_ver_regexp}")
  string (REGEX REPLACE "${_ver_regexp}" "\\1" _major "${_ver_field}")
  string (REGEX REPLACE "${_ver_regexp}" "\\2" _minor "${_ver_field}")
  string (REGEX REPLACE "${_ver_regexp}" "\\3" _revision "${_ver_field}")

  # revision may or may not be there
  set (_rev_regexp "\\.([0-9]+).*")
  if (_revision MATCHES "${_rev_regexp}")
	string (REGEX REPLACE "${_rev_regexp}" "\\1" _revision "${_revision}")
  else ()
	set (_revision "0")
  endif ()

  # generate variable for what we have found
  string (TOUPPER "${suite}" _SUITE)
  string (TOUPPER "${module}" _MODULE)
  string (REPLACE "-" "_" _MODULE "${_MODULE}")
  if ((NOT DEFINED ${_SUITE}_${_MODULE}_VERSION_MAJOR) AND
	  (NOT DEFINED ${_SUITE}_${_MODULE}_VERSION_MINOR) AND
	  (NOT DEFINED ${_SUITE}_${_MODULE}_VERSION_REVISION))
	set (${_SUITE}_${_MODULE}_VERSION_MAJOR "${_major}" PARENT_SCOPE)
	set (${_SUITE}_${_MODULE}_VERSION_MINOR "${_minor}" PARENT_SCOPE)
	set (${_SUITE}_${_MODULE}_VERSION_REVISION "${_revision}" PARENT_SCOPE)
  endif ()
endfunction (find_dune_version suite module)
