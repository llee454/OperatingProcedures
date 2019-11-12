# This script parses a memory heap file produced by a Haskell program
# that was compiled with the "-prof -fprof-auto" flags, and run with
# the heap trace option "+RTS -p -h -RTS"; and prints out the most
# memory intensive functions.
#
# Example ussage: gawk -f findWorst.awk example.prof | head --lines 10

BEGIN {
  name = "[[:alnum:]\\._]+";
  source = "[[:alnum:]\\/.<>\\-()_,:]+";
  number = "[[:digit:]]+.[[:digit:]]+";
  profEntries[0]["name"] = "test";
}
function sortEntries(index1,entry1,index2,entry2){
  return (entry1["avgMemPerCall"] < entry2["avgMemPerCall"]);
}
{
  if (match ($0, "total alloc = ([[:digit:],]+)", a)) {
    totalMem = a[1];
    gsub(/,/, "", totalMem);
    totalMem = totalMem / 10^6; # total memory consumption in MB.
    printf ("total memory consumption: %.2f MB\n", totalMem);
  }
  if (match ($0, "^[[:space:]]*" name "[[:space:]]+" name "[[:space:]]+" source "[[:space:]]+[[:digit:]]+[[:space:]]+[[:digit:]]+[[:space:]]+" number "[[:space:]]+" number "[[:space:]]+" number "[[:space:]]+" number "$", a)) {
    entry["name"] = $1;
    entry["numCalls"] = $5;
    entry["percentMem"] = $7;
    entry["percentMemTotal"] = $9; # including functions called from the entry function

    if (entry["numCalls"] > 0 && entry["percentMemTotal"] > 0) {
      entry["memTotal"] = entry["percentMemTotal"] * .01 * totalMem; # total memory in MB.
      entry["avgMemPerCall"] = entry["memTotal"] / entry["numCalls"];

      numEntries = length(profEntries) + 1;
      profEntries[numEntries]["name"] = entry["name"];
      profEntries[numEntries]["percentMemTotal"] = entry["percentMemTotal"];
      profEntries[numEntries]["memTotal"] = entry["memTotal"];
      profEntries[numEntries]["avgMemPerCall"] = entry["avgMemPerCall"];
    }
  }
}
END {
  asort(profEntries,sortedEntries,"sortEntries");
  for (i = 1; i < length(sortedEntries); i ++) {
    printf ("%-25s total memory used: %10.2f MB average memory used per call: %.2f MB\n", sortedEntries[i]["name"], sortedEntries[i]["memTotal"], sortedEntries[i]["avgMemPerCall"]);
  }
} 
