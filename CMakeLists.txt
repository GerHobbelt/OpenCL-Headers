cmake_minimum_required(VERSION 3.11)
project(OpenCL-Loader)

set(CMAKE_CONFIGURATION_TYPES "Debug;Release")

file(GLOB GEN_SRC "generator/*.*")
file(GLOB OPENCL_VERSIONS LIST_DIRECTORIES true RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "${CMAKE_CURRENT_SOURCE_DIR}/opencl*")

set(OPENCL_VERSION "opencl12" CACHE STRING "OpenCL API Version")
set_property(CACHE OPENCL_VERSION PROPERTY STRINGS ${OPENCL_VERSIONS})

set(BUILD_TEST false CACHE BOOL "Build simple test program to verify initialization")
set(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR}/install CACHE PATH "Install location for include/ and lib/")

set(CL_SUBDIR "OCDL")

set(API_INCLUDE_ROOT "${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION}/include")
set(API_INCLUDE_DIR "${API_INCLUDE_ROOT}/${CL_SUBDIR}")

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

    #strip away all possible sub-paths to git.exe - there are 4 of them
    string(REGEX REPLACE "mingw[0-9]*/" ""        _BASH ${GIT_EXECUTABLE})
    string(REGEX REPLACE "cmd/" ""                _BASH ${_BASH})
    string(REGEX REPLACE "bin/" ""                _BASH ${_BASH})
    string(REGEX REPLACE "libexec/git-core/" ""   _BASH ${_BASH})
    string(REPLACE "/git.exe" "/usr/bin/bash.exe" _BASH ${_BASH})

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

set(STAMP_FILE ${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION}/include/${CL_SUBDIR}/opencl.h)

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

make_directory(${API_INCLUDE_DIR})

set(CLHPP_OUT ${API_INCLUDE_DIR}/cl.hpp)
set(CL2HPP_OUT ${API_INCLUDE_DIR}/cl2.hpp)

if(OPENCL_VERSION MATCHES "opencl2")
  configure_file(${CMAKE_SOURCE_DIR}/OpenCL-CLHPP/input_cl2.hpp ${CL2HPP_OUT})
elseif(${CMAKE_SOURCE_DIR}/OpenCL-CLHPP/input_cl.hpp IS_NEWER_THAN ${CLHPP_OUT})
  find_package(PythonInterp)
  if(EXISTS "${PYTHON_EXECUTABLE}")
    execute_process(  COMMAND ${PYTHON_EXECUTABLE} gen_cl_hpp.py -i input_cl.hpp -o ${CLHPP_OUT}
                    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/OpenCL-CLHPP )
  else()
    message(STATUS "Python not installed - OpenCL 1.X hpp file won't be generated.")
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

file(GLOB API_HEADERS "${API_INCLUDE_DIR}/*.h" "${API_INCLUDE_DIR}/*.hpp")
file(GLOB LIB_SRC "${CMAKE_BINARY_DIR}/opencl_loader/${OPENCL_VERSION}/src/*.c")

include_directories(
 ${PROJECT_NAME}
 PRIVATE
 ${API_INCLUDE_ROOT}
)

add_library(${PROJECT_NAME} STATIC ${LIB_SRC} ${API_HEADERS} ${GEN_SRC})

source_group("Generator" FILES ${GEN_SRC})
source_group("${CL_SUBDIR}" FILES ${API_HEADERS})

if(BUILD_TEST)
  add_executable(${PROJECT_NAME}-test ${CMAKE_SOURCE_DIR}/test/test.c)
  target_link_libraries(${PROJECT_NAME}-test ${PROJECT_NAME})
endif()

install(FILES $<TARGET_FILE:${PROJECT_NAME}> DESTINATION lib)
install(DIRECTORY ${API_INCLUDE_DIR}/ DESTINATION include/${CL_SUBDIR})
