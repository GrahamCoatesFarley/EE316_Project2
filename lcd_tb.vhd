library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_tb is 
end lcd_tb;

architecture testbench of lcd_tb is
    component lcd_manager is
        port(
		clk				 : in  std_logic;
		reset			    : in  std_logic;
		System_State    : in  std_logic_vector(2 downto 0);
		ADDRESS			 : in  std_LOGIC_VECTOR(7 downto 0);
		Data				 : in  std_LOGIC_VECTOR(15 downto 0);
		
		LCD_ON      	 : OUT STD_LOGIC;										-- LCD Power ON/OFF
      LCD_BLON    	 : OUT STD_LOGIC;										-- LCD Back Light ON/OFF
      LCD_RW      	 : OUT STD_LOGIC;										-- LCD Read/Write Select, 0 = Write, 1 = Read
      LCD_EN      	 : OUT STD_LOGIC := '0';							-- LCD Enable
      LCD_RS       	 : OUT STD_LOGIC := '0';							-- LCD Command/Data Select, 0 = Command, 1 = Data
      LCD_DATA    	 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := X"00"	-- LCD Data bus 8 bits
	);
    end component;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal System_State : std_logic_vector(2 downto 0) := "000";
    signal ADDRESS : std_LOGIC_VECTOR(7 downto 0) := X"00";
    signal Data : std_LOGIC_VECTOR(15 downto 0) := X"0000";

    signal LCD_ON : std_logic;
    signal LCD_BLON : std_logic;
    signal LCD_RW : std_logic;
    signal LCD_EN : std_logic;
    signal LCD_RS : std_logic;
    signal LCD_DATA : std_logic_vector(7 downto 0);

begin
    clk <= not clk after 10 ns; 

    process
    begin
		-- Startup
		reset <= '0';
		wait for 44200 us; 
	
		-- Genaral opperation
		System_State <= "000";
		wait for 10 ms;
		
		System_State <= "001";
		wait for 200 ms;
		
		System_State <= "010";
		ADDRESS <= X"CC";
		Data <= X"FEED";
		wait for 1000 ms;
		
		System_State <= "011";
		ADDRESS <= X"AB";
		Data <= X"0A1D";
		wait for 200 ms;
		
		reset <= '1';
		wait for 10 ms;
		
		reset <= '0';
		System_State <= "110";
		wait for 200 ms;
        wait;  
    end process;
    
    uut: lcd_manager port map(
        clk => clk,
        reset => reset,
        System_State => System_State,
        ADDRESS => ADDRESS,
        Data => Data,
        LCD_ON => LCD_ON,
        LCD_BLON => LCD_BLON,
        LCD_RW => LCD_RW,
        LCD_EN => LCD_EN,
        LCD_RS => LCD_RS,
        LCD_DATA => LCD_DATA
    );

end testbench;