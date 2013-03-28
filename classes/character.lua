--[[ Character class ]]

module(..., package.seeall)

Character = {}
Character.__index = Character

function Character.new(name)
    local character = {}                  -- instance
    setmetatable(character, Character)
    character.name = name
    return character
end

function Character:get_name()
    --[[ Return name ]]
    return self.name
end

function Character:load_gfx()
    --[[ Load sprite into map ]]
    local texture = MOAITexture.new()
    texture:load('images/chars/dude_1.png')
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
    -- TODO: Load from JSON
    local atr = {}
    atr.speed = 3
    atr.move_distance = 1
    atr.health = 20
    atr.strength = 5
    atr.defence = 3
    atr.agility = 3
    self.attribs = atr
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
        self.move_action = self.prop:seekLoc(X, Y, time,
                                                  MOAIEaseType.LINEAR)
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
