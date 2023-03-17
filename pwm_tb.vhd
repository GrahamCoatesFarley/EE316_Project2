library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_tb is
end pwm_tb;

architecture tb of pwm_tb is
    component pwm_gen is
        generic(
            N						  : integer   :=8; 
            PWM_COUNTER_MAX     : integer   :=256
            );
            
            port(
            clk                        : in std_logic;
            idata  							: in std_logic_vector(N-1 downto 0);
            oPWM                       : out std_logic
            
            );
    end component;

    signal clk : std_logic := '0';
    signal oPWM : std_logic;
    signal idata : std_logic_vector(7 downto 0) := "00000000";
begin
    clk <= not clk after 10ns;

    uut: pwm_gen generic map(
        N => 8,
        PWM_COUNTER_MAX => 256
        ) port map(
        clk => clk,
        idata => "00000000",
        oPWM => oPWM
        );

        process
        begin
            iData <= x"7f";

            wait;
        end process;
end tb; 