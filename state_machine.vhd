library ieee;
use ieee.std_logic_1164.all;

entity state_machine is
    port (
        clk: in std_logic;
        reset: in std_logic;
        key0: in std_logic; -- reset
        key1: in std_logic; -- test <--> pause
        key2: in std_logic; -- pwm -> test <--> pwm60
        key3: in std_logic; -- pwm60 -> pwm120 -> pwm1k -> pwm60
        
		  
		  addr: in std_logic_vector(7 downto 0); --  counter_value: in std_logic_vector(7 downto 0);

		  
		  RW : out std_logic;
		  enable: out std_logic;
		  
		  read_rom: out std_logic;
        counter_clear: out std_logic;
		  
		  
        state_out: out std_logic_vector(2 downto 0)
    );
end state_machine;

architecture behavioral of state_machine is
    type state_type is (init, init_press, test, pause, pwm60, pwm120, pwm1k);
    signal state: state_type := init;

    signal key0_last: std_logic := '0';
    signal last_addr : std_logic_vector(7 downto 0) := (others => '0');
begin
    process(clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= init;
                counter_clear <= '1';
                enable <= '1';
            else
                case state is
                    when init =>
                        if key0 = '0' then
                            state <= init_press;
                            counter_clear <= '1';
                            rw <= '0';
                        else 
                            rw <= '1';
                        end if;

                    when init_press =>
                            counter_clear <= '0';
                            read_rom <= '1';
                            last_addr <= addr;
                            if(addr = x"00" and last_addr = x"ff") then
                                state <= test;
                                read_rom <= '0';
                                rw <= '1';
                            end if;								
                    when test =>
                        if key1 = '1' then
                            state <= pause;
                        elsif key2 = '1' then
                            state <= pwm60;
                        end if;
                    when pause =>
                        enable <= '0';
                        if key1 = '1' then
                            state <= test;
                            enable <= '1';
                        end if;
                    when pwm60 =>
                        if key2 = '1' then
                            state <= test;
                        elsif key3 = '1' then
                            state <= pwm120;
                        end if;
                    when pwm120 =>
                        if key2 = '1' then
                            state <= test;  
                        elsif key3 = '1' then
                            state <= pwm1k;
                        end if;
                    when pwm1k =>
                        if key2 = '1' then
                            state <= test;
                        elsif key3 = '1' then
                            state <= pwm60;
                        end if;
                    when others =>
                        state <= init;
                end case;
            end if;
        end if;
    end process;

    process(state)
    begin
        case state is
            when init =>
                state_out <= "001";
					 
            when init_press =>
                state_out <= "001";
					 
            when test =>
                state_out <= "011";
					 
            when pause =>
                state_out <= "100";
					 
            when pwm60 =>
                state_out <= "101";
					 
            when pwm120 =>
                state_out <= "110";
					 
            when pwm1k =>
                state_out <= "111";
					 
            when others =>
                state_out <= "000";
        end case;
    end process;

end behavioral;