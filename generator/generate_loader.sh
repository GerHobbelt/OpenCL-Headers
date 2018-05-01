#!/bin/bash

#set -x

generator_dir=$(dirname "${0}")
generator_dir=$(cd "${generator_dir}"; pwd)

api_dir=$(cd "${generator_dir}"; cd ..; pwd)

out_dir="$(pwd)/opencl_loader"

function process_header() {
  local api_ver="${1}"
  local hdr_in="${2}"
  local hdr_out="${3}"
  local src_out="${4}"

  cat > "${hdr_out}" << EOF
//
// OpenCL-Loader generated replacement header for ${api_ver} ${hdr_in}
// $(date)
//
#pragma once
EOF

  #primary - include the initialize function decl
  "${generator_dir}"/process_header.sh -v src_out="${src_out}" -vsrc_out_decl="${src_out}.decl" -v hdr_out="${hdr_out}" "${hdr}"

  if [[ "${hdr_in}" == "opencl.h" ]]; then
    cat << EOF >> "${hdr_out}"
#ifdef __cplusplus
extern "C" {
#endif
#define OPENCL_LOADER_API_VERSION ${api_ver/opencl/}
extern int initialize_opencl();
#ifdef __cplusplus
}
#endif
EOF
  fi # opencl.h
}

function gen_loader() {
  local api_ver="${1}"
  local ver_out_dir="${out_dir}/${api_ver}"
  local src="${ver_out_dir}/src/${api_ver}_loader.c"

  if [[ ! -d "${api_ver}/CL" ]]; then
    echo "${api_ver} is not an OpenCL API directory." 1>&2
    return -1
  fi

  mkdir -p "${ver_out_dir}/src"
  mkdir -p "${ver_out_dir}/include/CL"

  cd "${api_ver}/CL"

  hpps=$(echo *.hpp)
  if [[ "${hpps}" == '*.hpp' ]]; then
    hpps=
  fi

  headers=
  includes=
  for hdr in *.h; do
    #skip d3d, dx, and intel headers for now
    if [[ ${hdr/d3d/} == ${hdr} && ${hdr/dx/} == ${hdr} && ${hdr/intel/} == ${hdr} ]]; then
      headers="${headers} ${hdr}"
      includes="${includes}#include \"CL/${hdr}\""
    fi
  done

  includes=$(echo "${includes}" | sed 's:#:\n#:g')

  cat > "${src}" << EOF
//
// ${api_ver} loader source generated by OpenCL-Loader generator 
// $(date)
//
#include "CL/opencl.h"
${includes}

#if defined(_WIN32)
# define VC_EXTRALEAN 1
# include <windows.h>
# define LIB_PFX ""
# define LIB_SFX ".dll"
  typedef HMODULE libptr;
  typedef FARPROC funcptr;
  static libptr open_lib(const char* path) { return LoadLibrary( path ); }
  static funcptr find_lib_func(libptr lib, const char* name) { return GetProcAddress( lib, (char*)name ); }
# define NULL_LIB ((libptr)0)
#elif defined(__ANDROID__) || defined(__linux__) || defined(__APPLE__)
# include <dlfcn.h>
# define LIB_PFX "lib"
# if defined(__APPLE__)
#   define LIB_SFX ".dylib"
# else
#   define LIB_SFX ".so"
# endif
  typedef void* libptr;
  typedef void* funcptr;
  static libptr open_lib(const char* path) { return dlopen( path, RTLD_NOW | RTLD_LOCAL );}
  static funcptr find_lib_func(libptr lib, const char* name) { return dlsym( lib, name ); }
# define NULL_LIB ((libptr)0)
#else
# error Unsupported OS!
#endif

int initialize_opencl() {
  static int s_initted = 0;
  if ( s_initted ) return 1;

  libptr libopencl = open_lib(LIB_PFX "OpenCL" LIB_SFX);
  if ( libopencl == NULL_LIB ) { libopencl = open_lib(LIB_PFX "opencl" LIB_SFX); }
  if ( libopencl == NULL_LIB ) return 0;

  s_initted = 1;
EOF

  for hdr in ${headers}; do
    process_header "${api_ver}" "${hdr}" "${ver_out_dir}/include/CL/${hdr}" "${src}"
  done

  cat >> "${src}" << EOF
  return 1;
}
EOF

  cat "${src}.decl" >> "${src}"
  rm "${src}.decl"

  if [[ "${hpps}" ]]; then
    for hpp in ${hpps}; do
      cp -v "${hpp}" "${ver_out_dir}/include/CL/${hpp}"
    done
  fi

  # cl.hpp needs special attention - pointers to clGetXXX functions get passed around.
  # because function names now correspond to pointers instead of prototypes the syntax
  # used in those heades to refer to api function pointers is off by a level of indirection.
  # &::clGetXXX of a global pointer-to-func is a pointer pointer
  for hpp_name in cl.hpp; do # cl2.hpp; do # cl2.hpp appears to handle both cases via template magic
    hpp="${ver_out_dir}/include/CL"/${hpp_name}
    if [[ -f "${hpp}" ]]; then
      echo "// ${hpp_name} Processed by OpenCL-Loader Generator $(date)" > "${hpp}.fixed"
      sed 's/\&::clGet/::clGet/g' "${hpp}" >> "${hpp}.fixed"
      mv -f "${hpp}.fixed" "${hpp}"
    fi
  done

  cd  "${api_dir}"
}

cd "${api_dir}"

if [[ -n "${1}" ]]; then
  for api_ver in "${@}"; do
    if [[ ${api_ver} != "opencl_loader" ]]; then
      echo "Generating Loader for ${api_ver}"
      gen_loader "${api_ver}"
    fi
  done
else
  for api_ver in opencl*; do
    if [[ ${api_ver} != "opencl_loader" ]]; then
      echo "Generating OpenCL Loader for ${api_ver}"
      gen_loader "${api_ver}"
    fi
  done
fi
