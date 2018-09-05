# OpenCL-Loader
Dynamic OpenCL loader generator

Tested Platforms:
* Windows - tested with cmake generator for Visual Studio 2017, Win32 & Win64
* Apple OSX - tested with cmake generators for make/clang and xcode
* Android - tested with cmake generator for Visual Studio 2017 ARM64

Pending:
* Linux - in theory should work, but has not been tested

Prereqs:
* cmake 3.11 or greater
* if generating project for MSVS 2017 Android C++ worfklow - https://github.com/Reification/CMake/releases
* bash shell and shell tools
  * windows host - git bash
  * apple host - system bash
  * linux host - system bash
* for opencl1X if cl.hpp is needed, python 2.x 
  * requirement inherited from OpenCL-HPP submodule to generate cl.hpp
  * cl2.hpp (opencl20 and above) does not have this requirement

Instructions:
* clone Repo
* create a build directory and run cmake from it
  * set OPENCL_VERSION to the name of any opencl header api directory (e.g. opencl12 or opencl20)
  * default value for OPENCL_VERSION is opencl12
  * set CMAKE_INSTALL_PREFIX to location of lib/ and include/ destination directories
* generate project, build INSTALL target
* header files will be under ${CMAKE_INSTALL_PREFIX}/OCDL/ (O)pen(C)L (D)ynamic (L)oader)
* include OCDL/opencl.h in one of your source files
* call `initialize_opencl((const char*)0)` before invoking any opencl functions
* profit

Licensing:
See file LICENSE in the root of this repo
