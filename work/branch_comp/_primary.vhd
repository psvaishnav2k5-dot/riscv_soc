library verilog;
use verilog.vl_types.all;
entity branch_comp is
    port(
        rs1_data        : in     vl_logic_vector(31 downto 0);
        rs2_data        : in     vl_logic_vector(31 downto 0);
        br_unsigned     : in     vl_logic;
        BrEq            : out    vl_logic;
        BrLt            : out    vl_logic
    );
end branch_comp;
