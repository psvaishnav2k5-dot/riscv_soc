library verilog;
use verilog.vl_types.all;
entity fwd_unit is
    port(
        EX_MEM_reg_write: in     vl_logic;
        EX_MEM_rd       : in     vl_logic_vector(4 downto 0);
        MEM_WB_reg_write: in     vl_logic;
        MEM_WB_rd       : in     vl_logic_vector(4 downto 0);
        ID_EX_rs1       : in     vl_logic_vector(4 downto 0);
        ID_EX_rs2       : in     vl_logic_vector(4 downto 0);
        ForwardA        : out    vl_logic_vector(1 downto 0);
        ForwardB        : out    vl_logic_vector(1 downto 0)
    );
end fwd_unit;
