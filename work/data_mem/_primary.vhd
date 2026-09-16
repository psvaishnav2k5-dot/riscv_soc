library verilog;
use verilog.vl_types.all;
entity data_mem is
    port(
        clk             : in     vl_logic;
        addr            : in     vl_logic_vector(31 downto 0);
        wdata           : in     vl_logic_vector(31 downto 0);
        byte_en         : in     vl_logic_vector(3 downto 0);
        we              : in     vl_logic;
        rdata           : out    vl_logic_vector(31 downto 0)
    );
end data_mem;
