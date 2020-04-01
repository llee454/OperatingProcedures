BEGIN {
  address_count = 0;
}
function pad(string, len, z) {
  z = "0000000000000000";
  return substr(substr(z, length(z) - len) string, length(string) + 1)
}
{
  if (match ($0, "([[:digit:]]) 0x([0-9a-f]*) \\(0x([0-9a-f]*)\\)( x *[[:digit:]]* 0x([0-9a-f]*))?", a)) {
    # x["instruction"] = "mode: " a[1] " pc: " a[2] " inst: " a[3];
    x["instruction"] = "mode: " a[1] " pc: " pad(a[2], 16) " inst: " pad(a[3], 8) " reg: " pad(a[5], 16);

    output = x["instruction"];
    for (i = 0; i < address_count; i ++) {
      output = output " dev paddr: " pad(x["addresses"][i], 16);
    } 
    print output;
    output = "";
    address_count = 0;
    delete x;
  }
  if (match ($0, "\\[translate\\] physical address: ([0-9a-f]*)", a)) {
    x["addresses"][address_count] = a[1];
    address_count ++;
  }
  if (match ($0, "core   [[:digit:]]: exception ([_a-z]*), epc 0x([0-9a-f]*)", a)) {
    print "exception type: " a[1] " at address: " pad(a[2], 16);
  }
  if ($0 ~ /exception|tval/) {
    output = "";
    address_count = 0;
    delete x;
  }
}
