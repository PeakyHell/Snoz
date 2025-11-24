%%% Input Configuration Module
%%% Defines the game configuration including grid dimensions, bot spawning locations, and map generation.

functor
import
    OS
export
    'genMap': MapGenerator
    'bots': Bots
    'dim': Dim
define
    % Grid dimension (Dim x Dim grid)
    Dim = 30
    % Percentage of randomly placed inside walls
    InsideWalls = 5

    % List of bots to spawn in the game.
    % Each bot is defined as: bot(Type TemplateAgent X Y)
    Bots = [
        bot('snake' 'SnakeBotExample' 1 1)
        bot('snake' 'SnakeBotExample' Dim-2 1)
        bot('snake' 'SnakeBotExample' 1 Dim-2)
        bot('snake' 'SnakeBotExample' Dim-2 Dim-2)
        bot('snake' 'AgentBlank' (Dim div 2) (Dim div 2))
    ]

    % MapGenerator: Generates the game map as a list of integers.
    fun {MapGenerator}
        % GridStructure: Recursively builds the map grid.
        % Input: Acc - Current index in the grid (0 to Dim*Dim - 1)
        % Output: List of 0s and 1s representing the grid structure
        fun {GridStructure Acc}
            Next
        in
            if Acc < Dim*Dim then
                % Check if on border
                if Acc < Dim then  % First row
                    Next = 1
                elseif Acc >= (Dim-1)*Dim then  % Last row
                    Next = 1
                elseif Acc mod Dim == 0 then  % First column
                    Next = 1
                elseif Acc mod Dim == Dim-1 then  % Last column
                    Next = 1
                else
                    if ({OS.rand} mod 100) < InsideWalls then
                        Next = 1
                    else
                        Next = 0
                    end
                end
                Next | {GridStructure Acc+1}
            else
                nil
            end
        end
    in
        {GridStructure 0}
    end
end
