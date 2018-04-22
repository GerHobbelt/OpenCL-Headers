# OpenCL-Loader
Dynamic OpenCL loader generator

Instructions:
* Clone Repo
* From bash (git bash on windows) run generator/generate_all.sh
* directory opencl_loader will be created with sub-directories for each OpenCL API version
* pick the API version you want to use
* use the headers in your Android OpenCL application - they replace system headers, so add the directory to your include path
* compile the matching src/.c file
* call initialize_openclXX() where XX is the version number
* profit
