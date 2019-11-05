# This script generates a trace using Spike and the processor
# model and compares them to determine at which address the two
# traces differ.

xlen="64"

options=$(getopt --options="hx:" --longoptions="forvis:,help,xlen:" -- "$@")
[ $? == 0 ] || error "Invalid command line. The command line includes one or more invalid command line parameters."

eval set -- "$options"
while true
do
  case "$1" in
    --forvis)
      forvis=$2
      shift 2;;
    -h | --help)
      cat <<- EOF
Usage: ./compare_trace.sh [OPTIONS] FILENAME

Runs riscv-tests/FILENAME using Spike and compares the resulting
trace with that produced by the RiscvFormalSpec model (ProcKami).

Options:
  -h|--help
  Displays this message.
  -x|--xlen 32|64
  Specifies whether or not the Spike should run in RV32 or RV64.
  --forvis TRACEFILE
  Compare against a forvis trace rather than against Spike.
  Note: forvis must be run with its --verbosity flag set to 1.

Example
  ./compare_trace.sh -x 32 rv32ui-p-and

Runs riscv-tests/rv32ui-p-and in Spike under RV32 and compares
Spike's trace with that in haskelldump/rv32ui-p-and.

Authors
  * Larry Lee <llee454@gmail.com> 
EOF
      exit 0;;
    -x|--xlen)
      xlen=$2
      shift 2;;
    --)
      shift
      break;;
  esac
done
shift $((OPTIND - 1))

filename=$1

[[ -z $filename ]] && error "Invalid command line. The FILENAME argument is missing."

model_trace_file="haskelldump/$filename.out"
model_trace_file_formatted=$(mktemp reference-model-XXX)
trace_file_formatted=$(mktemp model-XXX)

echo "reference trace file: $trace_file_formatted"
echo "model trace file: $model_trace_file_formatted"

# V. display difference
function build_ref {
  if [[ -z $forvis ]]
  then
    # I. generate spike trace
    spike_trace_file="$filename.out"
    echo "spike is running"
    /scratch/larryl/srcs/riscv-tools/riscv-isa-sim/spike -l --isa="RV${xlen}IMAFDC" riscv-tests/$filename &> $filename.out
    echo "spike is done"

    # III. reformat the spike trace
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
    '  $spike_trace_file > $trace_file_formatted
  else
    echo "reformatting the forvis trace file..."
    awk '
      BEGIN {
        reg_write = ""

        reg_names_matrix[1][1] = "x0"
        reg_names_matrix[1][2] = "ra"
        reg_names_matrix[1][3] = "sp"
        reg_names_matrix[1][4] = "gp"

        reg_names_matrix[2][1] = "x4/tp"
        reg_names_matrix[2][2] = "t0"
        reg_names_matrix[2][3] = "t1"
        reg_names_matrix[2][4] = "t2"

        reg_names_matrix[3][1] = "x8/s0/fp"
        reg_names_matrix[3][2] = "s1"
        reg_names_matrix[3][3] = "a0"
        reg_names_matrix[3][4] = "a1"

        reg_names_matrix[4][1] = "x12/a2"
        reg_names_matrix[4][2] = "a3"
        reg_names_matrix[4][3] = "a4"
        reg_names_matrix[4][4] = "a5"

        reg_names_matrix[5][1] = "x16/a6"
        reg_names_matrix[5][2] = "a7"
        reg_names_matrix[5][3] = "s2"
        reg_names_matrix[5][4] = "s3"

        reg_names_matrix[6][1] = "x20/s4"
        reg_names_matrix[6][2] = "s5"
        reg_names_matrix[6][3] = "s6"
        reg_names_matrix[6][4] = "s7"

        reg_names_matrix[7][1] = "x24/s8"
        reg_names_matrix[7][2] = "s9"
        reg_names_matrix[7][3] = "s10"
        reg_names_matrix[7][4] = "s11"

        reg_names_matrix[8][1] = "x28/t3"
        reg_names_matrix[8][2] = "t4"
        reg_names_matrix[8][3] = "t5"
        reg_names_matrix[8][4] = "t6"

        /* initialize the register values */
        for (i in reg_names_matrix) {
          for (j in reg_names_matrix [i]) {
            reg_name = reg_names_matrix [i][j]
            registers [reg_name]     = "0"
            new_registers [reg_name] = "0"
          }
        }
      }
      {
        /* update the register values matrix and detect register values updates */
        for (i in reg_names_matrix) {
          pattern = reg_names_matrix [i][1] "[[:space:]]*\\.*([0-9a-f]*)_\\.*([0-9a-f]*)_\\.*([0-9a-f]*)_\\.*([0-9a-f]*)[[:space:]]*" reg_names_matrix [i][2] "[[:space:]]*\\.*([0-9a-f]*)_\\.*([0-9a-f]*)_\\.*([0-9a-f]*)_\\.*([0-9a-f]*)[[:space:]]*" reg_names_matrix [i][3] "[[:space:]]*\\.*([0-9a-f]*)_\\.*([0-9a-f]*)_\\.*([0-9a-f]*)_\\.*([0-9a-f]*)[[:space:]]*" reg_names_matrix [i][4] "[[:space:]]*\\.*([0-9a-f]*)_\\.*([0-9a-f]*)_\\.*([0-9a-f]*)_\\.*([0-9a-f]*)"
          if (match ($0, pattern, a)) {
            new_registers[reg_names_matrix [i][1]] = a[1]  a[2]  a[3]  a[4]
            new_registers[reg_names_matrix [i][2]] = a[5]  a[6]  a[7]  a[8]
            new_registers[reg_names_matrix [i][3]] = a[9]  a[10] a[11] a[12]
            new_registers[reg_names_matrix [i][4]] = a[13] a[14] a[15] a[16]
            for (j in reg_names_matrix [i]) {
              reg_name = reg_names_matrix [i][j]
              if (registers [reg_name] != new_registers [reg_name]) {
                reg_write = new_registers [reg_name]
                registers [reg_name] = new_registers [reg_name]
              }
            }
          }
        }
        if (match ($0, "inum:[[:digit:]]*  pc 0x([0-9a-f]*)  instr 0x_([0-9a-f]*)_([0-9a-f]*)  priv ([[:digit:]])", a)) {
          instr = "mode: " a[4] " pc: 00000000" a[1] " inst: " a[2] a[3] " reg write: "
        }
        if ($0 ~ /Run_State/) {
          print instr reg_write " physical addresses:";
          instr = ""
          reg_write = ""
        }
      }
    ' $forvis > $trace_file_formatted
    echo "reformated the forvis trace file."
  fi
}

function build_model {
  # IV. reformat the model trace
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
}

build_ref & build_model
sleep 5
vimdiff $trace_file_formatted $model_trace_file_formatted
