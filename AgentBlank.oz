%%% Agent Blank Module
%%% A simple random-movement snake agent template.
%%% This agent moves randomly and tracks other bots in the game.

functor

import
    OS
    Input
export
    'getPort': SpawnAgent
define

    % Mapping from random numbers (1-4) to cardinal directions
    Directions = directions(
        1: 'north'
        2: 'south'
        3: 'east'
        4: 'west'
    )

    % NextMove: Calculates the next position given current state and direction.
    % Inputs:
    %   - State: Current agent state record with 'x' and 'y' coordinates
    %   - Dir: Direction atom ('north', 'south', 'east', 'west')
    % Output: Record m('x':NewX 'y':NewY) representing the new position
    fun {NextMove State Dir}
        I
    in
        case Dir
        of 'north' then I = (State.y - 1)*Input.dim+State.x+1 m('x':State.x 'y':State.y-1)
        [] 'south' then I = (State.y + 1)*Input.dim+State.x+1 m('x':State.x 'y':State.y+1)
        [] 'east' then I = State.y*Input.dim+(State.x+1)+1 m('x':State.x+1 'y':State.y)
        [] 'west' then I = State.y*Input.dim+(State.x-1)+1 m('x':State.x-1 'y':State.y)
        else 0
        end
    end

    % Agent: Main agent function implementing the behavior loop.
    % Input: State - Current agent state containing id, map, gcport, dir, x, y, tracker, port
    % Output: Function that processes messages and returns updated agent instance
    % State attributes:
    %   - id: Unique agent identifier
    %   - map: Game map (list of integers)
    %   - gcport: Port to the Game Controller
    %   - dir: Current direction ('north', 'south', 'east', 'west', 'stopped')
    %   - x, y: Current grid coordinates
    %   - tracker: Record tracking other bots
    %   - port: This agent's communication port
    fun {Agent State}

        % MovedTo: Handles the movedTo message when this bot moves.
        % Input: movedTo(Id _ X Y) message
        %   - Id: Bot identifier that moved
        %   - _: Bot type ('snake')
        %   - X, Y: New grid coordinates
        % Output: Updated agent instance
        fun {MovedTo movedTo(Id _ X Y)}
            Next TempState NewTracker NewDir
        in
            if Id == State.id then
                    TempState = {Adjoin State state('x':X 'y':Y)}
                        
                    % Pick a random direction
                    % NewDir = Directions.({OS.rand} mod 4 + 1)
                    NewDir = {ChooseDirection TempState}

                    Next = {NextMove TempState NewDir}
                    {Send State.gcport moveTo(State.id NewDir)}

                    {Agent {Adjoin TempState state('dir':NewDir 'tracker':NewTracker)}}
            else
                {Agent {AdjoinAt State 'tracker' NewTracker}}
            end
        end

    in
        % Message dispatcher function
        fun {$ Msg}
            Dispatch = {Label Msg}
            Interface = interface(
                'movedTo': MovedTo
            )
        in
            if {HasFeature Interface Dispatch} then
                {Interface.Dispatch Msg}
            else
                {Agent State}
            end
        end
    end

    % Handler: Processes messages from the stream and updates agent instance.
    % Inputs:
    %   - Msg | Upcoming: Stream pattern with current message and remaining stream
    %   - Instance: Current agent instance (function)
    % Output: None (recursive procedure)
    % Note: Msg | Upcoming is a pattern match of the Stream argument
    proc {Handler Msg | Upcoming Instance}
        if Msg \= shutdown() then {Handler Upcoming {Instance Msg}} end
    end

    % SpawnAgent: Creates and initializes a new agent instance.
    % Input: init(Id GCPort Map) record
    %   - Id: Unique agent identifier
    %   - GCPort: Port to the Game Controller
    %   - Map: Game map as a list
    % Output: Port for communicating with the agent
    fun {SpawnAgent init(Id GCPort Map)}
        Stream
        Port = {NewPort Stream}

        Instance = {Agent state(
            'id': Id
            'map': Map
            'gcport': GCPort
            'dir':'stopped'
            'x':~1
            'y':~1
            'tracker':tracker()
            'port':Port
        )}
    in
        thread {Handler Stream Instance} end
        Port
    end

    % Inputs
    %   - State: The current state of the snake
    fun {ChooseDirection State}
        X Y SafeDirections L0 L1 L2 L3 
        fun {AddIfCond Dir Cond Acc}
            if Cond then Dir|Acc else Acc end
        end
    in
        X = State.x
        Y = State.y

        % Find the safe surronding cells
        L0 = nil

        L1 = {AddIfCond 'north'
            ({List.nth State.map {GetIndex X (Y-1)}} == 0)
            L0}

        L2 = {AddIfCond 'south'
            ({List.nth State.map {GetIndex X (Y+1)}} == 0)
            L1}

        L3 = {AddIfCond 'east'
            ({List.nth State.map {GetIndex (X+1) Y}} == 0)
            L2}

        SafeDirections = {AddIfCond 'west'
            ({List.nth State.map {GetIndex (X-1) Y}} == 0)
            L3}

        {ChooseSafeDirection State SafeDirections}
    end

    fun {ChooseSafeDirection State SafeDirections}
        X Y TargetX TargetY
    in
        X = State.x
        Y = State.y
        TargetX = Input.dim div 2
        TargetY = Input.dim div 2

        if SafeDirections == nil then
            State.dir % No possible direction so just continues
        elseif {List.member State.dir SafeDirections} then
            State.dir % If possible, continues in the same direction
        else
            if TargetX > X andthen {List.member 'east' SafeDirections} then
                'east'
            elseif TargetX < X andthen {List.member 'west' SafeDirections} then
                'west'
            elseif TargetY > Y andthen {List.member 'south' SafeDirections} then
                'south'
            elseif TargetY < Y andthen {List.member 'north' SafeDirections} then
                'north'
            else
                case SafeDirections of H|_ then H else State.dir end
            end
        end
    end

    fun {GetIndex X Y}
        Y*Input.dim + X + 1 % +1 because lists are 1 indexed
    end
end
