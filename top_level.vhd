library ieee;
use ieee.std_logic_1164.all;

entity top_level is
    port(
        clk50: in std_logic;
        key0: in std_logic;
        key1: in std_logic;
        key2: in std_logic;
        key3: in std_logic;

        sda: inout std_logic;
        scl: inout std_logic;
		  
		  outPWM : out std_LOGIC;
		  
            led0: out std_logic;
            led1: out std_logic;
            led2: out std_logic;
            led3: out std_logic;
	    
	    
	    LCD_ON      	 : OUT STD_LOGIC;				-- LCD Power ON/OFF
        LCD_BLON    	 : OUT STD_LOGIC;				-- LCD Back Light ON/OFF
        LCD_RW      	 : OUT STD_LOGIC;				-- LCD Read/Write Select, 0 = Write, 1 = Read
     	LCD_EN      	 : OUT STD_LOGIC;				-- LCD Enable
        LCD_RS       	 : OUT STD_LOGIC;				-- LCD Command/Data Select, 0 = Command, 1 = Data
      	LCD_DATA    	 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);		-- LCD Data bus 8 bits,

          sram_addr : OUT STD_LOGIC_VECTOR(18 DOWNTO 0); -- address to sram
          sram_we_n, sram_oe_n : OUT STD_LOGIC; -- write enable, output enable
          sram_dio : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- data I/O to sram
          sram_ce_n : OUT STD_LOGIC -- chip enable
    );
end top_level;

architecture rtl of top_level is
    component state_machine is
        port (
            clk: in std_logic;
            reset: in std_logic;
            key0: in std_logic; -- debounced input, reset
            key1: in std_logic; -- pulse, test <--> pause
            key2: in std_logic; -- pulse, pwm -> test <--> pwm60
            key3: in std_logic; -- pulse, pwm60 -> pwm120 -> pwm1k -> pwm60
            addr: in std_logic_vector(7 downto 0);
    
            RW : out std_logic;
            enable: out std_logic;
            
            read_rom: out std_logic;
            counter_clear: out std_logic;

            state_out: out std_logic_vector(2 downto 0)

        );
    end component;

    component btn_debounce_toggle is
        GENERIC (CONSTANT CNTR_MAX : std_logic_vector(15 downto 0) := X"ffff");  
        Port (
            BTN_I 	: in  STD_LOGIC;
            CLK 		: in  STD_LOGIC;
            BTN_O 	: out  STD_LOGIC;
            TOGGLE_O : out  STD_LOGIC;
		    PULSE_O  : out STD_LOGIC);
    end component;
	
    component LCD_Manager  is
		port (
            clk		: in  std_logic;
            reset		: in  std_logic;
            System_State    : in  std_logic_vector(2 downto 0);
            ADDRESS		: in  std_LOGIC_VECTOR(7 downto 0);
            Data		: in  std_LOGIC_VECTOR(15 downto 0);
            
            LCD_ON      	 : OUT STD_LOGIC;								-- LCD Power ON/OFF
            LCD_BLON    	 : OUT STD_LOGIC;								-- LCD Back Light ON/OFF
            LCD_RW      	 : OUT STD_LOGIC;								-- LCD Read/Write Select, 0 = Write, 1 = Read
            LCD_EN      	 : OUT STD_LOGIC;								-- LCD Enable
            LCD_RS       	 : OUT STD_LOGIC;								-- LCD Command/Data Select, 0 = Command, 1 = Data
            LCD_DATA    	 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)		            -- LCD Data bus 8 bits
		);
		end component;
	

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

    component clk_en is 
        generic (
            max: integer := 2 -- 60ns default
        );
    
        port (
            clk50: in std_logic;
            clkOut: out std_logic
        );
    end component;

    component univ_bin_counter is
        generic(N: integer := 8; N2: integer := 9; N1: integer := 0);
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
		state_bits			: in std_logic_vector(2 downto 0);
		clk 					: in std_logic;
		en 					: in std_logic;
		reset 				: in std_logic;
		--M_incrementor 		: in std_logic_vector(N-1 downto 0); --M value, 3 possibilities, from the excel sheet forumula
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
    PORT (
        -- Control signals
        clk, reset : IN STD_LOGIC;
        en : IN STD_LOGIC;
        rw : IN STD_LOGIC;
        addr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        data_w : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- data to write to sram

        -- Output signals
        ready : OUT STD_LOGIC; -- ready to accept new data
        data_r : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- data read from sram

        -- SRAM interface
        sram_addr : OUT STD_LOGIC_VECTOR(18 DOWNTO 0); -- address to sram
        sram_we_n, sram_oe_n : OUT STD_LOGIC; -- write enable, output enable
        sram_dio : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- data I/O to sram
        sram_ce_n : OUT STD_LOGIC -- chip enable
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

component rom IS
		PORT
	(
		address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	END component;
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	signal rawAddress       : std_logic_vector(32-1 downto 0);
	signal sramAddr         : std_logic_vector(7 downto 0);  --right before SRAM block
	signal rawData          : std_logic_vector(15 downto 0); --right after SRAM block

	signal tuncatedData     : std_logic_vector(7 downto 0); --this might change, should be generic
	--this the resolution design choice

	 signal en : std_LOGIC;
	 
	 
	 signal rom_sig                     : std_logic_vector(15 downto 0) := x"0000"; --this is data for SRAM
	 
	 
	 
	 signal RW_sig 							  : std_logic;
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 
	 

    signal key_reg: std_logic_vector(3 downto 0) := "0000";
    

    -- input signals
    signal key0_db:     std_logic := '0';
    signal key1_pulse:  std_logic := '0';
    signal key2_pulse:  std_logic := '0'; 
    signal key3_pulse:  std_logic := '0';

    signal clk_i2c:     std_logic := '0';

    signal clk_1s: std_logic := '0';

    signal state_bits:       std_logic_vector(2 downto 0) := "000";

    signal not_reset:   std_logic;

    signal data:       std_logic_vector(15 downto 0) := x"0000";
    signal address:    std_logic_vector(7 downto 0) := x"ab";
    signal count_enable: std_logic := '0';
    signal read_rom: std_logic := '0';
    signal counter_clear: std_logic := '0';
    
    signal counter_clk: std_logic := '0';
    
	     signal truncAddr : std_logic_vector(7 downto 0);
		          signal clk_60ns: std_logic;

    signal addr_to_lcd: std_logic_vector(7 downto 0) := x"00";
    signal data_to_lcd: std_logic_vector(15 downto 0) := x"0000";

    signal reset_pulse: std_logic := '0';

    signal clock25: std_logic := '0';

begin
    debounce_key0: btn_debounce_toggle
        generic map (CNTR_MAX => X"ffff")
        port map (
            BTN_I => key_reg(0),
            CLK => clk50,
            BTN_O => key0_db,
            TOGGLE_O => open,
            PULSE_O => reset_pulse
        );

        not_reset <= not key0_db;

    debounce_key1: btn_debounce_toggle 
        generic map (CNTR_MAX => X"ffff")
        port map (
            BTN_I => key_reg(1),
            CLK => clk50,
            BTN_O => open,
            TOGGLE_O => open,
            PULSE_O => key1_pulse
        );

    debounce_key2: btn_debounce_toggle 
        generic map (CNTR_MAX => X"ffff")
        port map (
            BTN_I => key_reg(2),
            CLK => clk50,
            BTN_O => open,
            TOGGLE_O => open,
            PULSE_O => key2_pulse
        );

    debounce_key3: btn_debounce_toggle 
        generic map (CNTR_MAX => X"ffff")
        port map (
            BTN_I => key_reg(3),
            CLK => clk50,
            BTN_O => open,
            TOGGLE_O => open,
            PULSE_O => key3_pulse
        );
	    
        addr_to_lcd <= sramAddr when (state_bits = "011" or state_bits = "100") else x"00";
        data_to_lcd <= data when (state_bits = "011" or state_bits = "100") else x"0000";
	    
	    LCD_Display: LCD_Manager  
		port map(
            clk		=> clk50,
            reset		=> reset_pulse, 
            System_State    => state_bits,
            ADDRESS		=> addr_to_lcd,
            Data		=> data_to_lcd,
		
		    LCD_ON      	=> LCD_ON,	
      		LCD_BLON    	=> LCD_BLON,
      		LCD_RW      	=> LCD_RW,
		    LCD_EN		    => LCD_EN,
      		LCD_RS       	=> LCD_RS,	
      		LCD_DATA    	=> LCD_DATA
		);
	    
	    
    statemachine_inst: state_machine
        port map (
            clk => clk50,
            reset => reset_pulse,
            key0 => key0_db,
            key1 => key1_pulse,
            key2 => key2_pulse,
            key3 => key3_pulse,
            state_out => state_bits,
            addr => address,
            rw => RW_sig,
            enable => count_enable,
            read_rom => read_rom,
            counter_clear => counter_clear
        );
	    
    display: i2c_display
        port map (
            clk => clk50,
            reset => reset_pulse,
            data => data,
            sda => sda,
            scl => scl,
            status => open
        );

    clk_1s_enabler: clk_en
        generic map (max => 50_000_000)
        port map (
            clk50 => clk50,
            clkOut => clk_1s
        );

		  
		  
	clk25_inst: clk_en
        generic map (max => 1)
        port map (
            clk50 => clk50,
            clkOut => clock25
        );
		  

		  
    inst_fixed_point_counter:fixed_point_counter
	generic map(N => 32)
	port map(
	state_bits => state_bits,
	clk => clk50,
	en => '1',
	reset => key0_db,
	--M_incrementor => M_incrementor,
	rawAddress => rawAddress
	);

	inst_addr_truncate:truncate
	generic map(N => 32, W => 8)
	port map(
	raw => rawAddress,
	truncated => truncAddr
	);

    sramAddr <= address when (read_rom = '1' or state_bits = "011" or state_bits = "100") else truncAddr;
	
	Inst_SRAM_controller: SRAM_Controller 
    port map (
        clk => clk50,
        reset => reset_pulse,
        en => '1',
        rw => RW_sig,
        addr => sramAddr,
        data_w => rom_sig,
        ready => open,
        data_r => data,
        sram_addr => sram_addr,
        sram_we_n => sram_we_n,
        sram_oe_n => sram_oe_n,
        sram_dio => sram_dio,
        sram_ce_n => sram_ce_n 
    );


	inst_data_truncate:truncate
	generic map(N => 16, W => 8)
	port map(
	raw => data,
	truncated => tuncatedData 
	);
	
	inst_pwm_gen:pwm_gen
	generic map(N => 8, PWM_COUNTER_MAX => 512)  --why are we going with 8 bits pwm length, if you make the period longer, you use less data points from SRAM
																--this determines how many data samples are actually used from the SRAM
	port map(
	clk => clock25,
	idata => tuncatedData,
	oPWM => outPWM
	);
	
	Inst_Rom: rom
		port map(
			address	=>	sramAddr,
			clock		=> clk50,
			q			=>	rom_sig
		);

        clk_60ns_inst: clk_en
        generic map (max => 3)
        port map (
            clk50 => clk50,
            clkOut => clk_60ns
        );
		
        counter_clk <=  clk_60ns when read_rom = '1' else clk_1s;

		address_counter: univ_bin_counter 
        generic map (N => 8, N2 => 255, N1 => 0)
        port map (
            clk => counter_clk,
            reset => counter_clear,
            syn_clr => '0',
            load => '0',
            en => count_enable,
            up => '1',
            clk_en => '1',
            d => x"00",
            max_tick => open,
            min_tick => open,
            q => address
        );

        key_reg <= not key3 & not key2 & not key1 & not key0;
end rtl;
