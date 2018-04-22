#!/bin/gawk -f

function output_cur_sig() {
  if (CUR_FN) {
    if(!SKIPPING) {
      gsub( /\s+/, " ", CUR_SIG);

      gsub(CUR_FN, "(*PFN_"CUR_FN")", CUR_SIG);
      printf("typedef %s\n", CUR_SIG) >> hdr_out;

      printf("extern PFN_%s %s;\n", CUR_FN, CUR_FN) >> hdr_out;

      printf("  %s = (PFN_%s)dlsym(libopencl, \"%s\");\n", CUR_FN, CUR_FN, CUR_FN) >> src_out;
    }
    SKIPPING=0;
    CUR_SIG="";
    CUR_FN="";
  }
}

function parse_function_name(line) {
  matches[0] = "";
  if(match(line, /[_a-zA-Z]+[_a-zA-Z0-9]*\(/, matches)) {
    matches[0] = substr(matches[0],1,length(matches[0])-1);
    CUR_FN=matches[0];
    FN_COUNT = FN_COUNT + 1;
    FN_NAMES[FN_COUNT] = CUR_FN;
  }
}

BEGIN {
  #printf("// process_header.gawk -v hdr_out=%s -v src_out=%s", hdr_out, src_out);
  #for (i = 0; i < ARGC; i++) {
  #  printf( " %s", ARGV[i]);
  #}
  #printf("\n");
  FN_NAMES[0] = "";
  FN_COUNT=0;
  SKIPPING=0;
}

/^extern CL_API_ENTRY.*DEPRECATED/ {
  output_cur_sig();

  CUR_SIG=$0;
  CUR_FN="DerpEcated";
  SKIPPING=1;
  next;
}

/^extern CL_API_ENTRY/ {
  output_cur_sig();

  gsub(/ \*/, "*", $0);

  CUR_SIG=$3
  for(i = 4; i <= NF; i++) {
    CUR_SIG=CUR_SIG " " $i;
  }

  parse_function_name($0);

  next;
}

/.+/ { 
  if (CUR_SIG) {  
    gsub(/ \*/, "*", $0);

    if (!CUR_FN) {
      parse_function_name($0);
    }
    CUR_SIG=CUR_SIG " " $0;
    next;
  }
  print $0 >> hdr_out;
  next;
}

// {
  output_cur_sig();
}

END {
  output_cur_sig();

  for ( i = 1; i <= FN_COUNT; i = i+1 ) {
    printf("PFN_%s %s = 0;\n", FN_NAMES[i], FN_NAMES[i]) >> src_out_decl;
  }
}