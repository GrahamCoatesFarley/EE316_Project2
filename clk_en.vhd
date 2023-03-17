library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_en is
    generic (
        max: integer := 2 -- 60ns default
    );

    port (
        clk50: in std_logic;
        clkOut: out std_logic
    );
end clk_en;
 
architecture behavior of clk_en is
    signal count: integer range 0 to max := 0;
begin
    process(clk50)
    begin
        if rising_edge(clk50) then
            if count = max then
                count <= 0;
                clkOut <= '1';
                else
                count <= count + 1;
                clkOut <= '0';
            end if;
        end if;
    end process;

end behavior;