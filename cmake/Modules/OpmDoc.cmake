# - Setup documentation
#
# Assumes that a Doxyfile template is located in the project root
# directory, and that all documentation is going to be generated
# into its own Documentation/ directory. It will also generate an
# installation target for the documentation (not built by default)
#
# Requires the following variables to be set:
# ${opm}_NAME                Name of the project
#
# Output the following variables:
# ${opm}_STYLESHEET_COPIED   Location of stylesheet to be removed in distclean

macro (opm_doc opm docu_dir)
  # combine the template with local customization
  file (READ ${PROJECT_SOURCE_DIR}/cmake/Templates/Doxyfile _doxy_templ)
  string (REPLACE ";" "\\;" _doxy_templ "${_doxy_templ}")
  if (EXISTS ${PROJECT_SOURCE_DIR}/${docu_dir}/Doxylocal)
	file (READ ${PROJECT_SOURCE_DIR}/${docu_dir}/Doxylocal _doxy_local)
	string (REPLACE ";" "\\;" _doxy_local "${_doxy_local}")
  else (EXISTS ${PROJECT_SOURCE_DIR}/${docu_dir}/Doxylocal)
	set (_doxy_local)
  endif (EXISTS ${PROJECT_SOURCE_DIR}/${docu_dir}/Doxylocal)
  file (MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/${docu_dir})
  file (WRITE ${PROJECT_BINARY_DIR}/${docu_dir}/Doxyfile.in ${_doxy_templ} ${_doxy_local})
  # replace variables in this combined file
  configure_file (
	${PROJECT_BINARY_DIR}/${docu_dir}/Doxyfile.in
	${PROJECT_BINARY_DIR}/${docu_dir}/Doxyfile
	@ONLY
	)
  find_package (Doxygen)
  if (DOXYGEN_FOUND)
	add_custom_target (doc
	  COMMAND ${DOXYGEN_EXECUTABLE} ${PROJECT_BINARY_DIR}/${docu_dir}/Doxyfile
	  SOURCES ${PROJECT_BINARY_DIR}/${docu_dir}/Doxyfile
	  WORKING_DIRECTORY ${PROJECT_BINARY_DIR}/${docu_dir}
	  COMMENT "Generating API documentation with Doxygen"
	  VERBATIM
	  )
	# distributions have various naming conventions; this enables the packager
	# to direct where the install target should put the documentation. the names
	# here are taken from GNUInstallDirs.cmake
	option (CMAKE_INSTALL_DATAROOTDIR "Read-only arch.-indep. data root" "share")
	option (CMAKE_INSTALL_DOCDIR "Documentation root" "${CMAKE_INSTALL_DATAROOTDIR}/doc/${${opm}_NAME}")
	set (_formats html)
	foreach (format IN LISTS _formats)
	  string (TOUPPER ${format} FORMAT)
	  install (
		DIRECTORY ${PROJECT_BINARY_DIR}/${docu_dir}/${format}
		DESTINATION ${CMAKE_INSTALL_DOCDIR}
		COMPONENT ${format}
		OPTIONAL
		)
	  # target to install just HTML documentation
	  add_custom_target (install-${format}
		COMMAND ${CMAKE_COMMAND} -DCOMPONENT=${format} -P cmake_install.cmake
		COMMENT Installing ${FORMAT} documentation
		VERBATIM
		)
	  # since the documentation is optional, it is not automatically built
	  add_dependencies (install-${format} doc)
	endforeach (format)
  endif (DOXYGEN_FOUND)
  
  # stylesheets must be specified with relative path in Doxyfile, or the
  # full path (to the source directory!) will be put in the output HTML.
  # thus, we'll need to copy the stylesheet to this path relative to where
  # Doxygen will be run (in the output tree)
  if (NOT PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
	file (COPY ${PROJECT_SOURCE_DIR}/${docu_dir}/style.css
	  DESTINATION ${PROJECT_BINARY_DIR}/${docu_dir}
	  )
	set (${opm}_STYLESHEET_COPIED "${docu_dir}/style.css")
  else (NOT PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
	set (${opm}_STYLESHEET_COPIED "")
  endif (NOT PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
  
endmacro (opm_doc opm)
