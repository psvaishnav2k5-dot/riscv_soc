library verilog;
use verilog.vl_types.all;
entity uart_ctrl is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        addr            : in     vl_logic_vector(3 downto 0);
        wdata           : in     vl_logic_vector(31 downto 0);
        we              : in     vl_logic;
        re              : in     vl_logic;
        rdata           : out    vl_logic_vector(31 downto 0);
        uart_tx         : out    vl_logic;
        uart_rx         : in     vl_logic
    );
end uart_ctrl;
