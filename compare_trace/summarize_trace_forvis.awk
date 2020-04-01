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
