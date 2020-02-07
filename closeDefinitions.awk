# Usage: awk -f closeDefinitions.awk ProcKami
#
# This awk script scans the given directory for Coq definitions. It
# then checks to see how may files contain calls to each defined term
# and rewrites those definitions that are not referenced in more than
# one file so that they are local definitions.
#
# KNOWN BUGS
#   1. throws a Bash error when trying to determine the number of
#      times a term is referenced when the term includes a single quote
#      character.


BEGIN {
  while (("grep --recursive --include '*.v' Definition " ARGV[1] | getline def) > 0) {
    if (match (def, "^([^:]*):[[:space:]]*Definition[[:space:]]*([^[:space:]]*)", a)) {
      sourceName = a[1];
      name = a[2];

      print ("filename: " sourceName " name: " name);

      # I. check if definition is used in more than one file:
      system ("grep --color --recursive --include '*.v' '" name "' '" ARGV[1] "' | cut --fields=1 --delimiter=' ' | uniq");
      "grep --color --recursive --include '*.v' '" name "' '" ARGV[1] "' | cut --fields=1 --delimiter=' ' | uniq | wc -l" | getline numCallLocs;

      print ("name called in " numCallLocs " locations.");
      if (numCallLocs == 1) {
        # TODO: use sed instead:
        # system("sed 's/Definition[[:space:]]+" name "/Local Definition " name "/' " sourceName);
        # system ("~/OperatingProcedures/substitute.sh 'Definition " name "' 'Local Definition " name "' " sourceName);
      }
    }
  }
}
