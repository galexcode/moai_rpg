--[[ Character class ]]

module(..., package.seeall)

Character = {}
Character.__index = Character

function new(name, kind, i, j)
    --[[ Instantiate our class and call loading methods ]]
    local character = Character.instantiate(name, kind)
    character:load_attribs()
    character:load_gfx()
    character.prop:setLoc(map:idx_to_coords(i, j))
    return character
end

function Character.instantiate(name, kind)
    local character = {}                  -- instance
    setmetatable(character, Character)
    character.name = name
    character.kind = kind
    return character
end

function Character:load_gfx()
    --[[ Load sprite into map ]]
    local texture = MOAITexture.new()
    texture:load('images/'..self.attribs.type..'/'..
                 self.attribs.texture..'.png')
    local sprite = MOAIGfxQuad2D.new()
    sprite:setTexture(texture)
    local w, h = texture:getSize()
    sprite:setRect(-w/32, -h/32, w/32, h/32) -- (w/2) / (16 px/world unit)
    self.prop = MOAIProp2D.new()
    self.prop:setDeck(sprite)
    self.width, self.height = 1, 1
    self.dir_x, self.dir_y = 0, 0
end

function Character:load_attribs()
    --[[ Load attributes into self.attribs ]]
    humans = lib.assload.read('objects/humans/', 'json')
    monsters = lib.assload.read('objects/monsters/', 'json')
    -- Try one, if nil, try the other. TODO: Bug if kinds are not unique!
    self.attribs = humans[self.kind] or monsters[self.kind]
end

-- MOVEMENT COMPONENTS --
-- TODO: Move outside!

function Character:seek_location(X, Y)
    --[[ A prop method for seeking an (X,Y) world unit location. --]]
    local X_cur, Y_cur = self.prop:getLoc()
    local distance = helpers.math.distance(X, Y, X_cur, Y_cur)
    if distance <= 0 then return nil end
    local time = distance / self.attribs.speed
    self.dir_x = (X - X_cur) / distance -- X unit vector component
    self.dir_y = (Y - Y_cur) / distance -- Y unit vector component

    function thread_func()
        self.is_moving = true
        self.move_action = self.prop:seekLoc(X, Y, time, MOAIEaseType.LINEAR)
        MOAICoroutine.blockOnAction(self.move_action)
        self.is_moving = false
    end
    self.thread = MOAICoroutine.new()
    self.thread:run(thread_func)
end -- seek_location(x, y)

function Character:rebound()
    --[[ Bounce backwards from current direction vector. --]]
    local X_cur, Y_cur = self.prop:getLoc()
    local X_new = X_cur - self.dir_x * 0.5  -- rebound by 1/2 world units
    local Y_new = Y_cur - self.dir_y * 0.5
    self.prop:setLoc(X_new, Y_new)
end -- rebound(self)

function Character:re_move()
    --[[ Move to last known good location. --]]
    self.prop:setLoc( self:get_last_loc() )
end -- re_move(self)

function Character:get_last_loc()
    --[[ Simply return last known location as an (X, Y) coord. --]]
    return self.last_X, self.last_Y
end -- get_last_loc()

function Character:set_last_loc()
    --[[ Save current location as last known good location. --]]
    self.last_X, self.last_Y = self.prop:getLoc()
    return nil
end -- set_last_loc(self)

function Character:move_cell(direction)
    --[[ Move the character by a map tile, along the grid. --]]
    local i, j = map:coords_to_idx(self.prop:getLoc())
    if direction == 'up' then
        next_i, next_j = i - 1, j
    elseif direction == 'down' then
        next_i, next_j = i + 1, j
    elseif direction == 'left' then
        next_i, next_j = i, j - 1
    elseif direction == 'right' then
        next_i, next_j = i, j + 1
    else
        print('Warning: bad direction ('..(direction or 'nil')..')')
    end
    if direction == nil then
        return nil
    end
    local tile = map.grid[next_i][next_j]
    if tile.walkable then
        if not self.is_moving then
            self:seek_location(tile:getLoc())
            self.is_moving = true
        end
    else
        print('not walkable at: ['..next_i..']['..next_j..']')
        lib.sounds.play_sound('blip')
    end
end

function Character:isMoving()
    --[[ Return true if dude is moving. --]]
    if self.move_action ~= nil and self.move_action:isBusy() then
        return true
    end
    return false
end

function Character:stop()
    if self:isMoving() then
        self.move_action:stop()
    end
end

function Character:random_move()
    local cur_i, cur_j = map:coords_to_idx(self.prop:getLoc())
    local path = {}
    local moves_remaining = self.attribs.move_distance
    local attempts = 0
    while moves_remaining > 0 do
        attempts = attempts + 1
        local dir = math.random(1,4)
        local di, dj = 0, 0
        if dir == 1 then di = 1
        elseif dir == 2 then di = -1
        elseif dir == 3 then dj = 1
        elseif dir == 4 then dj = -1
        end
        local next_i, next_j = (cur_i + di), (cur_j + dj)
        if map.grid[next_i] ~= nil
        and map.grid[next_i][next_j] ~= nil
        and map.grid[next_i][next_j].walkable then
            table.insert(path, {next_i, next_j})
            moves_remaining = moves_remaining - 1
            cur_i, cur_j = next_i, next_j
        end
        if attempts > 50 then break end -- Character is stuck, just chill.
    end
    for i, entry in ipairs(path) do
        X, Y = map:idx_to_coords(entry[1], entry[2])
        self:seek_location (X, Y)
    end
end -- Character:random_move()

