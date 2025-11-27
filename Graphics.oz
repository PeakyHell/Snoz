%%% Graphics Module
%%% Manages all graphical rendering, game objects, and the GUI window.
%%% Handles drawing of snakes, fruits, the map, and game state display.

functor

import
    OS
    Application
    QTk at 'x-oz://system/wp/QTk.ozf'
    Input
    Browser
export
    'spawn': SpawnGraphics
define
    % Constants for graphics
    CD = {OS.getCWD}
    FONT = {QTk.newFont font('size': 18)}
    WALL_TILE = {QTk.newImage photo(file: CD # '/assets/wall.png')}
    DEFAULT_GROUND_TILE = {QTk.newImage photo(file: CD # '/assets/ground/ground_1.png')}

    FRUIT_SPRITE = {QTk.newImage photo(file: CD # '/assets/fruit.png')}
    ROTTEN_FRUIT_SPRITE = {QTk.newImage photo(file: CD # '/assets/rotten_fruit.png')}
    Dico = {Dictionary.new}
    % GameObject: Base class for all game entities.
    % Attributes:
    %   - id: Unique identifier for the object
    %   - type: Type of object ('snake', etc.)
    %   - sprite: QTk image to render
    %   - x, y: Pixel coordinates for rendering (not grid coordinates)
    % Methods:
    %   - init(Id Type Sprite X Y): Initializes the game object
    %   - getType($): Returns the type of this object
    %   - render(Buffer): Renders the sprite onto the given buffer
    %   - update(GCPort): Updates the object state (overridden in subclasses)
    class GameObject
        attr 'id' 'type' 'sprite' 'x' 'y' 'snakescore'

        % init: Initializes a game object.
        % Inputs: Id (integer), Type (atom), Sprite (QTk image), X (pixels), Y (pixels)
        meth init(Id Type Sprite X Y)
            'id' := Id
            'type' := Type
            'sprite' := Sprite
            'x' := X
            'y' := Y
            'snakescore' := 0
        end

        % getType: Returns the type of this game object.
        % Output: Type atom
        meth getType($) @type end

        % render: Draws this object on the given buffer.
        % Input: Buffer (QTk image buffer)
        meth render(Buffer)
            for body_part(x:X y:Y) in @tail do
                {Buffer copy(@sprite.body 'to': o(X Y))} end
            {Buffer copy(@sprite.head 'to': o(@x @y))}
        
        end
        % update: Updates object state each frame (default: no-op).
        % Input: GCPort (Game Controller port)
        meth update(GCPort) skip end
    end

    % Snake: Represents a snake game object with animated movement.
    % Inherits from: GameObject
    % Attributes (in addition to GameObject):
    %   - isMoving: Boolean, true when snake is animating movement
    %   - moveDir: Current movement direction ('north', 'south', 'east', 'west')
    %   - targetX, targetY: Target pixel coordinates for current movement
    %   - tail: List of body parts (body_part(x y))
    %   - length: Current length of the snake
    % Methods:
    %   - init(Id X Y): Initializes the snake at pixel coordinates (X, Y)
    %   - setTarget(Dir): Sets movement direction and target coordinates
    %   - move(GCPort): Moves snake towards target by 4 pixels per frame
    %   - update(GCPort): Called each frame to update snake position
    %   - grow(Size): Increases snake length (currently unimplemented)
    class Snake from GameObject
        attr 'isMoving' 'moveDir' 'targetX' 'targetY'
        'tail' 'length' 'framesMoved' 'growPending' 'pending' 'head'

        % init: Initializes a snake.
        % Inputs: Id (unique identifier), X (pixel x-coord), Y (pixel y-coord)
        meth init(Id X Y)
            Images Head Body in
               Body = {QTk.newImage photo(file: CD # '/assets/SNAKE_' # Id # '/body.png')}
               Head = {QTk.newImage photo(file: CD # '/assets/SNAKE_' # Id # '/head_north.png')}
            Images = images(head: Head body: Body)
           GameObject, init(Id 'snake'  Images X Y)
            'isMoving' := false
            'targetX' := X
            'targetY' := Y
            'tail' :=  body_part(x:X y:Y) | nil
            'length' := 1
            'framesMoved' := 0
            'growPending' := 0
            'pending' := nil
        end

        % setTarget: Sets the movement direction and calculates target coordinates.
        % Input: Dir (direction atom: 'north', 'south', 'east', 'west')
        % Sets target 32 pixels away in the specified direction
        meth setTarget(Dir)
            local HeadFile in
            'isMoving' := true
            'moveDir' := Dir
             HeadFile = case Dir
               of 'north' then CD # '/assets/SNAKE_' # @id # '/head_north.png'
               [] 'south' then CD # '/assets/SNAKE_' # @id # '/head_south.png' 
               [] 'east' then CD # '/assets/SNAKE_' # @id # '/head_east.png'
               [] 'west' then CD # '/assets/SNAKE_' # @id # '/head_west.png'
               end
    'sprite' := images(head: {QTk.newImage photo(file: HeadFile)} body: @sprite.body) end
            if Dir == 'north' then
                'targetY' := @y - 32
            elseif Dir == 'south' then
                'targetY' := @y + 32
            elseif Dir == 'east' then
                'targetX' := @x + 32
            elseif Dir == 'west' then
                'targetX' := @x - 32
            end
        end

        % move: Animates movement by updating position 4 pixels per frame.
        % Input: GCPort (Game Controller port)
        % Sends movedTo message when target is reached
        meth move(GCPort)
            PrevX PrevY NewTail Occ in
        PrevX = @x PrevY = @y

        if @moveDir == 'north' then 'y' := @y - 4
        elseif @moveDir == 'south' then 'y' := @y + 4
        elseif @moveDir == 'east'  then 'x' := @x + 4
        elseif @moveDir == 'west'  then 'x' := @x - 4
        end

        'framesMoved' := @framesMoved + 1
        Occ =  {Map @tail fun {$ body_part(x:Xi y:Yi)} Xi div 32 # Yi div 32 end}
        if @framesMoved mod 8 == 0 then
            if @growPending > 0 then
            'pending' := body_part(x:PrevX y:PrevY) | @pending
            'growPending' := @growPending - 1
        else
            if @pending \= nil then
                'tail' := {Record.toList @pending} | @tail
                'tail' := {List.flatten @tail}
                'pending' := nil
            end

            NewTail = body_part(x:@x y:@y) | @tail
            if {Length NewTail} > @length then
                'tail' := {List.take NewTail @length}
            else
                'tail' := NewTail
            end end end

        if @x == @targetX andthen @y == @targetY then
            'isMoving' := false
            NewX = @x div 32
            NewY = @y div 32
        in
            {Send GCPort occupiedTiles(@id Occ)}
            {Send GCPort movedTo(@id @type NewX NewY)}
            {Dictionary.put Dico @id @snakescore}
            {Send GCPort snakeScores(Dico)}
        end end

        % update: Called each frame to update snake state.
        % Input: GCPort (Game Controller port)
        meth update(GCPort)
            if @isMoving then
                {self move(GCPort)}
            end
        end

        % grow: Increases snake length
        % Input: Size (number of segments to add)
        meth grow(Size)
            % TODO
            % Increase the length of the snake
            % Modify the tail attribute
            % Render the tail (Not in this method)
            'growPending' := @growPending + Size
            'length' := @length + Size
            'snakescore' := @snakescore +1
        end
    end

    % Graphics: Main graphics management class
    class Graphics
        attr
            'buffer' 'buffered' 'canvas' 'window'
            'score' 'scoreHandle'
            'ids' 'gameObjects'
            'background'
            'running'
            'gcPort'
            'lastMsg'
            'lastMsgHandle'
            'grid_dim'

        % init: Initializes the graphics system and creates the game window.
        % Input: GCPort (Port to the Game Controller)
        % Creates a window with canvas, buttons, score display, and message box
        meth init(GCPort)
            Height
            GridWidth
            PanelWidth = 400
            Width
        in
            'running' := true
            'gcPort' := GCPort
            'grid_dim' := Input.dim
            Height = @grid_dim*32
            GridWidth = @grid_dim*32
            Width = GridWidth + PanelWidth
            'buffer' := {QTk.newImage photo('width': GridWidth 'height': Height)}
            'buffered' := {QTk.newImage photo('width': GridWidth 'height': Height)}

            'window' := {QTk.build td(
                canvas(
                    'handle': @canvas
                    'width': Width
                    'height': Height
                    'background': 'black'
                )
                button(
                    'text': "close"
                    'action' : proc {$} {Application.exit 0} end
                )
            )}

            'score' := 0
            'lastMsg' := 'Message box is empty'
            {@canvas create('image' GridWidth div 2 Height div 2 'image': @buffer)}
            {@canvas create('text' GridWidth+(PanelWidth div 2) 50 'text': 'score: 0' 'fill': 'white' 'font': FONT 'handle': @scoreHandle)}
            {@canvas create('text' GridWidth+(PanelWidth div 2) 100 'text': 'Message box: empty' 'fill': 'white' 'font': FONT 'handle': @lastMsgHandle)}
            'background' := {QTk.newImage photo('width': GridWidth 'height': Height)}
            {@window 'show'}
            'gameObjects' := {Dictionary.new}
            'ids' := 0
        end

         meth getGameObjectCount($)
            {Length {Dictionary.keys @gameObjects}}
        end
        % isRunning: Returns whether the graphics system is running.
        % Output: Boolean
        meth isRunning($) @running end

        % genId: Generates a unique identifier.
        % Output: Integer ID
        meth genId($)
            'ids' := @ids + 1
            @ids
        end

        % spawnFruit: Spawns a fruit at the given grid coordinates.
        % Inputs: X (grid x), Y (grid y)
        % Draws fruit on background and notifies Game Controller
        meth spawnFruit(X Y)
            {@background copy(FRUIT_SPRITE 'to': o(X * 32 Y * 32))}
            {Send @gcPort fruitSpawned(X Y)}
        end

        % dispawnFruit: Removes a fruit and schedules respawn after 500ms.
        % Inputs: X (grid x), Y (grid y)
        meth dispawnFruit(X Y)
            NewX = {OS.rand} mod @grid_dim
            NewY = {OS.rand} mod @grid_dim
        in
            thread
                {self spawnFruit(NewX NewY)}
            end
            {@background copy(DEFAULT_GROUND_TILE 'to': o(X * 32 Y * 32))}
            {Send @gcPort fruitDispawned(X Y)}
        end

        meth ateFruit(X Y Id)
            Bot = {Dictionary.condGet @gameObjects Id 'null'}
        in
            if Bot \= 'null' then
                {Bot grow(1)}
            end
        end

        % buildMap: Constructs the static background from the map.
        % Input: Map (list of 0s and 1s, where 1=wall, 0=empty)
        % Draws walls and ground tiles, randomly spawns fruits
        % Random fruit generation
        meth buildMap(Map)
            Z = {NewCell 0}
        in
            for K in Map do
                X = @Z mod @grid_dim
                Y = @Z div @grid_dim
                Rand_n = {OS.rand}
                Tile_index = (Rand_n mod 3)+1
            in
                if K == 0 then
                    {@background copy({QTk.newImage photo(file: CD # '/assets/ground/ground_' # Tile_index # '.png')} 'to': o(X * 32 Y * 32))}
                    if Rand_n mod (((Input.dim-1)*(Input.dim-1)) div 8) == 0 then {self spawnFruit(X Y)} end
                elseif K == 1 then
                    {@background copy(WALL_TILE 'to': o(X * 32 Y * 32))}
                end
                Z := @Z + 1
            end
        end

        % spawnBot: Creates and registers a new bot sprite.
        % Inputs: Type ('snake'), X (grid x), Y (grid y)
        % Output: Unique bot ID
        % Notifies Game Controller that bot has spawned
        meth spawnBot(Type X Y $)
            Bot
            Id = {self genId($)}
        in
            if Type == 'snake' then
                Bot = {New Snake init(Id X * 32 Y * 32)}
            else
                skip
            end

            {Dictionary.put @gameObjects Id Bot}
            {Send @gcPort movedTo(Id Type X Y)}
            Id
        end

        % dispawnBot: Removes a bot from the game.
        % Input: Id (bot identifier)
        meth dispawnBot(Id)
            {Dictionary.remove Dico Id}
            {Dictionary.remove @gameObjects Id}
        end

        % moveBot: Initiates movement for a bot in the specified direction.
        % Inputs: Id (bot identifier), Dir (direction atom)
        meth moveBot(Id Dir)
            Bot = {Dictionary.condGet @gameObjects Id 'null'}
        in
            if Bot \= 'null' then
                {Bot setTarget(Dir)}
            end
        end

        % updateScore: Updates the displayed score.
        % Input: NewScore (integer)
        meth updateScore(NewScore)
            'score' := NewScore
            {@scoreHandle set('text': "score: " # @score)}
        end
meth updateSchet(Xyi)
    
    {@canvas tk(delete scoreTag)}
   proc {PrintScore Lis I}
    Head in
      case Lis of (Color#Schet)|T then 
        Head = {QTk.newImage photo(file: CD # '/assets/SNAKE_' # Color # '/head_south.png')}
        {@canvas create('image' (@grid_dim*32)+(200 div 2) I 'image': Head 'tags': scoreTag)}
        {@canvas create('text' (@grid_dim*32)+(400 div 2) I 'text': Schet 'fill': 'white' 'font': FONT 'tags': scoreTag)} {PrintScore T I+50}
      [] nil then skip end
   end 
in
   {PrintScore (Xyi) 200}
end 



        % updateMessageBox: Updates the message box display.
        % Input: Msg (string or atom to display)
        meth updateMessageBox(Msg)
            'lastMsg' := Msg
            {@lastMsgHandle set('text': "Message box: " # @lastMsg)}
        end

        % update: Main rendering loop - updates and draws all game objects.
        % Called each frame by the ticker thread
        % Uses double buffering: draws to buffered, then copies to buffer
        meth update()
            GameObjects = {Dictionary.items @gameObjects}
        in
            {@buffered copy(@background 'to': o(0 0))}
            for Gobj in GameObjects do
                {Gobj update(@gcPort)}
                {Gobj render(@buffered)}
            end
            {@buffer copy(@buffered 'to': o(0 0))}
        end
    end

    % NewActiveObject: Creates an active object that processes messages in a separate thread.
    % Inputs:
    %   - Class: Class to instantiate
    %   - Init: Initialization method to call
    % Output: Procedure that sends messages to the object
    fun {NewActiveObject Class Init}
        Stream
        Port = {NewPort Stream}
        Instance = {New Class Init}
    in
        thread
            for Msg in Stream do {Instance Msg} end
        end

        proc {$ Msg} {Send Port Msg} end
    end

    % SpawnGraphics: Creates and starts the graphics system with a rendering loop.
    % Inputs:
    %   - Port: Game Controller port
    %   - FpsMax: Maximum frames per second (e.g., 30)
    % Output: Active Graphics object (procedure to send messages)
    % Starts a ticker thread that calls update() every FrameTime milliseconds
    fun {SpawnGraphics Port FpsMax}
        Active = {NewActiveObject Graphics init(Port)}
        FrameTime = 1000 div FpsMax

        % Ticker: Recursive procedure that runs the render loop.
        proc {Ticker}
            if {Active isRunning($)} then
                {Active update()}
                {Delay FrameTime}
                {Ticker}
            end
        end
    in
        thread {Ticker} end
        Active
    end
end