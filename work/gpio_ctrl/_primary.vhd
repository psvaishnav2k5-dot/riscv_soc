library verilog;
use verilog.vl_types.all;
entity gpio_ctrl is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        addr            : in     vl_logic_vector(3 downto 0);
        wdata           : in     vl_logic_vector(31 downto 0);
        we              : in     vl_logic;
        re              : in     vl_logic;
        rdata           : out    vl_logic_vector(31 downto 0);
        ledr            : out    vl_logic_vector(17 downto 0);
        ledg            : out    vl_logic_vector(8 downto 0);
        sw              : in     vl_logic_vector(17 downto 0);
        key             : in     vl_logic_vector(3 downto 0)
    );
end gpio_ctrl;
