library verilog;
use verilog.vl_types.all;
entity alu is
    generic(
        WIDTH           : integer := 32
    );
    port(
        op1             : in     vl_logic_vector;
        op2             : in     vl_logic_vector;
        alu_op          : in     vl_logic_vector(3 downto 0);
        res             : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of WIDTH : constant is 1;
end alu;
