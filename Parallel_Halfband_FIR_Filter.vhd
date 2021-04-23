--| |-----------------------------------------------------------| |
--| |-----------------------------------------------------------| |
--| |       _______           __      __      __          __    | |
--| |     /|   __  \        /|  |   /|  |   /|  \        /  |   | |
--| |    / |  |  \  \      / |  |  / |  |  / |   \      /   |   | |
--| |   |  |  |\  \  \    |  |  | |  |  | |  |    \    /    |   | |
--| |   |  |  | \  \  \   |  |  | |  |  | |  |     \  /     |   | |
--| |   |  |  |  \  \  \  |  |  |_|__|  | |  |      \/      |   | |
--| |   |  |  |   \  \  \ |  |          | |  |  |\      /|  |   | |
--| |   |  |  |   /  /  / |  |   ____   | |  |  | \    / |  |   | |
--| |   |  |  |  /  /  /  |  |  |__/ |  | |  |  |\ \  /| |  |   | |
--| |   |  |  | /  /  /   |  |  | |  |  | |  |  | \ \//| |  |   | |
--| |   |  |  |/  /  /    |  |  | |  |  | |  |  |  \|/ | |  |   | |
--| |   |  |  |__/  /     |  |  | |  |  | |  |  |      | |  |   | |
--| |   |  |_______/      |  |__| |  |__| |  |__|      | |__|   | |
--| |   |_/_______/	      |_/__/  |_/__/  |_/__/       |_/__/   | |
--| |                                                           | |
--| |-----------------------------------------------------------| |
--| |=============-Developed by Dimitar H.Marinov-==============| |
--|_|-----------------------------------------------------------|_|

--IP: Parallel Halfband FIR Filter
--Version: V1 - Standalone 
--Fuctionality: Halfband FIR filter
--IO Description
--  clk     : system clock = sampling clock
--  reset   : resets the A registes (buffers) and the P registers (delay line) of the DSP48 blocks 
--  enable  : Not in use: acts as bypass switch - bypass(0), active(1) 
--  data_i  : data input (signed)
--  data_lpf_o  : data output (signed) of the low-pass filter (Granted the filter coefficients describe a low-pass filter). 
--  data_hpf_o  : data output (signed) of the high-pass filter (i.e. the complementary output).
--
--Generics Description
--  FILTER_TAPS  : Specifies the amount of filter taps (multiplications)
--  INPUT_WIDTH  : Specifies the input width (8-25 bits)
--  COEFF_WIDTH  : Specifies the coefficient width (8-18 bits)
--  OUTPUT_WIDTH : Specifies the output width (8-43 bits)
--
--Finished on: 30.03.2021
--Notes: the DSP attribute is required to make use of the DSP slices efficiently
--------------------------------------------------------------------
--================= https://github.com/DHMarinov =================--
--------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Parallel_Halfband_FIR_Filter is
    Generic (
        FILTER_TAPS  : integer := 59; --59                -- Amount of coefficients
        INPUT_WIDTH  : integer range 8 to 25 := 24; 
        COEFF_WIDTH  : integer range 8 to 18 := 16;
        OUTPUT_WIDTH : integer range 8 to 43 := 24    -- This should be < (Input+Coeff width-1) 
    );
    Port (  
           clk    : in STD_LOGIC; 
           reset  : in STD_LOGIC;
           enable : in STD_LOGIC;
           data_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           data_lpf_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0);
           data_hpf_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0)
           );
end Parallel_Halfband_FIR_Filter;

architecture Behavioral of Parallel_Halfband_FIR_Filter is

--attribute use_dsp : string;
--attribute use_dsp of Behavioral : architecture is "yes";

constant MAC_WIDTH : integer := COEFF_WIDTH+INPUT_WIDTH;

type input_registers is array(0 to (FILTER_TAPS-3)/2+2) of signed(INPUT_WIDTH-1 downto 0);
signal areg_s  : input_registers := (others=>(others=>'0'));

type coeff_registers is array(0 to (FILTER_TAPS-3)/2+2) of signed(COEFF_WIDTH-1 downto 0);
signal breg_s : coeff_registers := (others=>(others=>'0'));

type mult_registers is array(0 to FILTER_TAPS-1) of signed(INPUT_WIDTH+COEFF_WIDTH-1 downto 0);
--signal mreg_s : mult_registers := (others=>(others=>'0'));

type dsp_registers is array(0 to (FILTER_TAPS-3)/2+2) of signed(MAC_WIDTH-1 downto 0);
signal preg_s : dsp_registers := (others=>(others=>'0'));

signal del : signed(INPUT_WIDTH-1 downto 0) := (others=>'0');
signal del2 : signed(INPUT_WIDTH-1 downto 0) := (others=>'0');

--type coefficients is array (0 to 6) of signed(COEFF_WIDTH-1 downto 0);
--signal coeff_s: coefficients :=( 
---- Blackman 500Hz LPF
--x"0005", x"000C", x"0016", x"0025",
--x"0037", x"004E", 
--x"0069");

-- Halfband
type coefficients is array (0 to 30) of signed( 15 downto 0);
signal coeff_s: coefficients :=( 
--x"0FE6", x"FE67", x"01B4", x"FE2C", x"01FF", x"FDD0", 
--x"026F", x"FD41", x"0329", x"FC47", x"0489", x"FA2C", 
--x"0826", x"F265", x"28BE", x"4000", x"28BE", x"F265", 
--x"0826", x"FA2C", x"0489", x"FC47", x"0329", x"FD41", 
--x"026F", x"FDD0", x"01FF", x"FE2C", x"01B4", x"FE67", 
--x"0FE6");

--x"001D", x"FFD9", x"003B", x"FFA7", x"0085",
--x"FF3F", x"0110", x"FE89", x"01FD", x"FD50", 
--x"03AA", x"FAE0", x"07A3", x"F2BD", x"289B", 
--x"3FF2", x"289B", x"F2BD", x"07A3", x"FAE0", 
--x"03AA", x"FD50", x"01FD", x"FE89", x"0110", 
--x"FF3F",  x"0085", x"FFA7", x"003B", x"FFD9",
--x"001D"
--);

x"001C", x"FFDD", x"0033", x"FFB2", 
x"0078", x"FF4E", x"00FF", x"FE9A", 
x"01EC", x"FD5F", x"039C", x"FAEA", 
x"079C", x"F2BF", x"28A2", x"4000", 
x"28A2", x"F2BF", x"079C", x"FAEA", 
x"039C", x"FD5F", x"01EC", x"FE9A", 
x"00FF", x"FF4E", x"0078", x"FFB2", 
x"0033", x"FFDD", x"001C");


begin  

-- Coefficient formatting
Coeff_Array: for i in 0 to (FILTER_TAPS-3)/2+2 generate
    Coeff: for n in 0 to COEFF_WIDTH-1 generate
        Coeff_Sign: if n > COEFF_WIDTH-2 generate
            breg_s(i)(n) <= coeff_s(i)(COEFF_WIDTH-1);
        end generate;
        Coeff_Value: if n < COEFF_WIDTH-1 generate
            breg_s(i)(n) <= coeff_s(i)(n);
        end generate;
    end generate;
end generate;        

process(clk)

variable mreg_s : mult_registers := (others=>(others=>'0'));

begin

if rising_edge(clk) then

    --Checks whether the FILTER_TAPS generic is even
    if (FILTER_TAPS mod 2) = 0 then
        assert (false) report "The FILTER_TAPS generic is even. Only odd values are accepted!"  severity failure;
    end if;

    if (reset = '1') then
        for i in 0 to (FILTER_TAPS-3)/2+2 loop
            areg_s(i) <=(others=> '0');
--            mreg_s(i) <=(others=> '0');
            preg_s(i) <=(others=> '0');
        end loop;

    elsif (reset = '0') then   
        for i in 0 to (FILTER_TAPS-3)/2+2 loop
            if i < (FILTER_TAPS-3)/4 then
                if i = 0 then
                    areg_s(i) <= signed(data_i);
                else
                    areg_s(i) <= areg_s(i-1); 
                end if;
                mreg_s(i) := areg_s(i)*breg_s(i);         
                preg_s(i) <= mreg_s(i) + preg_s(i+1);
                
            elsif i >= (FILTER_TAPS-3)/4 and i < (FILTER_TAPS-3)/4 + 3 then
                areg_s((FILTER_TAPS-3)/4) <= areg_s((FILTER_TAPS-3)/4-1);
                mreg_s(i) := areg_s((FILTER_TAPS-3)/4)*breg_s(i);         
                preg_s(i) <= mreg_s(i) + preg_s(i+1);
            
            else
                if i = (FILTER_TAPS-3)/4 + 3 then
                    areg_s(i) <= areg_s(i-3);
                    mreg_s(i) := areg_s(i)*breg_s(i);         
                    preg_s(i) <= mreg_s(i) + preg_s(i+1);
                elsif i = (FILTER_TAPS-3)/2+2 then          -- Final stage i.e. center coefficient
                    areg_s(i) <= areg_s(i-1);
                    mreg_s(i) := areg_s(i)*breg_s(i);         
                    preg_s(i) <= mreg_s(i);  
                else 
                    areg_s(i) <= areg_s(i-1);
                    mreg_s(i) := areg_s(i)*breg_s(i);         
                    preg_s(i) <= mreg_s(i) + preg_s(i+1);
                end if;
            end if;
        end loop;
        
        data_lpf_o <= std_logic_vector(preg_s(0)(MAC_WIDTH-2 downto MAC_WIDTH-OUTPUT_WIDTH-1)); 
        del <= areg_s((FILTER_TAPS+1)/2);
        del2 <= del;
        data_hpf_o <= std_logic_vector(preg_s(0)(MAC_WIDTH-2 downto MAC_WIDTH-OUTPUT_WIDTH-1)- del2); 
        
    end if; 
end if;
end process;

end Behavioral;