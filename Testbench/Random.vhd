--------------------------------------------------------------------------------------------
-- Entity Progetto Reti Logiche
--------------------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity project_reti_logiche is
    port (
    i_clk : in std_logic;
    i_start : in std_logic;
    i_rst : in std_logic;
    i_data : in std_logic_vector(7 downto 0);
    o_address : out std_logic_vector(15 downto 0);
    o_done : out std_logic;
    o_en : out std_logic;
    o_we : out std_logic;
    o_data : out std_logic_vector(7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

--------------------------------------------------------------------------------------------
-- Rappresentazione di tutti i possibili stati raggiungibili dalla macchina.
--------------------------------------------------------------------------------------------

type state_type is(
    START, -- Stato iniziale della macchina.
    ADDR_LOADER, -- Carica l'indirizzo da analizzare.
    WZ_BASE_LOADER, -- Carica l'indirizzo base della ennesima Working Zone.
    WAIT_MEM, -- Stato di attesa di caricamento/scaricamento dati dalla/alla memoria.
    DIFFERENCE_CALC, -- Calcola la differenza tra ADDR e WZ__BASE, valutando se l'indirizzo appartenga (o meno) alla Working Zone.
    ONE_SHOT_CALC, -- Calcola gli ultimi 4 bit dell'indirizzo finale in formato oneshot.
    ADDR_WZ, -- Produce l'indirizzo nel caso in cui ADDR appartenga ad una Working Zone.
    ADDR_NWZ, -- Produce l'indirizzo nel caso in cui ADDR non appartenga ad alcuna Working Zone.
    ADDR_WRITER, -- Scrive in memoria l'indirizzo prodotto.
    DONE, -- Aggiorna il segnale o_done a 1.
    DONE_WAIT -- Attende il segnale i_start a 0, quindi resetta il segnale o_done a 0 e riporta la macchina a stati nel suo stato iniziale.
    );
    
    signal STATE, CURRENT_STATE : state_type; -- Utilizzati per tenere traccia dei cambiamenti di stato
    
    begin
    process(i_clk, i_rst)
    
--------------------------------------------------------------------------------------------
-- Variabili utilizzate per mantenere dei dati significativi.
--------------------------------------------------------------------------------------------
   
    variable ADDR: integer range 0 to 127; -- Intero atto a contenere l'indirizzo da analizzare
    variable WZ_BASE: integer range 0 to 127; -- Intero atto a contenere gli indirizzi base delle Working Zone.
    variable ONE_SHOT: std_logic_vector(3 downto 0); -- Vettore atto a contenere la codifica oneshot dell'indirizzo.
    variable counter : integer range 0 to 8; -- Contatore (per tenere traccia del numero di cicli eseguiti).
    variable difference: integer; -- Variabile per contenere il valore della differenza tra ADDR e WZ_BASE.

    begin 

--------------------------------------------------------------------------------------------
-- Architecture Progetto Reti Logiche
--------------------------------------------------------------------------------------------

    if (i_rst = '1') then
        -- report "Reset!";
        o_en <= '0'; -- Riporta il segnale di reading da memoria allo stato zero.
        o_we <= '0'; -- Riporta il segnale di writing su memoria allo stato zero.
        o_done <= '0'; -- Riporta il segnale di completamento del processo allo stato zero.
        ADDR := 0; -- Resetta l'indirizzo da analizzare letto.
        WZ_BASE := 0; -- Resetta l'indirizzo base della Working Zone letto.
        ONE_SHOT := "0000"; -- Resetta l'indirizzo base della codifica oneshot.
        counter := 0; -- Resetta il contatore di cicli.
        difference := 0; -- Resetta il valore della differenza.
        CURRENT_STATE <= START; -- Riporta la macchina allo stato iniziale.
        STATE <= START; -- Riporta la macchina allo stato iniziale.
        
    elsif (rising_edge(i_clk)) then 
        case state is -- Selezione degli stati della macchina
            
            -- Stato iniziale della macchina. Una volta che il segnale di start è stato portato ad uno 
            -- (solo dopo che lo stato di reset sia stato portato a 0) inizializza le variabili e gli stati.     
            when START =>
                if (i_start = '1' AND i_rst = '0') then                                                      
                    o_address <= "0000000000001000";  
                    o_en <= '1';
                    o_we <= '0';
                    STATE <= WAIT_MEM;
                    CURRENT_STATE <= START;
                end if;
            
            -- Stato necessario al fine di generare un delay per la lettura/scrittura dalla/sulla memoria.    
            when WAIT_MEM =>       
                if (CURRENT_STATE = START) then
                    STATE <= ADDR_LOADER;
                elsif (CURRENT_STATE = ADDR_LOADER) then 
                    -- report "ADDR: " & integer'image(ADDR);
                    STATE <= WZ_BASE_LOADER;
                elsif (CURRENT_STATE = ADDR_WZ) then
                    STATE <= ADDR_WRITER;
                elsif (CURRENT_STATE = ADDR_NWZ) then
                    STATE <= ADDR_WRITER;
                elsif (CURRENT_STATE = ADDR_WRITER) then
                    STATE <= DONE;
                else
                    STATE <= DONE_WAIT;
                end if;
            
            -- Stato di caricamento dell'indirizzo da codificare.
            when ADDR_LOADER =>
                ADDR := TO_INTEGER(unsigned(i_data));
                o_address <= "0000000000000000";   
                CURRENT_STATE <= ADDR_LOADER;
                STATE <= WAIT_MEM;

            -- Stato di caricamento dell'indirizzo base della Working Zone selezionata (a seconda del contatore).
            when WZ_BASE_LOADER =>
                WZ_BASE := TO_INTEGER(unsigned(i_data));
                if (counter = 0) then
                    o_address <= "0000000000000001";
                elsif (counter = 1) then
                    o_address <= "0000000000000010";
                elsif (counter = 2) then
                    o_address <= "0000000000000011";
                elsif (counter = 3) then
                    o_address <= "0000000000000100";
                elsif (counter = 4) then
                    o_address <= "0000000000000101";
                elsif (counter = 5) then
                    o_address <= "0000000000000110";
                elsif (counter = 6) then
                    o_address <= "0000000000000111";
                end if;    
                STATE <= DIFFERENCE_CALC;
             
             -- Stato di calcolo. Permette di valutare la differenza tra i valori di ADDR e WZ_BASE e di selezionare il corretto stato successivo.
             when DIFFERENCE_CALC =>
                -- report "WZ_BASE in analisi: " & integer'image(WZ_BASE);
                if ((ADDR - WZ_BASE = 0 OR ADDR - WZ_BASE = 1 OR ADDR - WZ_BASE = 2 OR ADDR - WZ_BASE = 3) AND counter <= 7) then
                    difference := ADDR - WZ_BASE;
                    STATE <= ONE_SHOT_CALC;
                elsif (counter = 7) then
                    STATE <= ADDR_NWZ;
                else
                    counter := counter + 1;
                    STATE <= WZ_BASE_LOADER;
                end if;
             
             -- Stato di calcolo. Permette di valutare la corretta codifica one shot per gli ultimi quattro bit dell'indirizzo codificato.
             when ONE_SHOT_CALC =>
                -- report "ADDR appartiene alla seguente Working Zone: " & integer'image(counter);
                if (difference = 0) then
                    ONE_SHOT := "0001";
                elsif (difference = 1) then
                    ONE_SHOT := "0010";
                elsif (difference = 2) then
                    ONE_SHOT := "0100";
                elsif (difference = 3) then
                    ONE_SHOT := "1000";
                end if;
                STATE <= ADDR_WZ;
             
             -- Permette la composizione per concatenazione dell'indirizzo codificato correttamente.
             when ADDR_WZ =>
                o_data <= '1' & std_logic_vector(TO_UNSIGNED(counter, 3)) & ONE_SHOT;
                o_address <= std_logic_vector(TO_UNSIGNED(9, 16));
                STATE <= WAIT_MEM;
                CURRENT_STATE <= ADDR_WZ;
             
             -- Permette la composizione dell'indirizzo che non appartiene ad alcuna Working Zone.
             when ADDR_NWZ =>
                -- report "ADDR non appartiene ad alcuna Working Zone.";
                o_data <= '0' & std_logic_vector(TO_UNSIGNED(ADDR, 7));
                o_address <= std_logic_vector(TO_UNSIGNED(9, 16));
                STATE <= WAIT_MEM;
                CURRENT_STATE <= ADDR_NWZ;
             
             -- Stato di scrittura in memoria (all'indirizzo richiesto) dell'indirizzo codificato correttamente.
             when ADDR_WRITER =>
                o_we <= '1';
                CURRENT_STATE <= ADDR_WRITER;
                STATE <= WAIT_MEM;             
             
             -- Stato semi-finale. Resetta i valori di o_en e o_we, settando a 1 il valore di o_done.
              when DONE =>
                -- report "Processo completato.";
                o_en <= '0';
                o_we <= '0';
                o_done <= '1';
                STATE <= DONE_WAIT; 
              
              -- Stato finale. Resetta la macchina al primo stato di START.  
              when DONE_WAIT =>
                if(i_start = '0') then
                    o_done <= '0';
                    CURRENT_STATE <= START;
                    STATE <= START;
                end if;

        end case;
      end if;                
  end process;
end Behavioral;