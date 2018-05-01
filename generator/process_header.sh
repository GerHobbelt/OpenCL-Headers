function output_cur_proto() {
  if (CUR_FN) {
    if(!SKIPPING) {
      gsub( /\s+/, " ", CUR_SIG);

      gsub("CL_API_CALL "CUR_FN, "(CL_API_CALL *PFN_"CUR_FN")", CUR_SIG);
      printf("typedef %s\n", CUR_SIG) >> hdr_out;

      printf("extern PFN_%s %s;\n", CUR_FN, CUR_FN) >> hdr_out;

      printf("  %s = (PFN_%s)find_lib_func(libopencl, \"%s\");\n", CUR_FN, CUR_FN, CUR_FN) >> src_out;
    }
    SKIPPING=0;
    CUR_SIG="";
    CUR_FN="";
  }
}

function process_proto_line(line) {
  if(!CUR_SIG) {
    CUR_SIG=line;
  } else {
   CUR_SIG=CUR_SIG " " line;
  }

  if(!CUR_FN) {
    matches[0] = "";
    if(match(line, /[_a-zA-Z]+[_a-zA-Z0-9]*\(/)) {
      CUR_FN = substr(line, RSTART, RLENGTH-1);
      FN_COUNT = FN_COUNT + 1;
      FN_NAMES[FN_COUNT] = CUR_FN;
    }
  }

  if(match(line, /\;\s*$/)) {
    output_cur_proto();
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
  CUR_SIG=$0;
  CUR_FN="DerpEcated";
  SKIPPING=1;
  next;
}

/^extern CL_API_ENTRY/ {
  gsub(/ \*/, "*", $0);

  #skip first 2 fields
  line=$3;
  for(i = 4; i <= NF; i++) {
    line=line " " $i;
  }

  process_proto_line(line);
  next;
}

/.+/ { 
  if (CUR_SIG) {  
    gsub(/ \*/, "*", $0);

    process_proto_line($0);
    next;
  }

  print $0 >> hdr_out;
  next;
}

END {
  for ( i = 1; i <= FN_COUNT; i = i+1 ) {
    printf("PFN_%s %s = 0;\n", FN_NAMES[i], FN_NAMES[i]) >> src_out_decl;
  }
}