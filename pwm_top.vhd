--Nathan Nguyen

LIBRARY ieee;
USE ieee.std_logic_1164.all;
	
use IEEE.NUMERIC_STD.ALL;

entity pwm_top is
	port(
	clk                        : in std_logic;
   reset                        : in std_logic;
	en 					: in std_logic;
	M_incrementor 		: in std_logic_vector(32-1 downto 0); --M value, 3 possibilities, from the excel sheet forumula
	
	outPWM : out std_LOGIC;
	



	

	iROM_data : in std_LOGIC_VECTOR(15 downto 0); --will be an internal signal in top level, coming from ROM block
	en_pulse : in std_LOGIC;
	RW_sig : in std_LOGIC;
	
	
	
	
	
	
		SRAM_DQ     : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);	-- SRAM Data bus 16 Bits
      SRAM_ADDR   : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);	-- SRAM Address bus 18 Bits
      SRAM_UB_N   : OUT STD_LOGIC;								-- SRAM High-byte Data Mask
      SRAM_LB_N   : OUT STD_LOGIC;								-- SRAM Low-byte Data Mask
      SRAM_WE_N   : OUT STD_LOGIC;								-- SRAM Write Enable
      SRAM_CE_N   : OUT STD_LOGIC;								-- SRAM Chip Enable
      SRAM_OE_N   : OUT STD_LOGIC								-- SRAM Output Enable
		
	
	
	);
end pwm_top;

















architecture behavioral of pwm_top is

component univ_bin_counter is
   generic(N: integer := 8; N2: integer := 255; N1: integer := 0);
   port(
			clk, reset				: in std_logic;
			syn_clr, load, en, up	: in std_logic;
			clk_en 					: in std_logic := '1';			
			d						: in std_logic_vector(N-1 downto 0);
			max_tick, min_tick		: out std_logic;
			q						: out std_logic_vector(N-1 downto 0)		
   );
end component;

component fixed_point_counter is
	generic(N:integer:=32);
	port(
		clk 					: in std_logic;
		en 					: in std_logic;
		reset 				: in std_logic;
		M_incrementor 		: in std_logic_vector(N-1 downto 0); --M value, 3 possibilities, from the excel sheet forumula
		rawAddress 			: out std_logic_vector(N-1 downto 0)  --feed into the SRAM controller to pick address
		--we will be using 256 data points from the SRAM
	);
end component;

component truncate is
	generic(N:integer:=32; W:integer:=8);
	port(
		raw 			: in std_logic_vector(N-1 downto 0);  --from 32-bit custom counter
		truncated     : out std_logic_vector(W-1 downto 0) --feed into the SRAM controller to pick address		
	);
end component;

component SRAM_controller is
	port(
		clk 			: in std_logic; 							--system clock (20ns)
		iaddress 	: in std_logic_vector(7 downto 0);  --after the MUX so good 8-bit address here
		--will be decimal values from 0 to 255
		idata			: in std_logic_vector(15 downto 0); --after the MUX so good 16-bit data here
		RW				: in std_logic; 							--read/write bit
			--read == 1 
			--write == 0
		--ireset : in std_logic;
		en_pulse       : in std_logic; 							
		--for SRAM (could be 60ns long or 1 second long?)
		--this is the enable pulse for this functional block
		odata       : out std_logic_vector(15 downto 0); 	  
		--this is for printing to the 7 segment display
		io       	: inout std_logic_vector(15 downto 0);  
		oaddress    : out std_logic_vector(17 downto 0);   			--add zeros in the front
		OE_bar      : out std_logic;                       --output enable bar
		WE_bar      : out std_logic;                       --write enable bar
		CE_bar      : out std_logic;                       --chip enable bar
		UB_bar      : out std_logic;                       --Upper Byte bar
		LB_bar      : out std_logic                       	--Lower Byte bar
	);
end component;

component pwm_gen is
	generic(
	N						  : integer   :=8; 
	PWM_COUNTER_MAX     : integer   :=128
	);
	
	port(
	clk                        : in std_logic;
	idata  							: in std_logic_vector(N-1 downto 0);
	oPWM                       : out std_logic
	
	);
end component;










--constant addr_N: integer :=32;





signal rawAddress       : std_logic_vector(32-1 downto 0);
signal sramAddr         : std_logic_vector(7 downto 0);  --right before SRAM block
signal rawData          : std_logic_vector(15 downto 0); --right after SRAM block

signal tuncatedData     : std_logic_vector(7 downto 0); --this might change, should be generic
--this the resolution design choice

--signal outPWM :std_LOGIC;






begin

inst_fixed_point_counter:fixed_point_counter
	generic map(N => 32)
	port map(
	clk => clk,
	en => en,
	reset => reset,
	M_incrementor => M_incrementor,
	rawAddress => rawAddress
	);

inst_addr_truncate:truncate
	generic map(N => 32, W => 8)
	port map(
	raw => rawAddress,
	truncated => sramAddr
	);
	
Inst_SRAM_controller: SRAM_Controller 
		port map(
			clk 			=> clk,
			iaddress 	=> sramAddr, --mux_SRAMAddr,  --this does need to be muxed
			idata			=> iROM_data,  --this can be connected to ROM only
			RW				=> RW_sig,			
			en_pulse    => en_pulse, --mux_SRAMPulse,	--this mux might not be needed
			
			odata       => rawData,
			
			--interacting with SRAM directly
			io       	=> SRAM_DQ, 
			oaddress    => SRAM_ADDR,
			OE_bar      => SRAM_OE_N,
			WE_bar      => SRAM_WE_N,
			CE_bar      => SRAM_CE_N,
			UB_bar      => SRAM_UB_N,
			LB_bar      => SRAM_LB_N
		);	


inst_data_truncate:truncate
	generic map(N => 16, W => 8)
	port map(
	raw => rawData,
	truncated => tuncatedData 
	);
	
inst_pwm_gen:pwm_gen
	generic map(N => 8, PWM_COUNTER_MAX => 256)  --why are we going with 8 bits pwm length, if you make the period longer, you use less data points from SRAM
																--this determines how many data samples are actually used from the SRAM
	port map(
	clk => clk,
	idata => tuncatedData,
	oPWM => outPWM
	);
	
	
	
	
	
end behavioral;



