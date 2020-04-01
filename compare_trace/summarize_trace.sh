# This script parses the trace file produced by the ProcKami model
# and outputs a summarized version of this trace.

{
  print $0
  if (match ($0, "Mode: ([0-3])", matches)) {
    currInst["mode"] = matches[1]
  }
  if (match ($0, "fetch pkt: { pc:([0-9a-f]*); inst:([0-9a-f]*)", matches)) {
    currInst["pc"] = matches[1]
    currInst["inst"] = matches[2]
  }
  if (match ($0, "Reg Write Wrote [0-9a-f]* to (floating point )?register ([0-9a-f]*)", matches)) {
    currInst["result"] = matches[2]
  }
  if (match ($0, "\\[Device.memDeviceSendReqFn\\] req accepted: ([01])", matches)) {
    currInst["memDeviceReq"]["accepted"] = matches[1] == 1
  }
  if (currInst["memDeviceReq"]["accepted"]) {
    if (match ($0, "\\[Device.memDeviceSendReqFn\\] req: { tag:[0-9a-f]*; memOp:([0-9a-f]*); addr:([0-9a-f]*); data:([0-9a-f]*)", matches)) {
      currInst["memDeviceReq"]["memOp"] = matches[1]
      currInst["memDeviceReq"]["daddr"] = matches[2]
      currInst["memDeviceReq"]["data"]  = matches[3]
    }
  }
  if (match ($0, "(\\[commitRule\\] optCommit)|(\\[Mem.handleMemRes\\])")) {
    output = "mode: " currInst["mode"] " pc: " currInst["pc"] " inst: " currInst["inst"] " reg write: " currInst["result"];
    if (currInst["memDeviceReq"]["accepted"]) {
      output = output " mem op: " currInst["memDeviceReq"]["memOp"] " device offset: " currInst["memDeviceReq"]["daddr"] " mem op data: " currInst["memDeviceReq"]["data"] 
    }
    print output
    delete output
    delete currInst
  }
}
