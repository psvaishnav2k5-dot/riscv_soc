library verilog;
use verilog.vl_types.all;
entity top_core is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        imem_addr       : out    vl_logic_vector(31 downto 0);
        imem_data       : in     vl_logic_vector(31 downto 0);
        dmem_addr       : out    vl_logic_vector(31 downto 0);
        dmem_wdata      : out    vl_logic_vector(31 downto 0);
        dmem_byte_en    : out    vl_logic_vector(3 downto 0);
        dmem_we         : out    vl_logic;
        dmem_re         : out    vl_logic;
        dmem_rdata      : in     vl_logic_vector(31 downto 0);
        dbg_pc          : out    vl_logic_vector(31 downto 0);
        dbg_alu_result  : out    vl_logic_vector(31 downto 0)
    );
end top_core;
