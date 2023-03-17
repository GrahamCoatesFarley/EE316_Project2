--Nathan Nguyen

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity truncate is
	generic(N:integer:=32; W:integer:=8);
	port(
		raw 			: in std_logic_vector(N-1 downto 0);  --from 32-bit custom counter
		truncated     : out std_logic_vector(W-1 downto 0) --feed into the SRAM controller to pick address		
	);
end truncate;

--we will be using 256 data points from the SRAM

architecture arch of truncate is 


begin

--just take the top bits, could offset this to take W bits somwhere else in the N bit string of data
truncated <= raw(N-1 downto ((N-1)-(W-1))); 


end arch;

