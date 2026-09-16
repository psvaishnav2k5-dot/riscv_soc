library verilog;
use verilog.vl_types.all;
entity control_unit is
    port(
        opcode          : in     vl_logic_vector(6 downto 0);
        funct3          : in     vl_logic_vector(2 downto 0);
        funct7          : in     vl_logic_vector(6 downto 0);
        BrEq            : in     vl_logic;
        BrLt            : in     vl_logic;
        alu_src         : out    vl_logic;
        ASel            : out    vl_logic;
        alu_op          : out    vl_logic_vector(3 downto 0);
        reg_write_en    : out    vl_logic;
        mem_write       : out    vl_logic;
        mem_read        : out    vl_logic;
        mem_to_reg      : out    vl_logic;
        is_link         : out    vl_logic;
        br_unsigned     : out    vl_logic;
        pc_src          : out    vl_logic_vector(1 downto 0)
    );
end control_unit;
