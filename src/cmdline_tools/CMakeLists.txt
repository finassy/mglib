get_filename_component(DIRNAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
set(DLM_NAME mg_${DIRNAME})


add_library("${DLM_NAME}" SHARED "${DLM_NAME}.c")

if (APPLE)
  set_target_properties("${DLM_NAME}"
    PROPERTIES
      SUFFIX ".${Idl_PLATFORM_EXT}.so"
  )
endif ()

set_target_properties("${DLM_NAME}"
  PROPERTIES
    PREFIX ""
)


target_link_libraries("${DLM_NAME}" ${Idl_LIBRARY})

install(TARGETS ${DLM_NAME}
  RUNTIME DESTINATION lib/${DIRNAME}
  LIBRARY DESTINATION lib/${DIRNAME}
)
install(FILES "${DLM_NAME}.dlm" DESTINATION lib/${DIRNAME})

file(GLOB PRO_FILES "*.pro")
install(FILES ${PRO_FILES} DESTINATION lib/${DIRNAME})
install(FILES .idldoc DESTINATION lib/${DIRNAME})
install(FILES profiler.tt DESTINATION lib/${DIRNAME})
install(PROGRAMS idlman DESTINATION bin)
