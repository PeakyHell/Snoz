%%% Main Game Controller Module
%%% Coordinates the entire multi-agent snake game.
%%% Manages game state, bot tracking, fruit spawning, and message broadcasting.

functor

import
    Input
    Graphics
    AgentManager
    Application
    System
    Browser
define

    StartGame
    Broadcast
    GameController
    Handler
    BotPort
    IsWall
    NewPosition

    % Mapping from bot IDs to color names for display
    ID_to_COLOR = converter(
        1: 'Purple'
        2: 'Marine'
        3: 'Green'
        4: 'Red'
        5: 'Cyan'
    )
in
   
    % Broadcast: Sends a message to all alive bots in the tracker.
    % Inputs:
    %   - Tracker: Record mapping bot IDs to bot information
    %   - Msg: Message to send to each bot's port
    proc {Broadcast Tracker Msg}
        {Record.forAll Tracker proc {$ Tracked} if Tracked.alive then {Send Tracked.port Msg} end end}
    end

    % GameController: Main game controller function managing game state and logic.
    % Input: State - Current game state
    % Output: Function that processes messages and returns updated controller instance
    % State attributes:
    %   - gui: Graphics object for rendering
    %   - map: Game map (list of 0s and 1s)
    %   - score: Global game score
    %   - gcPort: This controller's port
    %   - tracker: Record tracking all bots (id -> bot(id type port alive score x y))
    %   - active: Number of active bots
    %   - items: Record tracking fruits (index -> fruit(alive), nfruits count)
    fun {GameController State}

        % MoveTo: Handles bot movement requests.
        % Input: moveTo(Id Dir) message
        %   - Id: Bot identifier requesting to move
        %   - Dir: Direction to move ('north', 'south', 'east', 'west')
        % Output: Updated game controller instance
        % Validates movement, updates graphics, broadcasts position to all bots
        fun {MoveTo moveTo(Id Dir)}
            Pos NewTracker NewBot NewPos Current Occ Xyesos Lox Xyi
        in
            if State.tracker.Id.alive == true then
   
                Pos = pos('x':State.tracker.Id.x  'y':State.tracker.Id.y)
                Current = State.tracker.Id.x#State.tracker.Id.y
                Lox = {Dictionary.entries State.scores}
                Xyi = {List.sort Lox fun {$ A B} A.2 > B.2 end}
                {State.gui updateSchet(Xyi)}
                Occ = {List.flatten {Record.toList State.occupiedTiles}} %%%% pas fini / append here heads for other snakes
                if {State.gui getGameObjectCount($)} == 1 then
                    {State.gui updateMessageBox(ID_to_COLOR.Id # ' wins the game!')}
                    {State.gui dispawnBot(Id)}
                    
                end
                for P in Occ do
                    if P == Current then
                        {State.gui dispawnBot(Id)}
                    {State.gui updateMessageBox(ID_to_COLOR.Id # ' died')}
                    end
                end
                if {IsWall Pos Dir State} == false then
                  
                    {State.gui moveBot(Id Dir)}
                    NewPos = {NewPosition Pos Dir}
                    NewBot = {Adjoin State.tracker.Id bot(x:NewPos.x y:NewPos.y)}
                    NewTracker = {AdjoinAt State.tracker Id NewBot}
                    
                else
                    {State.gui dispawnBot(Id)}
                    {State.gui updateMessageBox(ID_to_COLOR.Id # ' died')}
                    {Broadcast State.tracker movedTo(Id State.tracker.Id.type Pos.x Pos.y)}
                    {Send State.tracker.Id.port invalidAction()}
                    NewTracker = State.tracker
                end
            else NewTracker = State.tracker
            end
            
            {GameController {AdjoinAt State 'tracker' NewTracker}}
        end
        
        % FruitSpawned: Handles fruit spawning events.
        % Input: fruitSpawned(X Y) message
        %   - X, Y: Grid coordinates of new fruit
        % Output: Updated game controller instance
        % Adds fruit to items tracker and broadcasts to all bots
        fun {FruitSpawned fruitSpawned(X Y)}
            Index = Y * Input.dim + X
            NewItems
        in
            if {HasFeature State 'items'} then
                NewItems = {Adjoin State.items items(Index: fruit('alive': true) 'nfruits': State.items.nfruits + 1)}
            else
                NewItems = items(Index: fruit('alive':true) 'nRfruits':0 'nfruits':1)
            end

            {Broadcast State.tracker fruitSpawned(X Y)}
            {GameController {AdjoinAt State 'items' NewItems}}
        end

        % FruitDispawned: Handles fruit despawning events.
        % Input: fruitDispawned(X Y) message
        %   - X, Y: Grid coordinates of fruit being removed
        % Output: Updated game controller instance
        % Marks fruit as not alive and broadcasts to all bots
        fun {FruitDispawned fruitDispawned(X Y)}
            I NewItems
        in
            I = Y * Input.dim + X
            if State.items.I.alive == true then
                NewItems = {Adjoin State.items items(I:fruit('alive':false) 'nfruits':State.items.nfruits - 1)}
                {Broadcast State.tracker fruitDispawned(X Y)}
                {GameController {Adjoin State state('items':NewItems)}}
            else
                {GameController State}
            end
        end

        % MovedTo: Handles notifications that a bot has finished moving.
        % Input: movedTo(Id Type X Y) message
        %   - Id: Bot that moved
        %   - Type: Bot type ('snake')
        %   - X, Y: New grid coordinates
        % Output: Updated game controller instance
        % Checks for fruit consumption, updates score, broadcasts to all bots
        fun {MovedTo movedTo(Id Type X Y)}
            I NewState TempState
        in
            if State.tracker.Id.alive == true then
                I = Y * Input.dim + X
                {Wait State.tracker}

                if Type == 'snake' then
                    if {HasFeature State.items I} andthen {And State.items.I.alive State.tracker.Id.alive} then
                        if {Label State.items.I} == 'fruit' then
                            % update score and message box
                            {State.gui updateScore(State.score + 1)}
                            {State.gui updateMessageBox(ID_to_COLOR.Id # ' ate a fruit')}

                            % remove the fruit
                            {State.gui dispawnFruit(X Y)}

                            % update the state
                            TempState = {AdjoinAt State 'score' State.score+1}
                            NewState = {AdjoinAt TempState 'active' State.active+1}

                            % update the snake that has eaten the fruit
                            % * Increase its personal score
                            % * Increase its tail length and render it
                            % TODO
                            {State.gui ateFruit(X Y Id)}

                        else
                            NewState = State
                        end
                    else
                        NewState = State

                    end
                else
                    NewState = State
                end
                {Broadcast State.tracker movedTo(Id Type X Y)}
            else
                NewState = State
            end

            {GameController NewState}
        end
        fun {OccupiedTiles occupiedTiles(Id Tiles)}
            NewOccupied = {AdjoinAt State.occupiedTiles Id Tiles}
        in
            {GameController {AdjoinAt State 'occupiedTiles' NewOccupied}}
        end

        fun {SnakeScores snakeScores(Dico)}
            %Color = ID_to_COLOR.Id
            %NewScores = {Dictionary.clone State.scores}
        %in
        %{Dictionary.put NewScores Id Score}
        {GameController {AdjoinAt State 'scores' Dico}}
        end
        % TellTeam: Handles team communication between bots of the same type.
        % Input: tellTeam(Id Msg) message
        %   - Id: Bot sending the message
        %   - Msg: Message to send to teammates
        % Output: Updated game controller instance
        % Broadcasts message only to bots of the same type (excluding sender)
        fun {TellTeam tellTeam(Id Msg)}
            TeamTracker
            % TeamFilter: Filters bots that are the same type but not the sender
            proc {TeamFilter X ?R}
                if X.type == State.tracker.Id.type andthen X.id \= Id then R = true
                else R = false
                end
            end
        in
            TeamTracker = {Record.filter State.tracker TeamFilter}
            {Broadcast TeamTracker tellTeam(Id Msg)}
            {GameController State}
        end
    in
        % Message dispatcher function
        fun {$ Msg}
            Dispatch = {Label Msg}
            Interface = interface(
                'moveTo': MoveTo
                'movedTo': MovedTo
                'fruitSpawned':FruitSpawned
                'fruitDispawned':FruitDispawned
                'tellTeam':TellTeam
                'occupiedTiles':OccupiedTiles
                'snakeScores': SnakeScores
            )
        in
            if {HasFeature Interface Dispatch} then
                {Interface.Dispatch Msg}

            else
                {GameController State}
            end
        end
    end

    % Handler: Processes messages from the stream and updates controller instance.
    % Inputs:
    %   - Msg | Upcoming: Stream pattern with current message and remaining stream
    %   - Instance: Current game controller instance (function)
    % Output: None (recursive procedure)
    % Exits application if Instance becomes a record (game over condition)
    % Note: Msg | Upcoming is a pattern match of the Stream argument
    proc {Handler Msg | Upcoming Instance}
        if {Record.is Instance} then
            {Application.exit 0}
        else
            {Handler Upcoming {Instance Msg}}
        end
    end

    % IsWall: Checks if moving in a direction would hit a wall.
    % Inputs:
    %   - Pos: Current position record pos(x y)
    %   - Dir: Direction to check ('north', 'south', 'east', 'west')
    %   - State: Game state containing the map
    % Output: Boolean (true if wall, false if free)
    fun {IsWall Pos Dir State}
        X Y I NewX NewY
    in
        X = Pos.x
        Y = Pos.y
        case Dir
        of 'north' then NewX=X NewY=Y-1
        [] 'south' then NewX=X NewY=Y+1
        [] 'east' then NewX=X+1 NewY=Y
        else NewX=X-1 NewY=Y
        end

        I = NewY*Input.dim+NewX+1

        if {List.nth State.map I} == 1 then true
        else false
        end
    end

    % NewPosition: Calculates the new position after moving in a direction.
    % Inputs:
    %   - Pos: Current position record pos(x y)
    %   - Dir: Direction to move ('north', 'south', 'east', 'west')
    % Output: New position record pos(x y)
    fun {NewPosition Pos Dir}
        X Y NewX NewY
    in
        X = Pos.x
        Y = Pos.y
        case Dir
        of 'north' then NewX=X NewY=Y-1
        [] 'south' then NewX=X NewY=Y+1
        [] 'east' then NewX=X+1 NewY=Y
        else NewX=X-1 NewY=Y
        end
        pos('x':NewX 'y':NewY)
    end

    % BotPort: Creates and spawns all bots from the Input.bots configuration.
    % Inputs:
    %   - GCPort: Game Controller port
    %   - Map: Game map
    %   - GUI: Graphics object
    %   - Tracker: Initial tracker record (empty)
    % Output: Tracker record containing all spawned bots
    fun {BotPort GCPort Map GUI Tracker}

        % BotPortInner: Recursively spawns bots and builds tracker.
        % Inputs:
        %   - Bots: List of bot specifications bot(Type Template X Y)
        %   - GCPort, Map, GUI: Passed through
        %   - Tracker: Accumulator for bot tracking
        % Output: Complete tracker record
        fun {BotPortInner Bots GCPort Map GUI Tracker}
            local Id BotPort in
                case Bots
                of bot(Type Template X Y)|T then
                    case Type
                    of snake then
                        Id = {GUI spawnBot('snake' X Y $)}
                        BotPort = {AgentManager.spawnBot Template init(Id GCPort Map)}
                        {BotPortInner T GCPort Map GUI {AdjoinAt Tracker Id bot(id:Id type:Type port:BotPort alive:true score:0 x:X y:Y)}}
                    else {BotPortInner T GCPort Map GUI Tracker}
                    end
                []nil then Tracker
                end
            end
        end

    in
        {BotPortInner Input.bots GCPort Map GUI Tracker}
    end

    % StartGame: Initializes and starts the game.
    % Inputs: None
    % Output: None (runs game in a thread)
    % Creates GUI, spawns all bots, initializes game controller, starts message handler
    proc {StartGame}
        thread

            Stream BotTracker
            Port = {NewPort Stream}
            % 30 is the number of tick per s
            GUI = {Graphics.spawn Port 30}

            Map = {Input.genMap}
            {GUI buildMap(Map)}

            Instance = {GameController state(
                'gui': GUI
                'map': Map
                'score': 0
                'scores' : {Dictionary.new}
                'gcPort':Port
                'tracker':BotTracker
                'active':0
                'occupiedTiles': occupiedTiles()
            )}
        in

            % TODO: log the winning team name and the score then use {Application.exit 0}

            local Tracker in
                Tracker = tracker()
                BotTracker = {BotPort Port Map GUI Tracker}
            end
            {Handler Stream Instance}
        end

    end

    % Start the game on module load
    {StartGame}
end