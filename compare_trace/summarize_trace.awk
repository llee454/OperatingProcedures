# This script parses the trace file produced by the ProcKami model
# and outputs a summarized version of this trace.
BEGIN {
  lineNumber = 0
}
function pad(string, len, z) {
  z = "0000000000000000"
  return substr(substr(z, length(z) - len) string, length(string) + 1)
}
{
  if (match ($0, "Config: { xlen:[0-3]; satp_mode:[0-9a-f]*; mode:([0-3]);", matches)) {
    currInst["mode"] = matches[1]
  }
  if (match ($0, "\\[decodeExecRule\\] decoder pkt: { fst:{ funcUnitTag:[0-9a-f]*; instTag:[0-9a-f]; inst:([0-9a-f]*);", matches)) {
    currInst["inst"] = matches[1]
  }
  if (match ($0, "Reg Write: ([0-9a-f]*) ([0-9a-f]*)", matches)) {
    currInst["regWrite"]["reg"] = matches[1]
    currInst["regWrite"]["value"] = matches[2]
  }
  if (match ($0, "\\[commitRule\\] optCommit: { valid:[01]; data:{ execCxt:{ pc:([0-9a-f]*)", matches)) {
    currInst["pc"] = matches[1]
    # currInst["memDeviceReq"]["paddr"] = matches[1]
    # currInst["memDeviceReq"]["data"]  = matches[2]
  }
  if (match ($0, "\\[commit\\] done\\.")) {
    output = "mode: " currInst["mode"] " pc: " pad(currInst["pc"], 16) " inst: " pad(currInst["inst"], 8) " reg: " pad(currInst["regWrite"]["value"], 16)
    if (currInst["memDeviceReq"]["accepted"]) {
      output = output " dev paddr: " pad(currInst["memDeviceReq"]["paddr"], 16) " data: " pad(currInst["memDeviceReq"]["data"], 16)
    }
    # output = output " line: " lineNumber
    print output
    output = ""
    delete currInst
  }
  lineNumber = lineNumber + 1
}
