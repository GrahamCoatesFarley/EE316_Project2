LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
ENTITY sram_controller IS
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
END sram_controller;

ARCHITECTURE arch OF sram_controller IS
    TYPE state_type IS (init, idle, r1, r2, w1, w2);
    SIGNAL state_reg : state_type := idle;
    SIGNAL data_w_reg : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL data_r_reg : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL addr_reg : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL we_reg, oe_reg, tri_reg : STD_LOGIC;
BEGIN
    PROCESS (clk, reset, state_reg, en, rw, sram_dio, addr, data_w, data_w_reg, data_r_reg, addr_reg)
    BEGIN
		if(rising_edge(clk)) then
			  if(reset = '1') then
					state_reg <= init;
			  end if;
			  ready <= '0';

			  tri_reg <= '1';
			  we_reg <= '1';
			  oe_reg <= '1';
			  CASE state_reg IS
					WHEN init =>
						addr_reg <= (OTHERS => '0');
                        data_w_reg <= (OTHERS => '0');
                        data_r_reg <= (OTHERS => '0');
                        tri_reg <= '1';
                        we_reg <= '1';
                        oe_reg <= '1';
                        if(reset = '0') then
                            state_reg <= idle;
                        end if;
					WHEN idle =>
						 IF (en = '0') THEN
							  state_reg <= idle;
						 ELSE
							  addr_reg <= "00000000000" & addr;
							  IF (rw = '0') THEN -- write
									state_reg <= w1;
                                    data_w_reg <= data_w;
							  ELSE
									state_reg <= r1;
							  END IF;
						 END IF;
						 ready <= '1';
					WHEN w1 =>
						 state_reg <= w2;
						 tri_reg <= '0';
						 we_reg <= '0';
					WHEN w2 =>
						 state_reg <= idle;
						 tri_reg <= '0';
					WHEN r1 =>
						 state_reg <= r2;
						 oe_reg <= '0';
					WHEN r2 =>
						 data_r_reg <= sram_dio;
						 state_reg <= idle;
						 oe_reg <= '0';
			  END CASE;
		  end if;
    END PROCESS;
    -- to main system
    data_r <= data_r_reg;
    -- to SRAM
    sram_we_n <= we_reg;
    sram_oe_n <= oe_reg;
    sram_addr <= addr_reg;
    -- I/O for SRAM chip
    sram_ce_n <= '0';
    sram_dio <= data_w_reg WHEN tri_reg = '0'
        ELSE
        (OTHERS => 'Z');
END arch;