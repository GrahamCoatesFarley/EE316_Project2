library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity statemachine_tb is
end statemachine_tb;

architecture testbench of statemachine_tb is
    component state_machine is
        port (
            clk: in std_logic;
            reset: in std_logic;
            key0: in std_logic; -- reset
            key1: in std_logic; -- test <--> pause
            key2: in std_logic; -- pwm -> test <--> pwm60
            key3: in std_logic; -- pwm60 -> pwm120 -> pwm1k -> pwm60
            addr: in std_logic_vector(7 downto 0);
    
            state_out: out std_logic_vector(2 downto 0)
        );
    end component;

    signal clk: std_logic := '0';
    signal reset: std_logic := '0';
    signal key0: std_logic := '0';
    signal key1: std_logic := '0';
    signal key2: std_logic := '0';
    signal key3: std_logic := '0';

    signal addr: std_logic_vector(7 downto 0) := (others => '0');

    signal state_out: std_logic_vector(2 downto 0) := (others => '0');

begin
    clk <= not clk after 10 ns; -- 50 MHz clock

    uut: state_machine port map (
        clk => clk,
        reset => reset,
        key0 => key0,
        key1 => key1,
        key2 => key2,
        key3 => key3,
        addr => addr,
        state_out => state_out
    );

    process
    begin
        reset <= '1';
        wait for 40 ns;

        reset <= '0';
        wait for 20 ns;

        key0 <= '1';
        wait for 20 ns;

        key0 <= '0';
        wait for 20 ns;

        -- press key1 twice
        for i in 1 to 2 loop
            key1 <= '1';
            wait for 20 ns;

            key1 <= '0';
            wait for 20 ns;
        end loop;

        key2 <= '1';
        wait for 20 ns;

        key2 <= '0';
        wait for 20 ns;

        -- press key3 three times
        for i in 1 to 3 loop
            key3 <= '1';
            wait for 20 ns;

            key3 <= '0';
            wait for 20 ns;
        end loop;

        key2 <= '1';
        wait for 20 ns;
        
        key2 <= '0';
        wait for 20 ns;


        wait;
    end process;

end testbench;