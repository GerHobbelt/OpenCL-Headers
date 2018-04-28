cmake_minimum_required(VERSION 3.11)
project(OpenCL-Loader)

set(CMAKE_CONFIGURATION_TYPES "Debug;Release")

file(GLOB GEN_SRC "generator/*.*")
file(GLOB OPENCL_VERSIONS LIST_DIRECTORIES true RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "${CMAKE_CURRENT_SOURCE_DIR}/opencl*")

set(OPENCL_VERSION "opencl12" CACHE STRING "OpenCL API Version")
set_property(CACHE OPENCL_VERSION PROPERTY STRINGS ${OPENCL_VERSIONS})

function(configure_bash)
  if(EXISTS "${BASH}")
    message(STATUS "Using predefined shell ${BASH}")
    return()
  endif()

  set(_BASH bash)

  if(CMAKE_HOST_SYSTEM MATCHES "Windows")
    find_package(Git)
    if(NOT GIT_FOUND)
      message(FATAL_ERROR "git bash required on windows.")
    endif()
    string(REPLACE "git.exe" "bash.exe" _BASH ${GIT_EXECUTABLE})
    string(REGEX REPLACE "mingw[0-9]*/" "" _BASH ${_BASH})
    if(NOT EXISTS "${_BASH}")
      message(FATAL_ERROR "${_BASH} does not exist. git bash required on windows.")
    endif()
  endif()

  set(BASH ${_BASH} PARENT_SCOPE)
  message(STATUS "Using shell ${_BASH}")
endfunction()

find_package(Git)
if(NOT EXISTS ${GIT_EXECUTABLE})
  message(FATAL_ERROR "Git not installed!")
endif()

execute_process(  COMMAND ${GIT_EXECUTABLE} submodule init
                  COMMAND ${GIT_EXECUTABLE} submodule update
                  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR} )

set(STAMP_FILE ${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION}/include/CL/opencl.h)

set(LOADER_OOD false)

if(EXISTS ${STAMP_FILE})
  foreach(GEN_FILE ${GEN_SRC})
    if(${GEN_FILE} IS_NEWER_THAN ${STAMP_FILE})
      set(LOADER_OOD true)
    endif()
  endforeach(GEN_FILE)
endif()

if(LOADER_OOD)
  message( STATUS "Generated loader code OOD")
  file(REMOVE_RECURSE ${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION})
endif()

make_directory(${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION}/include/CL)

set(CLHPP_OUT ${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION}/include/CL/cl.hpp)

if(OPENCL_VERSION MATCHES "opencl2")
  configure_file(${CMAKE_SOURCE_DIR}/OpenCL-CLHPP/input_cl2.hpp ${CLHPP_OUT})
else()
  find_package(PythonInterp)
  if(NOT EXISTS ${PYTHON_EXECUTABLE})
    message(FATAL_ERROR "Python not installed - required to generate OpenCL 1.X hpp file")
  endif()

  if(${CMAKE_SOURCE_DIR}/OpenCL-CLHPP/input_cl.hpp IS_NEWER_THAN ${CLHPP_OUT})
    execute_process(  COMMAND ${PYTHON_EXECUTABLE} gen_cl_hpp.py -i input_cl.hpp -o ${CLHPP_OUT}
                      WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/OpenCL-CLHPP )
  endif()
endif()

if(NOT EXISTS ${STAMP_FILE})
  message(STATUS "Generating OpenCL API Loader for ${OPENCL_VERSION}.")
  configure_bash()
  execute_process ( COMMAND "${BASH}" "${CMAKE_SOURCE_DIR}/generator/generate_loader.sh" ${OPENCL_VERSION}
                    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/ )
else()
  message(STATUS "OpenCL API Loader for ${OPENCL_VERSION} exists.")
endif()

set(API_INCLUDE_DIR "${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION}/include")

file(GLOB API_HEADERS "${API_INCLUDE_DIR}/CL/*.h" "${API_INCLUDE_DIR}/CL/*.hpp")
file(GLOB LIB_SRC "${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION}/src/*.c")

add_library(${PROJECT_NAME} STATIC ${LIB_SRC} ${API_HEADERS} ${GEN_SRC})

source_group("Generator" FILES ${GEN_SRC})
source_group("CL" FILES ${API_HEADERS})

target_include_directories(
 ${PROJECT_NAME}
 PRIVATE
 ${API_INCLUDE_DIR}
)

install(FILES $<TARGET_FILE:${PROJECT_NAME}> DESTINATION lib)
install(DIRECTORY ${API_INCLUDE_DIR}/CL DESTINATION include/)
