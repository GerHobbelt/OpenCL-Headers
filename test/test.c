#include <stdio.h>
#include "OCDL/opencl.h"

int main(int argc, const char** argv) {
  if ( !initialize_opencl((const char*)0) )
  {
    fprintf( stderr, "initialize_opencl() failed to load OpenCL API!\n" );
    return -1;
  }

  printf( "OpenCL initialized.\n");

  return 0;
}
