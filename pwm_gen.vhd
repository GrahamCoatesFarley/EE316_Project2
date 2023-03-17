--Nathan Nguyen

LIBRARY ieee;
USE ieee.std_logic_1164.all;
	
use IEEE.NUMERIC_STD.ALL;

entity pwm_gen is
	generic(
	N						  : integer   :=8; 
	PWM_COUNTER_MAX     : integer   :=256
	);
	
	port(
	clk                        : in std_logic;
	idata  							: in std_logic_vector(N-1 downto 0);
	oPWM                       : out std_logic
	
	);
end pwm_gen;



architecture behavioral of pwm_gen is

--signal internalCount 		: unsigned(N-1 downto 0);
signal internalCount : integer:=0;
signal regData : std_logic_vector(N-1 downto 0);

begin


regData <= idata;


--simple counter
	process(clk)
	begin
	if rising_edge(clk) then
	   if internalCount <= PWM_COUNTER_MAX-1 then
	       internalCount <= internalCount + 1;
	   else
	       internalCount <= 0;
	   end if;
    end if;
    end process;
	 
	 
	 
	 
--comparator statements that drive the PWM signal
--to_unsigned(<integer_value>, <bit_width>);
oPWM <= '0' when regData < std_logic_vector(to_unsigned(internalCount, N)) else '1';
	 

end behavioral;

	