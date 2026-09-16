library verilog;
use verilog.vl_types.all;
entity hazard_unit is
    port(
        ID_EX_mem_read  : in     vl_logic;
        ID_EX_rd        : in     vl_logic_vector(4 downto 0);
        IF_ID_rs1       : in     vl_logic_vector(4 downto 0);
        IF_ID_rs2       : in     vl_logic_vector(4 downto 0);
        PC_write        : out    vl_logic;
        IF_ID_write     : out    vl_logic;
        ID_EX_flush     : out    vl_logic
    );
end hazard_unit;
