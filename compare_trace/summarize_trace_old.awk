BEGIN {
  address_count = 0;
}
function pad(string, len, z) {
  z = "0000000000000000";
  return substr(substr(z, length(z) - len) string, length(string) + 1)
}
{
  if ($0 ~ /Mode:/)  {
    x["mode"] = $2;
  }
  if ($0 ~ /PC:/) {
    x["pc"] = $2;
  }
  if (match ($0, "inst:([0-9a-f]*);", a)) {
    x["inst"] = a[1];
  }
  if ($0 ~ /Reg Write Wrote/) {
    x["result"] = $4;
  }
  if (0 != match ($0, "\\[pte_translate\\] the resulting paddr: { valid:1; data:([0-9a-f]*); }", a)) {
    x["addresses"][address_count] = a[1];
    address_count ++;
  }
  if ($0 ~ /Inc PC/) {
    output = "mode: " x["mode"] " pc: " pad(x["pc"], 16) " inst: " pad(x["inst"], 8) " reg: " pad(x["result"], 16);
    for (i = 0; i < address_count; i ++) {
      output = output " " pad(x["addresses"][i], 16);
    }
    print output;
    output = "";
    address_count = 0;
    delete x;
  }
}
