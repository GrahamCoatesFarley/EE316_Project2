--Nathan Nguyen (tested and works)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity fixed_point_counter is
	generic(N:integer:=32);
	port(
		state_bits			: in std_logic_vector(2 downto 0);
		clk 					: in std_logic;
		en 					: in std_logic;
		reset 				: in std_logic;
		--M_incrementor 		: in std_logic_vector(N-1 downto 0); --M value, 3 possibilities, from the excel sheet forumula
		rawAddress 			: out std_logic_vector(N-1 downto 0)  --feed into the SRAM controller to pick address
		--we will be using 256 data points from the SRAM
	);
end fixed_point_counter;


architecture arch of fixed_point_counter is 

signal regCounter 		: unsigned(N-1 downto 0);
signal regIncrementor 	: unsigned(N-1 downto 0); --:= (others=>'0')


--195 clk cycles must be skipped before the next read from SRAM in
--60 hz out (will read the same data a few times in a row)
--120 hz out (will read the same data a few times in a row)
--1000 hz out (will not " ")
--dont do modulo with 2 signal counting variables, pull the top bits

begin

	process(clk)  --Handles Josh's state machine
	begin
		if (rising_edge(clk)) then
			case state_bits is
				when "101" =>
                --pwm60
					 regIncrementor <= to_unsigned(5_154, regIncrementor'length);
					 
            when "110" =>
                --pwm120
					 regIncrementor <= to_unsigned(10_308, regIncrementor'length);
					 --regIncrementor <= unsigned(10_308);
					 
					 
				when "111" =>
                --pwm1k
					 regIncrementor <= to_unsigned(85_899, regIncrementor'length);
					 --regIncrementor <= to_unsigned(85_899);
					 
            when others =>
                regIncrementor <= to_unsigned(0, regIncrementor'length); --std_logic_vector(to_unsigned(internalCount, N)) else '1'
				
			end case;
		end if;
	end process;

--5,153.96076
--10,307.92151
--85,899.34592




--regIncrementor <= unsigned(M_incrementor);
rawAddress <= std_logic_vector(regCounter);


	process(clk)
	begin
		if (rising_edge(clk)) then 
			if (reset = '1') then  
				regCounter <= to_unsigned(0, regCounter'length);
			
			elsif (en = '1') then
				regCounter <= regCounter + regIncrementor;
			
			end if;
		end if;
	end process;
end arch;