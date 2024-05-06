library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity SpaceShooter is
    port (
        clk_fast, clk_slow, move_left, move_right, shoot, control : in std_logic;
        rows : out bit_vector(1 to 7);
        cols_green, cols_red : out bit_vector(1 to 5) := (others => '1');
        dizaine, unite: out std_logic_vector(3 downto 0) := (others => '0');
		  led_end: out std_logic

    );
end SpaceShooter;

architecture space_arch of SpaceShooter is
	
	-- Constantes
	constant GRID_WIDTH : integer := 5;
	constant GRID_HEIGHT : integer := 7;
	constant OBSTACLE_SPEED_MAX : integer := 15;
	
	-- Etats du jeu
	type GameState is (MENU, PLAY, GAME_OVER, PAUSE);
	signal state : GameState := MENU;
	
   -- Positions du joueur
	signal player_col : integer range 1 to GRID_WIDTH := 3;
	constant player_row  : integer := GRID_HEIGHT;

	-- Logique du jeu
	signal not_action : boolean := true; -- Ce booléen vaut false si un bouton a été pressé (moves & shoot)
	signal lives : integer range 0 to 3 := 3; -- Nombre de vies du joueur : 3 initialement

	-- Tirs du joueur
	signal bullet_row : integer range 0 to 6 := 6; -- Ligne courante de la balle tirée par le joueur
	signal bullet : boolean := false; -- Indication si notre joueur a tiré ou non
	signal collision : boolean := false; -- Indication si un obstacle a été touché ou non
	
	-- Obstacles
	signal obstacle_row : integer range 1 to GRID_HEIGHT := 1; -- Position initiale de l'obstacle
	signal obstacle_col : integer range 1 to GRID_WIDTH; -- Position horizontale de l'obstacle
	shared variable obstacle_speed : integer range 1 to OBSTACLE_SPEED_MAX := OBSTACLE_SPEED_MAX; -- Vitesse de déplacement de l'obstacle
	signal delete_obstacle : boolean := false; -- False si un obstacle a été touché. False sinon
	signal rand_col : integer range 1 to GRID_WIDTH := 1; -- Colonne aléatoire pour l'obstable
	
	-- Faciliter l'affichage de la matrice selon la fréquence courante
	signal led_counter : integer range 0 to 20; -- Index de la ligne courante pour l'affichage du menu
	signal switch : natural range 1 to 3 := 1; -- Switch pour avoir une alternance entre les obstacles et le joueur

	-- 7 segments (0 to 99)
	subtype digit_type is integer range 0 to 9; -- Type pour les 7 segments
	signal score_dizaine, score_unite : digit_type;
	signal previous_dizaine : digit_type;
	
	signal difficulty : integer range 1 to 3 := 1;
	
	signal end_led_state : std_logic := '0';
	
	
	begin
   	logic : process(clk_slow, clk_fast, move_left, move_right, shoot, control)
		
   	begin
      	if rising_edge(clk_slow) then
				case state is
					when MENU =>
						led_end <= '0';
						score_dizaine <= 0;
						score_unite <= 0;
						
						
						if(move_right = '0' and move_left = '0') then
							not_action <= true;
						
						elsif(not_action) then
							not_action <= false;
							if move_left = '1' then
								if(difficulty > 1) then
									difficulty <= difficulty - 1;
								end if;
							elsif move_right = '1' then
								if(difficulty < 3) then
									difficulty <= difficulty + 1;
								end if;
							end if;
						end if;
						
						if(shoot = '1') then
							state <= PLAY;
						end if;
						
						dizaine <= "0000";
						unite <= std_logic_vector(to_unsigned(difficulty, 4));
						
						case difficulty is
							when 1 => 
								obstacle_speed := OBSTACLE_SPEED_MAX;
								lives <= 3;
							when 2 => 
								obstacle_speed := 10;
								lives <= 3;
							when 3 =>
								obstacle_speed := 10;
								lives <= 1;
						end case;
						
					when PLAY =>
						led_end <= '0';
						
						if(move_right = '0' and move_left = '0' and shoot = '0') then
							not_action <= true;
							
						elsif(not_action) then
							not_action <= false;
							if move_left = '1'  then 
								if player_col > 1 then
									player_col <= player_col - 1;
								end if;
							elsif move_right = '1' then
								-- Déplacer la LED vers la droite
								if player_col < GRID_WIDTH then
										player_col <= player_col + 1;
								end if;
							elsif shoot = '1' then
								-- Le joueur a tiré
								bullet <= true;
							end if;
						end if;
					
						if(bullet) then
							if(bullet_row > 1) then
								bullet_row <= bullet_row - 1;
							else
								bullet_row <= 6;
								bullet <= false;
							end if;
						end if;
					
						if obstacle_row < 7 then
							led_counter <= led_counter + 1;
							
							-- Facteur de ralentissement pour l'obstacle
							if led_counter = obstacle_speed then
								led_counter <= 0;
								if(not delete_obstacle) then
									obstacle_row <= obstacle_row + 1;
								else
									delete_obstacle <= false;
								end if;
							end if;
						-- Si l'obstacle n'a pas touché le joueur, on réinitialise sa position
						else
							obstacle_row <= 1;
							obstacle_col <= rand_col;
							delete_obstacle <= false;
						end if;
						
						-- Si l'obstacle touche le joueur, on diminue ses vies de 1
						 if(obstacle_row = GRID_HEIGHT and obstacle_col = player_col) or obstacle_row = GRID_HEIGHT then
							  lives <= lives - 1;
							  delete_obstacle <= true;
						 end if;
						
						collision <= (bullet_row = obstacle_row and player_col = obstacle_col) and bullet; -- Si le tir a touché un obstacle, il vaut true. False sinon
						
						if(collision) then
							-- On incrémente le score manuellement pour économiser les logic gates (optimisation)
							if(score_dizaine <= 9 and score_unite <= 9) then
								if score_unite = 9 then
									score_dizaine <= score_dizaine + 1;
									score_unite <= 0;
								else
									score_unite <= score_unite + 1;
								end if;
							end if;
							
							if score_dizaine /= previous_dizaine then 
								obstacle_speed := obstacle_speed - 1;
								previous_dizaine <= score_dizaine;
							end if;
							
							delete_obstacle <= true; -- On supprime l'obstacle s'il a été touché par un tir
							obstacle_row <= 1; -- On place l'obstacle à la premiere ligne (à corriger)
							obstacle_col <= rand_col; -- On place l'obstacle dans une colonne random
							collision <= false; -- Le nouvel obstacle n'a pas encore été touché
							bullet <= false;
							bullet_row <= 6;
						
						end if;
						
						-- Mise à jour des 7 segments en fonction du score
						dizaine <= std_logic_vector(to_unsigned(score_dizaine, 4));
						unite <= std_logic_vector(to_unsigned(score_unite, 4));
						
						if(lives = 0) then
							state <= GAME_OVER;
						end if;

						if(control = '1') then
							state <= PAUSE;
						end if;
						
						
					when GAME_OVER =>
						led_counter <= led_counter + 1;
						if(led_counter = 20) then
							led_counter <= 0;
							end_led_state <= not end_led_state;
							led_end <= end_led_state;
						end if;
						
						-- RESET
						if(control = '1') then
							state <= MENU;
						elsif(shoot = '1') then
							score_dizaine <= 0;
							score_unite <= 0;
							player_col <= 3;
							case difficulty is
								when 1 => 
									obstacle_speed := OBSTACLE_SPEED_MAX;
									lives <= 3;
								when 2 => 
									obstacle_speed := 10;
									lives <= 3;
								when 3 =>
									obstacle_speed := 10;
									lives <= 1;
							end case;
							state <= PLAY;
						end if;
						
					when PAUSE =>
						if(shoot = '1') then
							state <= PLAY;
						end if;

				end case;
			end if;
		end process logic;
   
	-- Random process pour la colonne des obstacles
	random : process(clk_fast)
	begin 
		if rising_edge(clk_fast) then
			if rand_col = GRID_WIDTH then
				rand_col <= 1;
			else
				rand_col <= rand_col + 1;
			end if;
		end if;
	end process random;
	
	 
	display : process(clk_fast, control)   

	begin
	  if rising_edge(clk_fast) then
			case state is
				when PLAY | PAUSE =>
					 rows <= (others => '0');
					 cols_green <= (others => '1');
					 cols_red <= (others => '1');
					 
					 -- Premier rising edge, on affiche le joueur selon son état
					 if switch = 1 then
						  
						  case lives is 
								when 3 => 
									 cols_green(player_col) <= '0';
								when 2 => 
									 cols_green(player_col) <= '0';
									 cols_red(player_col) <= '0';
								when 1 => 
									 cols_red(player_col) <= '0';
								when others =>
						  end case;
						  
						  rows(player_row) <= '1';
					 
					-- Deuxième rising edge, on affiche l'obstacle
					elsif switch = 2 then
						if not delete_obstacle then
							cols_red <= (others => '1');
							rows <= (others => '0');
							rows(obstacle_row) <= '1';
							cols_red(obstacle_col) <= '0';
						end if;
				 
					-- Troisième rising edge, on affiche le tir du joueur s'il a été envoyé
					elsif switch > 2  and bullet then
					  rows(bullet_row) <= '1';
					  cols_red(player_col) <= '0';
					end if;
				 
					switch <= switch + 1;
				when others =>
			end case;
	  end if;
	end process display;

end architecture space_arch;








		
		