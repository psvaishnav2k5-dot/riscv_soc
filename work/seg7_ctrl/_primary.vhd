library verilog;
use verilog.vl_types.all;
entity seg7_ctrl is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        addr            : in     vl_logic_vector(3 downto 0);
        wdata           : in     vl_logic_vector(31 downto 0);
        we              : in     vl_logic;
        re              : in     vl_logic;
        rdata           : out    vl_logic_vector(31 downto 0);
        hex0            : out    vl_logic_vector(6 downto 0);
        hex1            : out    vl_logic_vector(6 downto 0);
        hex2            : out    vl_logic_vector(6 downto 0);
        hex3            : out    vl_logic_vector(6 downto 0);
        hex4            : out    vl_logic_vector(6 downto 0);
        hex5            : out    vl_logic_vector(6 downto 0);
        hex6            : out    vl_logic_vector(6 downto 0);
        hex7            : out    vl_logic_vector(6 downto 0)
    );
end seg7_ctrl;
