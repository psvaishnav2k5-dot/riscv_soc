library verilog;
use verilog.vl_types.all;
entity reg_file is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        write_en        : in     vl_logic;
        rd              : in     vl_logic_vector(4 downto 0);
        write_data      : in     vl_logic_vector(31 downto 0);
        rs1             : in     vl_logic_vector(4 downto 0);
        read_data1      : out    vl_logic_vector(31 downto 0);
        rs2             : in     vl_logic_vector(4 downto 0);
        read_data2      : out    vl_logic_vector(31 downto 0)
    );
end reg_file;
