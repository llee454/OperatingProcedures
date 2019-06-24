# This script generates a trace using Spike and the processor model and compares them to determine at which address the two traces differ.

# test_file="riscv-tests/rv64ui-v-add"

# I. generate spike trace
spike_trace_file="rv64ui-p-add.out"
echo "spike is running"
# /scratch/larryl/srcs/riscv-tools/riscv-isa-sim/spike -l --isa="RV32IMAFDC" riscv-tests/rv32uf-v-fadd &> rv32uf-v-fadd.out
/scratch/larryl/srcs/riscv-tools/riscv-isa-sim/spike -l riscv-tests/rv64ui-p-add &> rv64ui-p-add.out
echo "spike is done"

# II. generate the model trace
model_trace_file="haskelldump/rv64ui-p-add.out"
# srun --cpus-per-task=2 --mem=128000 runElf.sh -v --haskell riscv-tests/rv64ui-v-add

# III. reformat the spike trace
spike_trace_file_formatted=$(mktemp)
awk '
  BEGIN {
    address_count = 0;
  }
  {
    if (match ($0, "([[:digit:]]) 0x([0-9a-f]*) \\(0x([0-9a-f]*)\\)( x *[[:digit:]]* 0x([0-9a-f]*))?", a)) {
      # x["instruction"] = "mode: " a[1] " pc: " a[2] " inst: " a[3];
      x["instruction"] = "mode: " a[1] " pc: " a[2] " inst: " a[3] " reg write: " a[5] " physical addresses:";

      output = x["instruction"];
      for (i = 0; i < address_count; i ++) {
        output = output " " sprintf ("%.16x", x["addresses"][i]);
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
      print "exception type: " a[1] " at address: " sprintf ("%.16x", a[2]);
    }
    if ($0 ~ /exception|tval/) {
      output = "";
      address_count = 0;
      delete x;
    }
  }
' $spike_trace_file > $spike_trace_file_formatted

# IV. reformat the model trace
model_trace_file_formatted=$(mktemp)
awk '
  BEGIN {
    address_count = 0;
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
      #output = "mode: " x["mode"] " pc: " x["pc"] " inst: " x["inst"];
      output = "mode: " x["mode"] " pc: " x["pc"] " inst: " x["inst"] " reg write: " x["result"] " physical addresses:";
      for (i = 0; i < address_count; i ++) {
        output = output " " sprintf ("%.16x", x["addresses"][i]);
      }
      print output;
      output = "";
      address_count = 0;
      delete x;
    }
  }
' $model_trace_file > $model_trace_file_formatted

echo $spike_trace_file_formatted
echo $model_trace_file_formatted

# V. display difference
vimdiff $spike_trace_file_formatted $model_trace_file_formatted
