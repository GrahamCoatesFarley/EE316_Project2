library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_display is
    port (
        clk: in std_logic;
        reset: in std_logic;

        data: in std_logic_vector(15 downto 0);

        sda: inout std_logic;
        scl: inout std_logic;

        status: out std_logic
    );
end i2c_display;

architecture rtl of i2c_display is
    component i2c_master is
        generic(
            input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
            bus_clk   : INTEGER := 100_000);   --speed the i2c bus (scl) will run at in Hz
        port(
            clk       : IN     STD_LOGIC;                    --system clock
            reset_n   : IN     STD_LOGIC;                    --active low reset
            ena       : IN     STD_LOGIC;                    --latch in command
            addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
            rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
            data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
            busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
            data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
            ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
            sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
            scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
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

        signal reset_n : std_logic;

        signal i2c_busy: std_logic := '0';
        attribute keep : string;
        attribute keep of i2c_busy    : signal is "true";


        signal i2c_data: std_logic_vector(7 downto 0) := "00000000";

        signal byteSel: integer range 0 to 12:= 0;

        type state_type is (start, ready, data_valid, busy_high, repeat);
        signal i2c_state: state_type := start;

        signal enable : std_logic := '0';
        signal clk_logic: std_logic;
begin

    reset_n <= not reset;

    i2c_driver: i2c_master
        generic map(
            input_clk => 50_000_000,
            bus_clk => 50_000
        )
        port map(
            clk => clk,
            reset_n => reset_n,
            ena => enable,
            addr => "1110001", -- 0x71 but drop the msb
            rw => '0',
            data_wr => i2c_data,
            busy => i2c_busy,
            data_rd => open,
            ack_error => open,
            sda => sda,
            scl => scl
        );

    process(byteSel, data)
    begin
    case byteSel is
        when 0  => i2c_data <= X"76";
        when 1  => i2c_data <= X"76";
        when 2  => i2c_data <= X"76";   
        when 3  => i2c_data <= X"7A";
        when 4  => i2c_data <= X"FF";
        when 5  => i2c_data <= X"77";
        when 6  => i2c_data <= X"00";
        when 7  => i2c_data <= X"79";
        when 8  => i2c_data <= X"00";   
        when 9  => i2c_data <= x"0"&data(15 downto 12);
        when 10 => i2c_data <= x"0"&data(11 downto 8);
        when 11 => i2c_data <= x"0"&data(7  downto 4);
        when 12 => i2c_data <= x"0"&data(3  downto 0);
        when others => i2c_data <= X"76";
    end case;
    end process;

    status <= i2c_busy;

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            byteSel <= 0;
            enable <= '0';
        elsif rising_edge(clk) then
            case i2c_state is
                when start =>
                    enable <= '1';
                    i2c_state <= ready;
                when ready =>    
                    if i2c_busy = '0' then
                        enable  <= '1';
                        i2c_state   <= data_valid;
                    end if;
                when data_valid => 
                    if (i2c_busy = '1') then
                        enable  <= '0';
                        i2c_state   <= busy_high;
                    end if;
                when busy_high =>
                    if(i2c_busy = '0') then
                        i2c_state <= repeat;
                    end if;      
                when repeat =>
                    if byteSel < 12 then
                        byteSel <= byteSel + 1;
                    else   
                        byteSel <= 7;
                    end if;        
                    
                    i2c_state <= start;
                when others => null;
            end case;
        end if;
    end process;
end rtl;