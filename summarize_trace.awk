# This script parses the trace file produced by the ProcKami model
# and outputs a summarized version of this trace.
BEGIN {
}
function pad(string, len, z) {
  z = "0000000000000000";
  return substr(substr(z, length(z) - len) string, length(string) + 1)
}
{
  if (match ($0, "Mode: ([0-3])", matches)) {
    currInst["mode"] = matches[1]
  }
  if (match ($0, "\\[commit\\] exec_context_pkt: { pc:([0-9a-f]*);.*inst:([0-9a-f]*);", matches)) { 
    currInst["pc"] = matches[1]
    currInst["inst"] = matches[2]
  }
  if (match ($0, "Reg Write Wrote ([0-9a-f]*) to (floating point )?register ([0-9a-f]*)", matches)) {
    currInst["regWrite"]["value"] = matches[1]
    currInst["regWrite"]["reg"] = matches[3]
  }
  if (match ($0, "\\[decodeExecRule\\] memory unit req accepted: 1")) {
    currInst["memDeviceReq"]["accepted"] = 1
  }
  if (match ($0, "\\[Arbiter.sendReq\\] clientReq: { tag:[0-9a-f]*; req:{ dtag:[0-9a-f]*; offset:[0-9a-f]*; paddr:([0-9a-f]*); memOp:[0-9a-f]*; data:([0-9a-f]*); }; }", matches)) {
    currInst["memDeviceReq"]["paddr"] = matches[1]
    currInst["memDeviceReq"]["data"]  = matches[2]
  }
  if (match ($0, "\\[commit\\] done\\.")) {
    output = "mode: " currInst["mode"] " pc: " pad(currInst["pc"], 16) " inst: " pad(currInst["inst"], 8) " reg: " pad(currInst["regWrite"]["value"], 16)
    if (currInst["memDeviceReq"]["accepted"]) {
      output = output " dev paddr: " pad(currInst["memDeviceReq"]["paddr"], 16) " data: " pad(currInst["memDeviceReq"]["data"], 16)
    }
    print output
    output = ""
    delete currInst
  }
}
