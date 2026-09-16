library verilog;
use verilog.vl_types.all;
entity timer_ctrl is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        addr            : in     vl_logic_vector(4 downto 0);
        wdata           : in     vl_logic_vector(31 downto 0);
        we              : in     vl_logic;
        re              : in     vl_logic;
        rdata           : out    vl_logic_vector(31 downto 0);
        timer_irq       : out    vl_logic
    );
end timer_ctrl;
