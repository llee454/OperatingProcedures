# Usage gawk -f removeImports.awk EXAMPLE.v
#
# Iterates over the import statements in a Coq file and removes
# those statements that are not necessary.
#
# This program will attempt to compile the file using coqc to
# determine whether or not each import statement can be removed.
#
# If your directory has a _CoqProject file that provides include
# paths and other command line arguments for coqc, this script will
# read the file and pass the arguments to coqc.
#
# Example:
#   find . -name '*.v' -exec gawk -f removeImports.awk {} \;
#   find ProcKami -name '*.v' -exec gawk -f /home/larryl/OperatingProcedures/removeImports.awk {} \;

BEGIN {
  fileName = ARGV[1];
  getline coqcArgs < "_CoqProject"

  while (("grep 'Require Import' " fileName | getline importLine) > 0) {
    ("mktemp 'removeImportsXXXX.v'" | getline tempFileName)
    system ("cp -v " fileName " " tempFileName);
    system ("sed -i 's/" importLine "//' " tempFileName);
    system ("head --lines 20 " tempFileName);

    if (system ("coqc " coqcArgs " " tempFileName) == 0) {
      print ("commenting out: " importLine)
      system ("cp " tempFileName " " fileName);
    } else {
      print ("keeping line: " importLine)
    }
    system ("rm " tempFileName);
  }
}
