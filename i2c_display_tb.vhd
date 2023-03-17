library ieee;
use ieee.std_logic_1164.all;

entity i2c_display_tb is
end i2c_display_tb;

architecture testbench of i2c_display_tb is
    component i2c_display is   
        port (
            clk: in std_logic;
        reset: in std_logic;

        data: in std_logic_vector(15 downto 0);

        sda: inout std_logic;
        scl: inout std_logic;

        status: out std_logic
        );
    end component;

    signal clk: std_logic := '0';
    signal reset: std_logic := '0';
    signal data : std_logic_vector(15 downto 0) := (others => '0');
    signal sda: std_logic := '0';
    signal scl: std_logic := '0';
	 signal status: std_logic := '0';
	 
begin

uut: i2c_display port map(
          clk => clk,
        reset => reset,

        data  => data,

        sda  => sda,
        scl => scl,

        status => status
    );
    -- 50 MHz clock
    clk <= not clk after 20 ns;

    process
    begin
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;

        data <= "0000000000000000";
        wait for 400 ms;

        data <= "0000000000000001";
        wait for 400 ms;
    end process;
end testbench;