files=$(find ProcKami -name "*.v")

awk '
  BEGIN {
    inRegRead = 0;
    inRegWrite = 0;
    regKindPattern = "[[:alnum:](]*[[:space:][:alnum:])]*"
    regNamePattern = "[[:alnum:](@^\"]*[[:alnum:][:space:]_+)\"]*"
  }  
  function trim(x) {
    gsub (/^ /, "", x);
    gsub (/ $/, "", x);
    return x;
  }
  {
    # 1. process register read actions.
    if ($0 ~ /Read[^[:alnum:]]+/) {
      inRegRead = 1;
      reg["source"] = $0;
    }
    if (inRegRead == 1 && match ($0, ".*:[[:space:]]*(" regKindPattern ")", a)) {
      reg["kind"] = trim(a[1]);
    }
    if (inRegRead == 1 && match ($0, ".*<-[[:space:]]*(" regNamePattern ")", a)) {
      reg["name"] = trim(a[1]);
    }
    if (inRegRead == 1 && $0 ~ /;/) {
      name = reg["name"];
      print "[reg read] name: " name " kind: " reg["kind"] " source: " reg["source"];
      if (name in regs) {
        if (reg["kind"]) {
          if (regs[name]["kind"]) {
            if (regs[name]["kind"] != reg["kind"]) {
              print "WARNING: potential register kind mismatch! reg name: " name
            }
          } else {
            regs[name]["kind"] = reg["kind"];
          }
        }
      } else {
        regs[name]["kind"] = reg["kind"];
        regs[name]["source"] = reg["source"];
      }
      inRegRead = 0;
      delete reg;
    }
    # 2. process register write actions.
    if ($0 ~ /Write[^[:alnum:]]+/) {
      inRegWrite = 1;
      reg["source"] = $0;
    }
    if (inRegWrite == 1 && match ($0, ".*Write[[:space:]]*(" regNamePattern ")", a)) {
      reg["name"] = a[1];
    }
    if (inRegWrite == 1 && match ($0, ".*:[[:space:]]*(" regKindPattern ")", a)) {
      reg["kind"] = a[1];
    }
    if (inRegWrite == 1 && $0 ~ /;/) {
      name = reg["name"];
      print "[reg write] name: " name " kind: " reg["kind"] " source: " reg["source"]
      if (name in regs) {
        if (reg["kind"]) {
          if (regs[name]["kind"]) {
            if (regs[name]["kind"] != reg["kind"]) {
              print "WARNING: potential register kind mismatch! reg name: " name
            }
          } else {
            regs[name]["kind"] = reg["kind"];
          }
        }
      } else {
        regs[name]["kind"] = reg["kind"];
        regs[name]["source"] = reg["source"];
      }
      inRegWrite = 0;
      delete reg;
    }
  }
' $files
