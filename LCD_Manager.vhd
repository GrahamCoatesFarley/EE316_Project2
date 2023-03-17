library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LCD_Manager is
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
end LCD_Manager;

architecture behavior of LCD_Manager is

	-- Internal State Declaration
	type stateType is (Start, Init_Hold, Init, Test, Pause, PWM60, PWM120, PWM1000);
	signal Message_State : stateType := Start;
	
	-- Constants for clock enabler
	constant clk_en_cnt_max     : integer := 249999; -- 5ms note: Clear Display and Return Home need at least 1.53ms  
	
	-- Signals for output message_Out
	signal clk_en      	  		: std_logic := '0';
	signal clk_en_cnt  	 	 	: integer range 0 to clk_en_cnt_max := 0;
	signal message_cnt 			: integer := 0;
	signal clk_en_3HZ_cnt  		: integer range 0 to 16666666 := 0;
	signal clk_en_3HZ 	 	   : std_logic := '0';
	
	-- Start up signals 
	signal StartUp      	  			: std_logic := '0';
	signal PowerOn20ms_cnt 			: integer range 0 to 8:= 0;

	-- LCD_EN Signals
	type states is (Start, Mid, Ending);
	signal LCD_EN_State 				: states := Start;
	signal LCD_EN_clk_en_cnt 		: integer range 0 to 83332:= 0;
	signal LCD_EN_clk_en				: std_LOGIC := '0';
	
	-- Change detect
	signal lastdata					: std_LOGIC_VECTOR(15 downto 0);
	signal lastaddr 					: std_LOGIC_VECTOR(7 downto 0);
	signal inputbuf					: std_LOGIC_VECTOR(2 downto 0);
	signal changed						: std_logic := '0';
	
begin
	
	-- LCD Clk enaber 
	process(clk, reset)
	begin
		if reset = '1' then
			LCD_EN_clk_en_cnt <= 0;
			LCD_EN_clk_en     <= '0';
		elsif rising_edge(clk) then
			if(LCD_EN_clk_en_cnt = 83332) then 
				LCD_EN_clk_en 		<= '1';
				LCD_EN_clk_en_cnt <= 0;
			else
				LCD_EN_clk_en_cnt <= LCD_EN_clk_en_cnt + 1;
				LCD_EN_clk_en     <= '0';
			end if;
		end if;
	end process;
	
	-- LCD_EN Manager
	process(clk, reset)
	begin
		if reset = '1' then
			LCD_EN_State <= Start;
			LCD_EN <= '0';
		elsif rising_edge(clk) and LCD_EN_clk_en = '1' then
			case LCD_EN_State is 
				when Start =>
					LCD_EN <= '1';
					LCD_EN_State <= Mid;
				when Mid =>
					LCD_EN <= '0';
					LCD_EN_State <= ending;
				when ending =>
					LCD_EN <= '0';
					LCD_EN_State <= Start;
				when others =>
					LCD_EN <= '0';
					LCD_EN_State <= Start;
			end case;
		end if;
	end process;
	
	-- Clock enabler for the updating LCD 3HZ
	process(clk, reset)
	begin
		if reset = '1' then
			clk_en_3HZ_cnt <= 0;
			clk_en_3HZ     <= '0';
		elsif rising_edge(clk) then 
			if(clk_en_3HZ_cnt = 16666666) then 
				clk_en_3HZ <= '1';
				clk_en_3HZ_cnt <= 0;
			else
				clk_en_3HZ_cnt <= clk_en_3HZ_cnt + 1;
				clk_en_3HZ <= '0';
			end if;
		end if;
	end process;
	
		-- Clock enabler for the updating LCD 1HX
	process(clk, reset)
	begin
		if reset = '1' then
			clk_en_cnt <= 0;
			clk_en     <= '0';
		elsif rising_edge(clk) then --and startUp = '1' then
			if(clk_en_cnt = clk_en_cnt_max) then 
				clk_en <= '1';
				clk_en_cnt <= 0;
			else
				clk_en_cnt <= clk_en_cnt + 1;
				clk_en <= '0';
			end if;
		end if;
	end process;
	
	-- Internal states 
	process(clk, reset, System_State)
	begin
		if rising_edge(clk) and reset = '0' then
			case System_State is 
				when "000"  => Message_State <= Start;
				when "001"  => Message_State <= Init;
				when "010"  => Message_State <= Init;
				when "011"  => Message_State <= Test;
				when "100"  => Message_State <= Pause;
				when "101"  => Message_State <= PWM60;
				when "110"  => Message_State <= PWM120;
				when "111"  => Message_State <= PWM1000;
				when others => Message_State <= Start;
			end case;
			
		elsif rising_edge(clk) and reset = '1' then
			Message_State <= Start;
		end if;
	end process;
	
	-- Defult LCD output that won't be changed in the lookup table and make sure that the componets work	
	LCD_ON   <= '1';
	LCD_BLON <= '1';
	LCD_RW	<= '0';
	
	-- Output Handler
	process(clk, reset, clk_en, Message_State, message_cnt)
	begin
	
		if reset = '1' then -- Reset handler 
			-- General Run Signals
			LCD_DATA      	<= X"00";
			LCD_RS        	<= '0';
			message_cnt 	<= 0;
			
			-- Start up sequence signals
			StartUp 				<= '0';
			PowerOn20ms_cnt 	<= 0;
		
		-- Start Initalizing phase
		elsif rising_edge(clk) and PowerOn20ms_cnt /= 8 and clk_en = '1' then
			case PowerOn20ms_cnt is 
				when 0 => 
					LCD_DATA <= X"30"; 
					LCD_RS	<= '0';				
					PowerOn20ms_cnt <= 1;
				when 1 => 
					LCD_DATA <= X"30"; 
					LCD_RS	<= '0';	
				PowerOn20ms_cnt <= 2;				
				when 2 => 
					LCD_DATA <= X"30"; 
					LCD_RS	<= '0';					
					PowerOn20ms_cnt <= 3;	
				when 3 =>
					LCD_DATA <= X"30"; 
					LCD_RS	<= '0';
					PowerOn20ms_cnt <= 4;
				when 4 =>
					LCD_DATA <= X"38"; 
					LCD_RS	<= '0';
					PowerOn20ms_cnt <= 5;
				when 5 =>
					LCD_DATA <= X"0C"; 
					LCD_RS	<= '0';
					PowerOn20ms_cnt <= 6;
				when 6 =>
					LCD_DATA <= X"06"; 
					LCD_RS	<= '0';
					PowerOn20ms_cnt <= 7;
				when 7 =>
					LCD_DATA <= X"80"; 
					LCD_RS	<= '0';
					StartUp 	<= '1';
					PowerOn20ms_cnt <= 8;
				when others =>
					LCD_DATA 	<= X"00"; 
					LCD_RS		<= '0';
					PowerOn20ms_cnt <= 0;
					StartUp 		<= '0';
			end case;

		-- end Initalizing phase
		elsif	rising_edge(clk) and clk_en = '1' and (System_State /= inputbuf or address /= lastaddr or data /= lastdata) then
			-- if in test mode, and the address or date changed, update. otherwise, don't pay attention to address/data
			changed <= '1';
			inputbuf <= System_State;
			lastaddr <= address;
			lastdata <= data;
		elsif rising_edge(clk) and changed = '1' then
			changed <= '0';
			message_cnt <= 0;
		-- Default run portion
		elsif rising_edge(clk) and clk_en = '1' and StartUp = '1' then	
			case Message_State is  -- Output look up handler
				when Start =>
					message_cnt <= 0;   -- Start/null
					LCD_DATA <= X"01"; -- clear
					LCD_RS <= '0';
				when Init =>
					case message_cnt is -- Initializing
						when 0 =>
							-- clear display
							LCD_RS <= '0';
							LCD_DATA <= x"01"; 						
							message_cnt <= message_cnt + 1;
						when 1 =>
							LCD_DATA <= X"80"; -- Top left
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 2 => 
							LCD_DATA <= X"49";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 3 => 
							LCD_DATA <= X"6E";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 4 => 
							LCD_DATA <= X"69";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 5 => 
							LCD_DATA <= X"74";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 6 => 
							LCD_DATA <= X"69";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 7 => 
							LCD_DATA <= X"61";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 8 => 
							LCD_DATA <= X"6C";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 9 => 
							LCD_DATA <= X"69";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 10 => 
							LCD_DATA <= X"6E";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 11 => 
							LCD_DATA <= X"7A";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 12 => 
							LCD_DATA <= X"69";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 13 => 
							LCD_DATA <= X"6E";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 14 => 
							LCD_DATA <= X"67";
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when others   =>
							LCD_RS <= '0';
							LCD_DATA <= X"80";
							if clk_en_3HZ = '1' then
								message_cnt <= 0; -- null
							end if;
						end case;
				when Test =>
					case message_cnt is -- Test Mode
						when 0 =>
							LCD_DATA <= X"80"; -- Top left
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 1 =>
							-- clear display
							LCD_RS <= '0';
							LCD_DATA <= x"01"; 
							message_cnt <= message_cnt + 1;
						when 2 =>
							LCD_DATA <= X"54"; -- T
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 3 =>
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 4 =>
							LCD_DATA <= X"73"; -- s
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 5 =>
							LCD_DATA <= X"74"; -- t
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 6 => -- Space
							LCD_DATA <= X"85";
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 7 => -- "Mode" section
							LCD_DATA <= X"4D"; -- M
							 LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 8 =>
							LCD_DATA <= X"6F"; -- o
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 9 =>
							LCD_DATA <= X"64"; -- d
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 10 =>
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 11 => -- Moves cursor to the second row
							LCD_DATA <= X"C0";
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 12 =>-- writing address
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case ADDRESS(7 downto 4) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 13 =>-- writing address
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case ADDRESS(3 downto 0) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 14 =>
							LCD_RS <= '0';
							LCD_DATA <= X"C3";
							message_cnt <= message_cnt + 1;
						when 15 =>-- data
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case Data(15 downto 12) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 16 =>-- data
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case Data(11 downto 8) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 17 =>-- data
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case Data(7 downto 4) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 18 =>-- data
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case Data(3 downto 0) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when others =>
							LCD_RS <= '0';
							LCD_DATA <= X"80";
							if clk_en_3HZ = '1' then
								message_cnt <= 0; -- null
							end if;
					end case;
				when Pause =>
					case message_cnt is -- Pause Mode
						when 0 =>
							LCD_DATA <= X"80"; -- Top left
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 1 =>
							-- clear display
							LCD_RS <= '0';
							LCD_DATA <= x"01"; 
							message_cnt <= message_cnt + 1;
						when 2 =>
							LCD_DATA <= X"50";  -- P
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 3 =>
							LCD_DATA <= X"61"; -- a
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 4 =>
							LCD_DATA <= X"75"; -- u
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 5 =>
							LCD_DATA <= X"73"; -- s
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 6 =>
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 7 => -- Space
							LCD_DATA <= X"86";
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 8 => -- "Mode" section
							LCD_DATA <= X"4D"; -- M
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 9 =>
							LCD_DATA <= X"6F"; -- o
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 10 =>
							LCD_DATA <= X"64"; -- d
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 11 =>
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 12 =>
							LCD_DATA <= X"C0"; -- move to second row
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 13 =>-- writing address
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case ADDRESS(7 downto 4) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 14 =>-- writing address
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case ADDRESS(3 downto 0) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 15 =>
							LCD_RS <= '0';
							LCD_DATA <= X"C3";
							message_cnt <= message_cnt + 1;
						when 16 =>-- data
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case Data(15 downto 12) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 17 =>-- data
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case Data(11 downto 8) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 18 =>-- data
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case Data(7 downto 4) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						when 19 =>-- data
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
							case Data(3 downto 0) is
								when X"0" => LCD_DATA <= X"30";
								when X"1" => LCD_DATA <= X"31";
								when X"2" => LCD_DATA <= X"32";
								when X"3" => LCD_DATA <= X"33";
								when X"4" => LCD_DATA <= X"34";
								when X"5" => LCD_DATA <= X"35";
								when X"6" => LCD_DATA <= X"36";
								when X"7" => LCD_DATA <= X"37";
								when X"8" => LCD_DATA <= X"38";
								when X"9" => LCD_DATA <= X"39";
								when X"A" => LCD_DATA <= X"41";
								when X"B" => LCD_DATA <= X"42";
								when X"C" => LCD_DATA <= X"43";
								when X"D" => LCD_DATA <= X"44";
								when X"E" => LCD_DATA <= X"45";
								when X"F" => LCD_DATA <= X"46";
								when others => LCD_DATA <= X"00";
							end case;
						
						when others =>
								LCD_RS <= '0';
								LCD_DATA <= X"80";
							if clk_en_3HZ = '1' then
								message_cnt <= 0; -- null
							end if;
					end case;
				when PWM60 =>   
					case message_cnt is -- PWM Generation 60 Hz
						when 0 =>
							LCD_DATA <= X"80"; -- Top left
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 1 =>
							-- clear display
							LCD_RS <= '0';
							LCD_DATA <= x"01";
							message_cnt <= message_cnt + 1;	
						when 2 => 
							LCD_DATA <= X"50"; -- P
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 3 => 
							LCD_DATA <= X"57"; -- W
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 4 => 
							LCD_DATA <= X"4D"; -- M
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 5 => 
							LCD_DATA <= X"84"; -- space
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 6 => 
							LCD_DATA <= X"47"; -- G
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 7 => 
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 8 => 
							LCD_DATA <= X"6E"; -- n
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 9 => 
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 10 => 
							LCD_DATA <= X"72"; -- r
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 11 => 
							LCD_DATA <= X"61"; -- a
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 12 => 
							LCD_DATA <= X"74"; -- t
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 13 => 
							LCD_DATA <= X"69"; -- i
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 14 => 
							LCD_DATA <= X"6F"; -- o
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 15 => 
							LCD_DATA <= X"6E"; -- n
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 16 => -- Moves cursor to the second row
							LCD_DATA <= X"C0";
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 17 => 
							LCD_DATA <= X"36"; -- 6
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 18 => 
							LCD_DATA <= X"30"; -- 0
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 19 => 
							LCD_DATA <= X"C3"; -- space
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 20 => 
							LCD_DATA <= X"48"; -- H
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 21 => 
							LCD_DATA <= X"7A"; -- z
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when others =>
							LCD_RS <= '0';
							LCD_DATA <= X"80";
							if clk_en_3HZ = '1' then
								message_cnt <= 0; -- null
							end if;
					end case;
				when PWM120 =>
					case message_cnt is -- PWM Generation 120 Hz
						when 0 =>
							LCD_DATA <= X"80"; -- Top left
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 1 =>
							-- clear display
							LCD_RS <= '0';
							LCD_DATA <= x"01";
							message_cnt <= message_cnt + 1;	
						when 2 => 
							LCD_DATA <= X"50"; -- P
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 3 => 
							LCD_DATA <= X"57"; -- W
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 4 => 
							LCD_DATA <= X"4D"; -- M
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 5 => 
							LCD_DATA <= X"84"; -- space
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 6 => 
							LCD_DATA <= X"47"; -- G
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 7 => 
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 8 => 
							LCD_DATA <= X"6E"; -- n
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 9 => 
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 10 => 
							LCD_DATA <= X"72"; -- r
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 11 => 
							LCD_DATA <= X"61"; -- a
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 12 => 
							LCD_DATA <= X"74"; -- t
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 13 => 
							LCD_DATA <= X"69"; -- i
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 14 => 
							LCD_DATA <= X"6F"; -- o
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 15 => 
							LCD_DATA <= X"6E"; -- n
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 16 => -- Moves cursor to the second row
							LCD_DATA <= X"C0";
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 17 => 
							LCD_DATA <= X"31"; -- 1
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 18 => 
							LCD_DATA <= X"32"; -- 2
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 19 => 
							LCD_DATA <= X"30"; -- 0
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 20 => 
							LCD_DATA <= X"C4"; -- space
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 21 => 
							LCD_DATA <= X"48"; -- H
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 22 => 
							LCD_DATA <= X"7A"; -- z
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when others =>
							LCD_RS <= '0';
							LCD_DATA <= X"80";
							if clk_en_3HZ = '1' then
								message_cnt <= 0; -- null
							end if;
					end case;
				when PWM1000 =>
					case message_cnt is -- PWM Generation 1000 Hz
						when 0 =>
							LCD_DATA <= X"80"; -- Top left
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 1 =>
							-- clear display
							LCD_RS <= '0';
							LCD_DATA <= x"01";
							message_cnt <= message_cnt + 1;	
						when 2 => 
							LCD_DATA <= X"50"; -- P
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 3 => 
							LCD_DATA <= X"57"; -- W
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 4 => 
							LCD_DATA <= X"4D"; -- M
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 5 => 
							LCD_DATA <= X"84"; -- space
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 6 => 
							LCD_DATA <= X"47"; -- G
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 7 => 
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 8 => 
							LCD_DATA <= X"6E"; -- n
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 9 => 
							LCD_DATA <= X"65"; -- e
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 10 => 
							LCD_DATA <= X"72"; -- r
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 11 => 
							LCD_DATA <= X"61"; -- a
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 12 => 
							LCD_DATA <= X"74"; -- t
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 13 => 
							LCD_DATA <= X"69"; -- i
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 14 => 
							LCD_DATA <= X"6F"; -- o
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 15 => 
							LCD_DATA <= X"6E"; -- n
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 16 => -- Moves cursor to the second row
							LCD_DATA <= X"C0";
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 17 => 
							LCD_DATA <= X"31"; -- 1
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 18 => 
							LCD_DATA <= X"30"; -- 0
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 19 => 
							LCD_DATA <= X"30"; -- 0
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 20 => 
							LCD_DATA <= X"30"; -- 0
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 21 => 
							LCD_DATA <= X"C5"; -- space
							LCD_RS <= '0';
							message_cnt <= message_cnt + 1;
						when 22 => 
							LCD_DATA <= X"48"; -- H
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when 23 => 
							LCD_DATA <= X"7A"; -- z
							LCD_RS <= '1';
							message_cnt <= message_cnt + 1;
						when others =>
							LCD_RS <= '0';
							LCD_DATA <= X"80";
							if clk_en_3HZ = '1' then
								message_cnt <= 0; -- null
							end if;
					end case;
				when others =>         -- Error in case statement 
					message_cnt  <= 0;
					LCD_RS       <= '0';
					LCD_DATA 	 <= X"01";
			end case;
		end if;
	end process;
end behavior;