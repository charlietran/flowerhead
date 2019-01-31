pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- f l o w e r h e a d
-- by charlie tran

game_mode={
  intro={},
  game={is_game=1},
  lvl_complete={},
  outro={animtimer=0},
  debug_menu={}
}

function _init()
  current_game_mode=game_mode.intro
  printh("------\n")

  gravity=.05
  friction=.88

  -- speed of our animation loops
  runanimspeed=.3
  wallrunanimspeed=.2

  -- game length timer
  gametime=0

  coroutines={}
  deferred_draws={}

  -- holds all entities
  entities={player}

  game_mode.intro:init()
  clouds:init()
  cam:init()
  levels:init()
  player:init()
end

function _update60()
  run_coroutines()
  if not freeze then
    current_game_mode:update()
  end
end

function run_coroutines()
  for _,coroutine in pairs(coroutines) do
    if costatus(coroutine) != 'dead' then
      local ok,error=cowrap(coroutine)
    else
      del(coroutines,coroutine)
    end
  end
end

function _draw()
  current_game_mode:draw()
  for _,deferred in pairs(deferred_draws) do
    deferred()
  end
  if toggles.performance then draw_debug() end
end

function game_mode.game:update()
  gametime+=1
  cam:update()

  -- entities include player, bees, bombs
  for _,e in pairs(entities) do e:update() end

  particles:update()
  explosions:update()
end

function game_mode.game:draw()
  cls()

  clouds:draw()
  cam:draw()
  levels:draw()
  grasses:draw()
  -- entities include player, bees, bombs
  for _,e in pairs(entities) do e:draw() end
  particles:draw()
  explosions:draw()
  banners:draw()
  cam:fade()
end

clouds={
  speed=.1,
  padding=40,
}
clouds.list={}

function reset_level()
  player:init()
  cam.fadeout=1

  lvl.door_open=lvl.start_opened

  if not lvl.started then
    lvl.started=true
    banners:add(lvl)
  end

  -- reset all crumbling blocks
  crumbling={}

  -- reset all the planted tiles / grass counts
  grasses.map={}
  grasses.tiles={}
  for _,t in pairs(lvl.changed_tiles) do
    mset(t[1],t[2],t[3])
  end

  -- clean up bees
  sfx(-1,3)
  bees.count=0

  lvl.percent_complete=0
  lvl.planted=0
  lvl.bombs_disabled=true
  for index,v in pairs(lvl.bee_index) do
    lvl.bee_index[index]=true
  end
  entities={player}
  if lvl.flowerheart_x then
    flowerheart_class:new({
     x=lvl.flowerheart_x,
     y=lvl.flowerheart_y
    })
  end
  truncate(grasses.map)
  truncate(particles.list)
  truncate(explosions.list)
  truncate(deferred_draws)

  -- spawn bombs
  for _,s in pairs(lvl.bomb_spawns) do
  	bomb_class:new({
    x=s[1],y=s[2],vx=0,vy=0
   })
  end
end

function clouds:init()
  for i=1,45 do
    srand(i)
    local size=i/3
    self.list[i]={
      x=size+rnd(128-size),
      y=size+rnd(128-size),
      size=size
    }
  end
  --reset randomness seed
  srand(bnot(time()))
end

function clouds:draw()
  -- cloud checker pattern
  -- 0 = filled, 1 = empty
  -- 0100
  -- 1001
  -- 0011
  -- 1110
  camera(0,0)
  -- fillp(0b1010010110100101)

  -- this time factor is used to
  -- drift the clouds in the
  -- x direction. multiplied by
  -- 10 to get the right cloud
  -- drifting speed

  -- draw the clouds as circles
  -- drifting in the x direction
  -- over time and with parallax
  local tm=time()
  for _,cloud in pairs(self.list) do
    local cloudx,cloudy
    -- the y offset is the
    -- product of our current cam
    -- offset and the cloud size
    -- so that larger (closer)
    -- clouds appear to move more
    -- multiplied the magic .01
    -- to get the right parallax
    -- feeling
    cloudy=cloud.y-(cam.y*cloud.size*.01)%192

    -- our x offset is the same,
    -- with our time factor added
    -- so that the clouds appear
    -- to drift to the left

    local xdrift  = .1*cam.x+tm
    local xoffset = cloud.x-xdrift*cloud.size*clouds.speed
    local xrange  = 128+clouds.padding+2*cloud.size

    cloudx=xoffset%xrange-cloud.size

    fillp(0b0110111110111111)

    -- draw our cloud circle
    circfill(cloudx,cloudy,cloud.size,1)
  end

  fillp()
end

level_class={
  cx1=nil,cy1=nil,cx2=nil,cy2=nil,
  index=nil,
  timer_enabled=false,
  num_bees=0,
  changed_tiles={},
  bombs_disabled=true,
  desc=""
}

function level_class.new(o)
  local level=setmetatable(
  	o or {},
  	{__index=level_class}
  )
  level:setup()
  return level
end

function level_class:setup()
  local cx1,cy1=self.cx1,self.cy1
  -- initialize the level object
  -- with initial coordinates
  -- from the top-left block
  -- x/y   = pixel coords
  -- cx/cy = map cell coords
  self.sx1=cx1*8
  self.sy1=cy1*8

  self.plantable=0
  self.planted=0
  self.percent_complete=0
  self.obstacles={}

  self.bomb_spawns={}

  -- determine level bounds
  -- set the pixel bounds in x/y
  -- and cell bounds as cx/cy
  for cx2=cx1,127 do
    if mget(cx2,cy1)==9 then
      self.cx2=cx2
      self.sx2=cx2*8+8
      break
    end
  end

  for cy2=cy1,63 do
    if mget(cx1,cy2)==7 then
      self.cy2=cy2
      self.sy2=cy2*8+8
      break
    end
  end

  -- map all special tiles
  for cy=cy1,self.cy2 do
    for cx=cx1,self.cx2 do
      -- check for plantable tiles and set the level's plantable count
      if is_plantable(cx,cy) then
        self.plantable+=1
      end

      -- map obstacles
      local tile=mget(cx,cy)
      if is_wall(tile) or is_spike(tile) then
        self.obstacles[cy]=self.obstacles[cy] or {}
        self.obstacles[cy][cx]=true
      end

      if is_flowerheart(tile) then
       self.flowerheart_x=cx*8+3
       self.flowerheart_y=cy*8+2
       mset(cx,cy,0)
      end

      -- find the door and set location
      if tile==35 or tile==36 then
        self.door_cx=cx
        self.door_cy=cy
        self.door_sx=cx*8
        self.door_sy=cy*8
        self.start_opened = tile==36
      end

      if tile==18 then
       add(
        self.bomb_spawns,
        {cx*8+3,cy*8+3}
       )
       mset(cx,cy,0)
      end
    end
  end

  -- this bee_index represents at what planted number a bee should spawn
  -- i.e. if bee_index[5] = true, when tile #5 is planted a bee will spawn
  self.bee_index={}
  -- based on the level's num_bees, distribute the bee spawning evenly
  for i=1,self.num_bees do
    local bee_index = flr(i/(self.num_bees+1)*self.plantable)
    self.bee_index[bee_index]=true
  end

  self:set_spawn()
end

function level_class:set_spawn()
  -- find start sprite (#64) and
  -- set initial x/y position
  for i=self.cx1,self.cx2 do
    for j=self.cy1,self.cy2 do
      if mget(i,j)==64 then
        self.spawnx=i*8+3
        self.spawny=j*8
        mset(i,j,0)
        break
      end
    end
    if self.spawnx then break end
  end
end

function level_class:open_door()
  self.door_open=true
  sfx(0,0)
  add(deferred_draws,self:make_door_anim())
end

function level_class:make_door_anim()
  local x,y=self.door_cx*8+5,
  										self.door_cy*8+2
  local frame_count=0

  return function()
    if frame_count>240 then return end
    frame_count+=1
    local t=time()
    local rays=16
    local dx,dy=player.x-x,player.y-y

    -- pythag dist to the player
    -- divide then mult by 1000
    -- to avoid int overflow
    local distance=sqrt(
     (dx/1000)^2+(dy/1000)^2
    )*1000
    if frame_count>120 then
					distance*=(1-(frame_count-120)/120)
    end

    -- get the angle to the player
    local angle=.5+atan2(dx,dy)

    for i=1,rays do
      -- tmod is a time offset so that each ray
      -- starts at at different angle
      local tmod=t/rays+i/rays

      -- subtract our angle from tmod so that it points
      -- towards the player
      local dmod_angle=tmod-angle

      -- modify distance so that it shrinks while
      -- pointing away from the player
      local dmod=-.7*cos(dmod_angle)*(1-.2*cos(t/4))

      fillp(0b0011100111000110.1)
      line(
        x,y,
        x+dmod*distance*cos(tmod),
        y+dmod*distance*sin(tmod),
        10)
      fillp()
    end
  end
end

levels={ list={} }

function levels:init()
  -- reload map data from cart
  reload(0x2000,0x2000,0x1000)

  -- level list --
  levels.list={
   add_level(1 ,0 ,0 ,0,"welcome to the dungeon"),
   add_level(2 ,16,0 ,0,"meet the spikes"),
   add_level(3 ,32,0 ,0,"get a heart"),
   add_level(4 ,48,0 ,0,"leap motion"),
   add_level(5 ,64,0 ,0,"over the top"),
   add_level(6 ,78,0 ,0,"z jumpin'"),
   add_level(7 ,94,0 ,2,"here there be bees"),
   add_level(8 ,0 ,16,3,"feeding time"),
   add_level(9 ,16,16,1,"crumblies"),
   add_level(10,32,16,0,"no jumping"),
   add_level(11,48,16,6,"trench run"),
   add_level(12,78,16,2,"the tower"),
   --13
   --14
   --15
   add_level(16,96,32,6,"the throne room")
  }

  levels.index=1
  levels.door_frame=0
  lvl=levels.list[1]
end -- levels:init

function add_level(i,x,y,b,d)
	return level_class.new({
		index=i,
		cx1=x,
		cy1=y,
		num_bees=b,
		desc=d
	})
end

function levels:draw()
  -- animate the door
  if lvl.door_open then
    self.door_frame=(self.door_frame+.0625)%5
    mset(lvl.door_cx,lvl.door_cy,37+self.door_frame)
  else
    self.door_frame=(self.door_frame+.0625)%5
    mset(lvl.door_cx,lvl.door_cy,32+self.door_frame)
  end


  -- if exited, only draw the door at its screen location
  if lvl.exited then
    map(lvl.door_cx,lvl.door_cy,lvl.door_sx,lvl.door_sy,1,1)
  else
    -- otherwise, draw the whole current level
    map(lvl.cx1,lvl.cy1, -- cell coords of level origin
      lvl.sx1,lvl.sy1, -- screen coords of level origin
      lvl.cx2-lvl.cx1+1,
      lvl.cy2-lvl.cy1+1)
  end

  -- draw plant remainder above a locked exit
  if not lvl.door_open then
    local rem=""..(lvl.plantable-lvl.planted)
    print(rem,lvl.door_sx+(8-#rem*4)/2,lvl.door_sy-6,10)
  end
end

function levels:goto_next()
  self.index+=1
  lvl=self.list[self.index]

  if not lvl then
    current_game_mode=game_mode.outro
    return
  end

  current_game_mode=game_mode.game
  remove_entities("bee")
  truncate(deferred_draws)
  reset_level()
end

banners={list={}}

function banners:add(level)
  local banner={
    title="level "..level.index,
    caption=level.desc,
    height=level.banner_height or 32,
    x=0
  }
  banner.y=-banner.height -- start banner off screen
  add(self.list,banner)

  local anim1={duration=45,props={x=0,y=0}}
  local anim2={duration=45,props={x=0,y=-banner.height},easing=ease_in_quad}
  local seq=coroutine_sequence({
    make_animation(banner,anim1),
    make_delay(30),
    make_animation(banner,anim2),
    function() del(self.list,banner) end
  })

  add(coroutines,seq)
end

function banners:draw()
  --local ox,oy=cam.x-64,cam.y-64
  local tm=time()
  for _,b in pairs(self.list) do
    -- adjust banner x and y for camera position
    local x=cam.x-64
    local y=cam.y-64+b.y
    local width=127
    local margin=(128-width)/2

    rectfill(x+margin+2,y+2,x+margin+width+2,y+b.height+2,2)
    fillp(0b0111101111011110)
    rectfill(x+margin,y,x+margin+width,y+b.height,1)
    fillp()

    for i=1,#b.title do
      print(
        sub(b.title,i,i),
        x+margin+(width-#b.title*6)/2 + (i-1)*6,
        y+b.height/4+sin(i/#b.title + tm/2),
        10)
    end

    print(
      b.caption,
      x+margin+(width-#b.caption*4)/2,
      y+b.height*3/4,
      7)
  end
end

function game_mode.lvl_complete:start()
  -- change game mode and exit the level
  current_game_mode=game_mode.lvl_complete
  lvl.exited=true
  player.vx=0
  music(10,0,15)

  cinematic(false,120,
        function()
          music(0,0,1)
          levels:goto_next()
        end)
end

function game_mode.lvl_complete:update() end

function game_mode.lvl_complete:draw()
  cls()
  clouds:draw()
  cam:draw()
  levels:draw()
  for _,e in pairs(entities) do e:draw() end
end

--------------------------------
--visual effects----------------
function cinematic(lines,hold,callback,color)
  local color=color or 1
  local box1={
    x=cam.x-64,y=cam.y-64-127,w=127,h=127,color=color,
    params={props={x=cam.x-64,y=player.y-15-127},duration=30,hold=hold-30},
  }
  box1.params.draw=function() draw_box(box1) end
  local box2={
    x=cam.x-64,y=cam.y+64,w=127,h=127,color=color,
    params={props={x=cam.x-64,y=player.y+15},duration=30,hold=hold-30},
  }
  box2.params.draw=function() draw_box(box2) end
  deferred_animate(box1,box1.params)
  deferred_animate(box2,box2.params)
  if lines then
    local t={x=box2.x,y=box2.y}
    deferred_animate(t,
      {
        props={x=t.x,y=box2.params.props.y+6},duration=30,hold=hold-30,
        draw=function() for i,l in pairs(lines) do print(l,t.x+(64-#l*2),t.y+8*(i-1),7) end end
      })
  end
  add(coroutines,coroutine_sequence({ make_delay(hold), callback }))
end

function poof(x,y,c)
  for i=1,64 do
    spawnp(
      x,
      y,
      cos(i/64), -- vx
      sin(i/64), -- vy
      1, -- jitter
      c, -- color
      22 -- duration
      )
  end
end
--------------------------------
--entities----------------------
-- describes a game object that
-- has a position, velocity, a
-- sprite to draw, collides
-- with the map or other entities
-- and can be destroyed

entity_class={
  x=0, y=0, vx=0, vy=0,
  w=0, h=0, wr=0, hr=0,
  scale=1,
  anim={timer=0,frames=0,speed=1},
  spr_x=0,spr_y=0,
  flipx=false,
  dead=false,
  dying=false,
  map_collide=true,
  entity_collide=false,
  has_gravity=true,
  m_collide_callback=function(self,collision) end
}

function entity_class:new(o)
  local e = setmetatable(o or {}, {__index=entity_class})
  return insert(entities,e)
end

function entity_class:m_collide_callback(collision)
end

function entity_class:die()
  self.dead=true
  del(entities,self)
end

function entity_class:move()
  -- move through all our x steps, then our y steps
  local xsteps=abs(self.vx)
  local step,collision
  for i=xsteps,0,-1 do
    step=min(i,1)*sgn(self.vx)
    collision=self.map_collide and m_collide(self,'x',step)
    if collision then
      self:m_collide_callback(collision)
      break
    else
      if not self.is_player then self:check_e_collisions() end
      self.x+=step
    end
  end

  if self.has_gravity then
    self.vy+=gravity
  end

  local ysteps=abs(self.vy)
  for i=ysteps,0,-1 do
    step=min(i,1)*sgn(self.vy)
    collision=self.map_collide and m_collide(self,'y',step)
    if collision then
      self:m_collide_callback(collision)
      break
    else
      if not self.is_player then self:check_e_collisions() end
      self.y+=step
    end
  end
end

function entity_class:check_e_collisions()
  for _,entity in pairs(entities) do
    if entity ~= self then
      if e_collide(self,entity) then
        self:e_collide_callback(entity)
      end
    end
  end
end

function entity_class:draw()
  self:animate()
end

function entity_class:animate()
  if self.dead then return end

  self.anim.timer = (self.anim.timer+self.anim.speed) % self.anim.frames

  -- draw the entity's sprite from the sprite sheet
  sspr(
    -- the sprite's location on the sheet is based on the spr_x and spr_y attributes
    -- spr_x is multiplied by the anim timer because animation frames are
    -- laid out x-adjacent on the sprite sheet
    self.spr_x+flr(self.anim.timer)*self.w,
    self.spr_y,
    -- the width and height of our sprite on the sheet are self.w and self.h
    self.w,
    self.h,
    -- the screen coordinates of where to draw the sprite are offset
    -- by the sprites width radius and height radius, making the sprites
    -- x and y position the center of where we draw the sprite
    self.x-self.wr*self.scale,
    self.y-self.hr*self.scale,
    -- the final drawn width and height is scaled
    self.w*self.scale,
    self.h*self.scale,
    -- flip drawing on the x axis if self.flipx is true
    self.flipx
    )
end

function remove_entities(name)
  for e in all(entities) do
    if e.name==name then
      del(entities,e)
    end
  end
end

--------------------------------
--flowerheart-------------------
flowerheart_class={
  name="flowerheart",
  w=7,h=7,
  wr=3,hr=3,
  spr_x=56,spr_y=40,
  anim={timer=0,frames=7,speed=.142857143}
}
setmetatable(flowerheart_class,{__index=entity_class})

function flowerheart_class:new(obj)
  return setmetatable(entity_class:new(obj or {}), {__index=flowerheart_class})
end

function flowerheart_class:update()
  self:check_e_collisions()
end

function flowerheart_class:e_collide_callback(entity)
  if not entity.is_player then return end
  if lvl.index==3 and not flowerheart_obtained then
    flowerheart_obtained=1
    music(11,0,15)
    freeze=true
    cinematic(
      {
        "",
        "you found your heart",
        "",
        "press x to throw seed bombs",
      },
      260,
      function()
        freeze=false
        self:enable_bombing()
        music(0,0,1)
        sfx(7)
      end,
      3
      )
  else
    self:enable_bombing()
    sfx(7)
  end
end

function flowerheart_class:enable_bombing()
    self:die()
    lvl.bombs_disabled=false
    poof(self.x,self.y,3)
end

--------------------------------
--player object-----------------

player={}
setmetatable(player,{__index=entity_class})

function player:init()
  for k,v in pairs(player_init_vals) do player[k]=v end
  self.x=lvl.spawnx
  self.y=lvl.spawny
end

player_init_vals={
  name="player",
  scale=1,
  is_player=1,
  -- velocity
  vx=0,
  vy=0,
  --lists of our previous positions/flippage for effects rendering
  prevx=0,
  prevy=0,
  prevf=0,
  --the "effects" timer
  etimer=0,
  --the sprite is 3x5, so the
  --wr and hr dimensions are
  --radii, and x/y is the
  --initial center position
  wr=1,
  hr=2,
  w=3,
  h=5,

  hit_jump=false,

  --instantaneous jump velocity
  --the "power" of the jump
  jumpv=1.5,

  --movement states
  standing=false,
  wallsliding=false,

  disable_input=false,

  --what direction we're facing
  --1 or -1, used when we're
  --facing away from a wall
  --while sliding
  facing=1,

  --bomb input state
  throw_bomb=false,
  is_bombing=false,

  --timers used for animation
  --states and particle fx
  falltimer=7,
  landtimer=0,
  runtimer=0,
  headanimtimer=0,
  throwtimer=0,

  -- jump buffer timing
  jump_buffer=8,
  jump_buffer_timer=9,

  dead=false,
  dying=false,
  dying_timer=0,

  spr=64,
  map_collide=true,
}

-- player sprite numbers------
--64 standing
--65 running 1
--66 running 2
--67 crouching (post landing)
--80 jumping
--81 falling
--96 sliding 1
--97 sliding 2
--98 sliding 3 / hanging
--99 sliding 4

player.colls={}
function player:draw()
  if self.dead then return end
  self.headanimtimer=self.headanimtimer%3+1

  --if throwing, draw swoosh
  if self.throwtimer>0 then
    local xoff=-4
    if self.flipx then
      xoff=-2
    end

    sspr(
      32,32,7,6,
      self.x+xoff,
      self.y-5,
      7,6,
      self.flipx
      )
    self.throwtimer-=1
  end

  if self.standing then
    if self.landtimer>0 then
      -- if just landed, show crouch
      self.spr=67
    else
      -- if running, show
      -- alternating frames of
      -- the running anim
      self.spr=64+self.runtimer%3
    end
  elseif self.wallsliding	then
    self.spr=96+flr(self.runtimer%4)
  else
    if self.vy<0 then
      self.spr=80 -- jumping up
    else
      self.spr=81 -- falling down
    end
  end

  -- draw the player sprite
  spr(
    self.spr,
    self.x-self.wr, -- x pos
    self.y-self.hr, -- y pos
    .375,           -- width .375*8=3px
    .625,           -- height.625*8=5px
    self.flipx      -- flip x
  )
end

function player:update()
  if self.dead then
    player.dying_timer-=1
    if self.dying_timer<=0 then reset_level() end
    return false
  end

  self.standing=self.falltimer<7
  if not self.disable_input then
    self:handle_input()
  end

  -- apply drag
  -- each frame reduce our vx 2%
  -- so we don't move too fast
  self.vx*=.98

  self.falltimer+=1
  self:move()
  self:check_sliding()
  self:jump()
  self:effects()

  -- set current player cell
  self.cx,self.cy=flr(self.x/8),flr(self.y/8)
end

function player:m_collide_callback(collision)
  if collision.axis=='x' then
    self.vx=0
  elseif collision.axis=='y' then
    self.vy=0

    --set landing velocity
    --for landing effects
    if self.vy > 1 then
      self.landing_v=self.vy
    end

    --reset falling timer if
    --collision dir is down
    if collision.distance>0 then
      self.falltimer=0
      self.standing=true
      if is_crumbler(collision.tile) then
        crumble(collision.cx,collision.cy)
      end
    end
  end
end

function player:check_sliding()
  self.wallsliding=false
  if m_collide(self,'y',1,true) then return end

  --sliding on wall to the right?
  if m_collide(self,'x',1,true) then
    self.wallsliding=true
    self.facing=-1
    self.flipx=false
    if self.vy>0 then self.vy*=.97 end
  --sliding on wall to the left?
  elseif m_collide(self,'x',-1,true) then
    self.wallsliding=true
    self.facing=1
    self.flipx=true
    if self.vy>0 then self.vy*=.97 end
  else
    self.facing=self.flipx and -1 or 1
  end
end

function player:handle_input()
  if self.standing then
    self:ground_input()
  else
    self:air_input()
  end
  self:jump_input()
  if not lvl.bombs_disabled then
    self:bomb_input()
  end

  -- custom debug menu
  if btnp(6) then
    poke(0x5f30,1) -- disables builtin pause menu
    current_game_mode=game_mode.debug_menu
  end
end

function player:jump_input()
  local jump_pressed=btn(4)
  if jump_pressed and not self.is_jumping then
    self.jump_buffer_timer=0
  end
  self.jump_buffer_timer+=1
  self.is_jumping = jump_pressed
end --player.jump_input

function player:bomb_input()
  local bomb_pressed=btn(5)

  if not bomb_pressed then
    self.is_bombing=false
  end

  if not self.is_bombing and bomb_pressed then
    local bomb_vy=-1.5
    local bomb_vx=self.facing *
                  rnd(.4) +
                  self.vx * 1.2
    sfx(11)
    self.is_bombing=true
    self.throwtimer=7
    bomb_class:new({
      x=self.x,
      y=self.y-1,
      vy=bomb_vy,
      vx=bomb_vx
    })
  end
end -- player.bomb_input

function player:jump()
  if self.jump_buffer_timer > self.jump_buffer then return end

  if self.standing then
    self.jump_buffer_timer = self.jump_buffer
    self.vy=min(self.vy,-self.jumpv)
    sfx(9)
  -- allow walljump if sliding
  elseif self.wallsliding then
    self.jump_buffer_timer = self.jump_buffer
    --use normal jump speed,
    --but proportionate to how
    --fast player is currently
    --sliding down wall
    self.vy-=self.jumpv
    self.vy=mid(self.vy,-self.jumpv/3,-self.jumpv)

    --set x velocity / direction
    --based on wall facing
    --(looking away from wall)
    self.vx=self.facing
    -- immediately kick away one pixel to prevent
    -- a wallsliding collision next frame
    self.x+=self.facing
    self.flipx=(self.facing==-1)

    sfx(10)
  end
end --player:jump

function player:ground_input()
  -- pressing left
  if btn(0) then
    self.flipx=true
    self.facing=-1
    --brake if moving in
    --opposite direction
    if self.vx>0 then self.vx*=.9 end
    self.vx-=.05
    --pressing right
  elseif btn(1) then
    self.flipx=false
    self.facing=1
    if self.vx<0 then self.vx*=.9 end
    self.vx+=.05
    --pressing neither, slow down
    --by our friction amount
  else
    self.vx*=friction
  end
end --player.ground_input

function player:air_input()
  if btn(0) then
    self.vx-=.0375
  elseif btn(1) then
    self.vx+=.0375
  end
end --player.air_input

function player:effects()
  if self.standing then
    self:running_effects()
    self:landing_effects()
  elseif self.wallsliding then
    self:sliding_effects()
  end

  self:head_effects()
end --player.effects

function player:running_effects()
  -- updates the run timer to
  -- inform running animation

  -- if we're slow/still, then
  -- zero out the run timer
  if abs(self.vx)<.03 then
    self.runtimer=0
    -- otherwise if we're moving,
    -- tick the run timer and
    -- spawn running particles
  else
    local oruntimer=self.runtimer
    self.runtimer+=abs(self.vx)*runanimspeed
    if abs(self.vx)>1 and flr(oruntimer)!=flr(self.runtimer) then
      spawnp(
        self.x,     --x pos
        self.y+2,   --y pos
        -self.vx/3, --x vel
        -abs(self.vx)/6,--y vel,
        .5 --jitter
        )
    end
  end

  --update the "landed" timer
  --for crouching animation
  if self.landtimer>0 then
    self.landtimer-=.4
  end
end

function player:landing_effects()
  --only spawn landing effects
  --if we've a landing velocity
  if not self.landing_v then return end

  --play a landing sound
  --based on current y speed
  if self.landing_v>2 then
    sfx(15)
  else
    sfx(14)
  end

  --set the landing timer
  --based on current speed
  self.landtimer=self.landing_v

  --spawn landing particles
  for j=0,self.landing_v*2 do
    spawnp(
      self.x,
      self.y+2,
      self.landing_v/3*(rnd(2)-1),
      -self.landing_v/2*rnd(),
      .3)
  end

  --slight camera shake
  --shakevy+=self.landing_v/6

  --reset landing velocity
  self.landing_v=nil
end

function player:sliding_effects()
  local oruntimer=self.runtimer
  self.runtimer-=self.vy*wallrunanimspeed

  if flr(oruntimer)!=flr(self.runtimer) then
    spawnp(
      self.x-self.facing,
      self.y+1,
      self.facing*abs(self.vy)/4,
      0,
      .2)
  end
end

function player:head_effects()
  if self.etimer%19==0 then
    local ex,evx,edir
    edir=self.prevf and -1 or 1
    spawnp(
      self.prevx,
      self.prevy - self.hr,
      -edir*.3, -- x vel
      -.1, -- y vel
      0, --jitter
      10, -- color
      21 -- duration
      )
    self.prevx=self.x
    self.prevy=self.y
    self.prevf=self.flipx
  end

  self.etimer+=1

  if self.etimer>20 then
    self.etimer=1
  end
end

function player:hit_spike()
  if self.dead then return end
  self.dead=true
  self.dying_timer=30
  for i=1,100 do
    spawnp(
      self.x,self.y+2,
      sgn(self.vx)*(-.5 + rnd(2))*rnd(4), -- vx
      -7.5*rnd(), -- vy
      1, -- jitter
      7, -- color
      22 -- duration
      )
    sfx(42)
  end
  cam:shake(30,2)
end

--collision code----------------
--------------------------------

-- given entity, axis, direction,
-- this returns the coords of
-- which two coords should
-- be checked for collisions
function col_points(entity,axis,direction)
  local x1,x2,y1,y2

  -- x movement and y movement
  -- are calc'd separately. when
  -- this func is called, we only
  -- need to check one axis

  if axis=='x' then
    -- if we have x-velocity, then
    -- return the coords for the
    -- right edge or left edge of
    -- our agent sprite
    x1=entity.x+direction*entity.wr
    y1=entity.y-entity.hr
    x2=x1
    y2=entity.y+entity.hr
  elseif axis=='y' then
    -- if we have y-velocity, then
    -- return the coords for the
    -- top edge or bottom edge of
    -- our p sprite
    x1=entity.x-entity.wr
    y1=entity.y+direction*entity.hr
    y2=y1
    x2=entity.x+entity.wr
  end

  -- x1,y1 now represents the
  -- "near" corner to check
  -- (based on velocity), and
  -- x2,y2 the "far" corner
  return x1,y1,x2,y2
end

-- map collision check
-- check if the given entity (e)
-- collides on the axis (a)
-- within the distance (d)
function m_collide(entity,axis,distance,disable_callbacks)
  -- init hitmover checks
  justhitmover=false
  lasthitmover=nil

  -- get the 2 corners that should be checked
  x1,y1,x2,y2=col_points(entity,axis,sgn(distance))

  -- add our potential movement
  if axis=='x' then
    x1+=distance
    x2+=distance
  else
    y1+=distance
    y2+=distance
  end

  local coll={axis=axis,distance=distance}

  -- query our 2 points to see
  -- what tile types they're in
  local cx1,cy1,cx2,cy2=flr(x1/8),flr(y1/8),flr(x2/8),flr(y2/8)
  local tile1=mget(cx1,cy1)
  local tile2=mget(cx2,cy2)

  if entity.is_player and not lvl.exited and
                      (is_open_exit(tile1) or is_open_exit(tile2)) and
                      x1%8>1 and x1%8<6 and
                      y1%8>1 then
    game_mode.lvl_complete:start()
    return
  end

  if not disable_callbacks and (spike_collide(tile1,x1,y1) or spike_collide(tile2,x2,y2)) then
    entity:hit_spike()
    return
  end

  -- check if either corner will hit a wall
  if is_wall(tile1) then
    coll.tile,coll.cx,coll.cy=tile1,cx1,cy1
  elseif is_wall(tile2) then
    coll.tile,coll.cx,coll.cy=tile2,cx2,cy2
  end

  if coll.tile then
    return coll
  else
    return false
  end
end

crumbling={}
function crumble(cx,cy)
  local index=tostr(cx).."."..tostr(cy)
  if crumbling[index] then return end
  mset(cx,cy,14)
  crumbling[index]=true

  add(coroutines,cocreate(function()
    local timer=30
    -- destroy the block after 30 frames
    while timer>0 do
      timer-=1
      if timer==12 then mset(cx,cy,15) end
      yield()
    end
    mset(cx,cy,0)

    -- respawn the block after 120 frames
    timer=120
    while timer>0 do
      -- prevent block from respawning on top of player
      if player.cx==cx and player.cy==cy then yield() end
      timer-=1
      if timer==12 then mset(cx,cy,15) end
      if timer==6  then mset(cx,cy,14) end
      yield()
    end
    mset(cx,cy,13)
    crumbling[index]=false
  end))
end

--special coll logic for spikes
--their hitbox is 4 pixels tall
spike_hitboxes={
  --48 up mini spike
  {1,4,7,8},
  --49 left mini spike
  {4,1,8,7},
  --50 right mini spike
  {0,1,4,7},
  --51 down mini spike,
  {1,0,7,4},
  --52 up big spike
  {1,1,7,8},
  --53 right big spike
  {1,1,8,7},
  --54 left big spike
  {0,1,7,7},
  --55 down big spike
  {1,0,7,7}
}
function spike_collide(tile,x,y)
  if not is_spike(tile) then return end
  local xpos,ypos,hb=x%8,y%8,spike_hitboxes[tile-47]
  return xpos>hb[1] and xpos<hb[3] and ypos>hb[2] and ypos< hb[4]
end

-- entity collisions
function e_collide(obj, other)
  if
    -- other right edge is past obj left edge
    other.x+other.wr*other.scale > obj.x-obj.wr*obj.scale and
    -- other bottom edge is past obj to edge
    other.y+other.hr*other.scale > obj.y-obj.hr*obj.scale and
    -- other left edge is before obj right edge
    other.x-other.wr*other.scale < obj.x+obj.wr*obj.scale and
    -- other top edge is before obj bottom edge
    other.y-other.hr*other.scale < obj.y+obj.hr*obj.scale
    then
    return true
  end
end

-- sprite flags:
-- 0: collidable wall
-- 1: plantable
-- 2: open exit
-- 3: is exit (open or closed)
-- 4: is spike
-- 5: is flowerheart

function is_wall(tile)
  return fget(tile,0)
end

function is_spike(tile)
  return fget(tile,4)
end

function is_exit(tile)
  return fget(tile,3)
end

function is_open_exit(tile)
  return fget(tile,2)
end

function is_flowerheart(tile)
  return fget(tile,5)
end

function is_crumbler(tile)
  return fget(tile,6)
end

--tile plantable if flag 1 set
--and the tile above it
--is not a wall, exit or spike
function is_plantable(cx,cy)
  local tile=mget(cx,cy)
  local above_tile=mget(cx,cy-1)
  return fget(tile,1) and
   not is_wall(above_tile) and
   not is_spike(above_tile) and
   not is_exit(above_tile)
end

--particle spawning-------------
--------------------------------
function spawnp(x,y,vx,vy,jitter,c,d)
  --object for the particle
  local s={
    x=x,
    y=y,
    ox=x,
    oy=y,
    vx=2*(vx+rnd(jitter*2)-jitter),
    vy=2*(vy+rnd(jitter*2)-jitter),
    c=c or 5,
    d=d or 15
  }
  s.duration=s.d+rnd(s.d)
  s.life=1

  add(particles.list,s)
end

--particles holds all particles
--to be drawn in our object loop
particles={list={}}
function particles:update()
  for _,p in pairs(self.list) do
    -- save original x/y
    p.ox=p.x
    p.oy=p.y
    -- apply velocity
    p.x+=p.vx
    p.y+=p.vy
    -- velocity diminishes
    p.vx*=.85
    p.vy*=.85

    p.life-=1/p.duration

    if p.life<0 then
      del(self.list,p)
    end

    -- kill if touching map
    if current_game_mode.is_game and is_wall(mget(p.x/8,p.y/8)) then
      del(self.list,p)
    end
  end
end

function particles:draw()
  for _,p in pairs(self.list) do
    line(
      p.x,p.y,
      p.ox,p.oy,
      p.c+(p.life/2)*3
    )
  end
end

--grass objects-----------------
--------------------------------
grasses={
  map={},
  tiles={},
  anim={timer=0,frames=4,speed=.066666667}
}

function grasses:draw()
  self.anim.timer=(self.anim.timer+self.anim.speed)%self.anim.frames

  local spr_x,spr_y
  for grass_row,grasses in pairs(self.map) do
    for grass_col,grass_value in pairs(grasses) do
      spr_x=3*flr(self.anim.timer)
      spr_y=8+2*grass_value
      sspr(
        spr_x,spr_y,  -- sprite coords
        3,2,          -- width, height
        grass_col-1,grass_row -- screen coords
        )
    end
  end
end

function grasses.plant(x,y)
  local x,cx=flr(x),flr(x/8)
  local y,cy=flr(y),flr(y/8)

  -- start a new grass map row if necessary
  grasses.map[y]=grasses.map[y] or {}

  -- return if grass already at x
  if grasses.map[y][x] then return end

  -- return if the tile below is not plantable
  if not is_plantable(cx,cy+1) then return end

  -- insert one of four possible flower types
  grasses.map[y][x]=flr(rnd(4))
  grasses.update_tile(cx,cy+1)
end

-- updates the count of grasses planted within a tile
-- if the tile is fully planted, mark it as such and
-- increase the current level's planted count
function grasses.update_tile(cx,cy)
  -- initialize the grass tile if necessary
  grasses.tiles[cy]=grasses.tiles[cy] or {}
  grasses.tiles[cy][cx]=grasses.tiles[cy][cx] or 0

  -- return if this tile is already fully planted
  if grasses.tiles[cy][cx]==8 then return end

  grasses.tiles[cy][cx]+=1

  -- if a tile has at least 6 (out of 8) grasses planted,
  -- mark it as fully planted
  if grasses.tiles[cy][cx]>=4 then
    grasses.tiles[cy][cx]=8
    lvl.planted+=1

    -- draw the tile differently now that it is planted
    -- the sprite sheet is arbitrarily set up so that
    -- the planted version of a tile is 9 sprites
    -- to the right
    ot=mget(cx,cy)
    mset(cx,cy,ot+9)
    add(lvl.changed_tiles,{cx,cy,ot})

    -- spawn a bee if necessary
    if toggles.max_beez or lvl.bee_index[lvl.planted] then
      bees:spawn(cx,cy)
      -- flag that the bee has been spawned
      lvl.bee_index[lvl.planted]=false
    end

    -- open the door if possible
    if not lvl.door_open and not lvl.exited and lvl.planted>=lvl.plantable then
      lvl:open_door()
    end
  end
end

--flower bombs------------------
--------------------------------
bomb_class={
  name="bomb",
  is_bomb=true,
  w=3,h=3,
  wr=1,hr=1,
  vy=-2.5,
  spr_x=16,spr_y=8,
  anim={timer=0,frames=8,speed=.166666667}
}
setmetatable(bomb_class,{__index=entity_class})

function bomb_class:new(obj)
  return setmetatable(entity_class:new(obj or {}), {__index=bomb_class})
end

function bomb_class:update()
  self:move()
end

function bomb_class:m_collide_callback(collision)
  -- when a bomb x-collides with wall, bounce back
  if collision.axis=='x' then
    self.vx=-self.vx/4
  elseif collision.axis=='y' then
    -- only explode when a bomb is moving downward
    if self.vy>0 then
      -- dud if the tile is not plantable
      if not is_plantable(collision.cx,collision.cy) then
        self:dud()
      else
        self:explode()
      end
    else
      -- if we collided moving upward, we hit the roof then fall back down
      self.vy=0
    end
  end
end

function bomb_class:e_collide_callback(entity)
end

function bomb_class:hit_spike()
  self:dud()
end

function bomb_class:dud()
  explosions.add(self.x,self.y+2,2)
  sfx(43)
  self:die()
end

function bomb_class:explode()
  explosions.add(self.x,self.y,4)
  -- plant 9 bombs around the explosion point
  for i=self.x+5,self.x-5,-1 do
    grasses.plant(i,self.y)
  end
  laff(self.x,self.y)
  sfx(40)
  sfx(41)
  cam:shake(6,1)
  self:die()
end

laffs={"woo","haa","hoo","hee","hii","yaa"}
function laff(x,y)
  local laff={
    x=x,
    y=y,
    text=laffs[1+flr(rnd(6))],
    col=3+8*flr(rnd(2)),
  }
  deferred_animate(laff,{
    props={x=x,y=y-10},
    duration=60,
    draw=function()
      print(
        laff.text,
        laff.x+cos(time()),
        laff.y,
        laff.col
      )
    end
  })
end

explosions={}
explosions.list={}

function explosions.update()
  for _,e in pairs(explosions.list) do
    if #e.sparks==0 then
      del(explosions.list,e)
    end

    for _,s in pairs(e.sparks) do
      s.x+=s.vx / s.mass
      s.y+=s.vy / s.mass
      s.r-=.2
      if s.r<.5 then
        del(e.sparks,s)
      end
    end -- for s in e.sparks
  end -- for e in all explosions
end -- explosions.update()

function explosions.draw()
  for _,e in pairs(explosions.list) do
    for _,s in pairs(e.sparks) do
      local color
      if s.r>2.5 then
        color=11
      elseif s.r>2 then
        color=3
      else
        color=13
      end
      circfill(s.x,s.y,s.r,color)
    end
  end --for _,e in pairs(explosions.list)
end

function explosions.add(x,y,intensity,color)
  local e={}
  e.x=x
  e.y=y
  e.sparks={}
  for i=1,50 do
    local spark={}
    spark.mass=.5+rnd(2)
    spark.r=.25+rnd(intensity)
    spark.vx=(-1+rnd(2))*.5
    spark.vy=(-1+rnd(2))*.5
    spark.x=e.x+spark.vx
    spark.y=e.y+spark.vy
    add(e.sparks,spark)
  end
  add(explosions.list,e)
end


--intro object------------------
--------------------------------

function game_mode.intro:init()
  self.a=0
  self.r=2
  self.title="flowerhead"
  self.subtitle="by charlie tran"
  self.prompt="press x to start"
  self.animtimer=0
  self.animlength=8
  music(63)
end

function game_mode.intro:update()
  if btnp(5) then
    current_game_mode=game_mode.game
    reset_level()
    music(0,0,1)
  end

  particles:update()

  -- spawn speed streaks
  if self.animtimer%2==0 then
    spawnp(
      32+rnd(96),
      32+rnd(96),
      -5, -- x vel
      -5, -- y vel
      .1, -- jitter
      5  -- color
    )
  end
end

function game_mode.intro:draw()
  cls()
  clouds:draw()
  particles:draw()

  self.animtimer+=.25
  if self.animtimer>self.animlength then
    self.animtimer=1
  end

  for i=1,#self.title do
    y=sin(i/16+time()/8)*4
    print(
      sub(self.title,i,i),
      66 - #self.title*4  + ((i-1)*8),
      50+y,
      3)
    if i==5 then sy=50+y-5 end
  end

  spr(64,58,sy)

  if self.animtimer%3==0 then
    spawnp(
      57,
      sy,
      -.7, -- x vel
      -.2, -- y vel
      0, --jitter
      10, -- color
      21 -- duration
      )
  end
    print(
      self.subtitle,
      64-#self.subtitle*2,
      70,
      13
      )
  if self.animtimer < 6 then
    print(
      self.prompt,
      64-#self.prompt*2,
      88,
      7
      )
  end
end

--camera------------------------
--------------------------------
cam={}
-- x/y represent the current
-- offset of the camera. offset
-- of 0,0 means the camera will
-- originate (top left corner)
-- be at top left of the screen
function cam:init()
  self.x=0
  self.y=0

  self.shake_remaining=0
  self.shake_force=0

  self.thresh_x=24
  self.thresh_y=24

  self.fadeout=0
end

--update the game camera to
--track the player within our
--specified threshold
function cam:update()
  self.shake_remaining=max(0,self.shake_remaining-1)

  -- if the camera is too far to
  -- the left of the player, then
  -- shift the camera towards the
  -- player, at most 4 pixels
  if (self.x+self.thresh_x)<player.x then
    self.x+=min(player.x-(self.x+self.thresh_x),4)
  end
  -- and if too far right, then
  -- shift camera to the left
  if (self.x-self.thresh_x)>player.x then
    self.x-=min((self.x-self.thresh_x)-player.x,4)
  end
  -- same if cam is too far above
  -- player, shift it downwards
  -- (positive y means downward)
  if (self.y+self.thresh_y)<player.y then
    self.y+=min(player.y-(self.y+self.thresh_y),4)
  end
  -- and lastly, if too far
  -- below player, shift it up
  if (self.y-self.thresh_y)>player.y then
    self.y-=min((self.y-self.thresh_y)-player.y,4)
  end

  -- clamp the camera offset to
  -- be within the bounds of our
  -- current.level
  self.x=mid(self.x,lvl.sx1+64,lvl.sx2-64)
  self.y=mid(self.y,lvl.sy1+64,lvl.sy2-64)
end

-- returns coordinates to be
-- used by pico8 camera() func
function cam:position()
  local shake={x=0,y=0}
  if self.shake_remaining>0 then
    shake.x=rnd(self.shake_force)-self.shake_force/2
    shake.y=rnd(self.shake_force)-self.shake_force/2
  end
  return self.x-64+shake.x,self.y-64+shake.y
end

function cam:shake(ticks, force)
  self.shake_remaining=ticks
  self.shake_force=force
end

function cam:draw()
  camera(cam:position())
end

function cam:fade()
  if self.fadeout>0 then
    for i=0,15 do
      pal(i,i*(1-self.fadeout),1)
    end
    self.fadeout-=.1
  else
    pal()
  end
end

--the bees----------------------
--------------------------------
bee_class={
  name="bee",
  anim={timer=0,frames=3,speed=.25},
  spr_x=64,spr_y=8,
  is_bee=true,
  has_gravity=false,
  vx_turning=.05,
  vy_turning=.1,
  w=7,h=7,wr=3,hr=3,
  flipx=false,
  update_counter=0,
  update_interval=15,
  max_vx=.5,
  max_vy=.5,
  path={}
}
setmetatable(bee_class,{__index=entity_class})

-- make the bee bounce off spikes
function bee_class:hit_spike()
  self.vy=-self.vy
end

function bee_class:new(obj)
  local bee=obj or {}
  bee.pathfinder=pathfinder_class:new(bee)
  return setmetatable(bee, {__index=bee_class})
end

function bee_class:jitter()
  local offset=sin(time())*.15
  self.vy=mid(self.vy+offset,-self.max_vy,self.max_vy)
end

function bee_class:update()
  self.update_counter+=1
  if self.update_counter == self.update_interval then
    self.update_counter=0
    self.pathfinder:update(player)
  end

  self:set_target()
  self:steer()
  self:jitter()
  self:move()
end

function bee_class:draw()
  --if toggles.path_vis then self:draw_paths() end
  entity_class.draw(self)
end

function bee_class:set_target()
  if self.pathfinder.enabled then
    self.target_x,self.target_y=self.pathfinder:next_target()
  end
end

-- adjust bee velocity to move towards target
function bee_class:steer()
  if not self.target_x then return end

  if self.target_x<self.x then
    self.vx=max(self.vx-self.vx_turning,-self.max_vx*1/self.scale)
  else
    self.vx=min(self.vx+self.vx_turning,self.max_vx*1/self.scale)
  end
  self.flipx=self.vx<0

  if self.target_y<self.y then
    self.vy=max(self.vy-self.vy_turning,-self.max_vy*1/self.scale)
  else
    self.vy=min(self.vy+self.vy_turning,self.max_vy*1/self.scale)
  end
end

function bee_class:e_collide_callback(entity)
  -- don't collide with ents while spawning
  if self.spawning then return end

  -- kill the player if touching, then recall bees to the door
  if entity.is_player then
    player:hit_spike()
  --if hit by a bomb, grow 20%,
  --exploding at 200% scale
  elseif entity.is_bomb then
    entity:dud()
    self.scale+=.2
    if self.scale >= 2 then
      self:die()
    end
  end
end

function bee_class:die()
  poof(self.x,self.y,9)
  entity_class.die(self)
  sfx(42)
  bees.count-=1
  if bees.count==0 then sfx(-1,3) end
end

-- debugging visualization to draw the pathfinding
-- for each bee
--function bee_class:draw_paths()
  --local pf=self.pathfinder
  --for cell in all(pf.visited) do
    --local px,py=cell[1][1]*8,cell[1][2]*8
    --fillp(0b0000111100001111)
    --rectfill(px,py, px+7,py+7,3)
    --fillp()https://arstechnica.com/gaming/2019/01/kingdom-mixes-zombie-outbreak-with-political-intrigue-in-winning-combo/
    --print(cell[2],px,py+2,11)
  --end

  --if pf.next_cell then
    --rectfill(
      --pf.next_cell[1]*8,pf.next_cell[2]*8,
      --pf.next_cell[1]*8+7,pf.next_cell[2]*8+7,
      --7)
  --end

  --local points={}
  --for cell in all(pf.path) do
    --add(points,{cell[1]*8+4,cell[2]*8+4})
  --end

  --for i=2,#points do
    --local x1=points[i-1][1]
    --local y1=points[i-1][2]
    --local x2=points[i][1]
    --local y2=points[i][2]
    --line(x1,y1,x2,y2,8)
  --end
--end

bees={
  -- how many frames to delay after spawning for
  -- bees to start pathfinding the player
  count=0,
}

function bees:spawn(cx,cy)
  -- the bee randomly flies in from left or right
  local dir=sgn(-1+rnd(2))
  local bee=bee_class:new({
      flipx=-dir,
      -- spawn the bee centered above the passed-in cell coordinate
      x=cx*8+bee_class.wr+dir*32,
      y=cy*8-32,
      -- bee starts big then zooms down to normal size
      scale=8,
      spawning=true,
      target_x=cx*8+bee_class.wr+1,
      target_y=cy*8-8+bee_class.hr,
  })

  bee.pathfinder.enabled=false

  add(coroutines,coroutine_sequence({
    -- make a spawn effect centered above the tile
    bees:make_spawn_effect(cx*8+4,cy*8-1, (-1+rnd(2))*.5,-1, 60),
    -- add our new bee to the bee list
    function()
      insert(entities,bee)
      bees.count=bees.count+1
    end,
    -- animate the bee zooming from its initial big size down to normal
    function() sfx(16,3) end,
    make_animation(bee,{props={x=cx*8+bee.wr+1,y=cy*8-8+bee.hr,scale=1},hold=60,duration=60}),
    function()
    	bee.pathfinder.enabled=true
    	bee.spawning=false
    end
  },true))
end

-- return a function that draws a "fountain" particle
-- effect that indicates a bee will spawnt here
function bees:make_spawn_effect(x,y,vx,vy,duration)
  return function()
    for i=1,duration do
      if player.dead then return end
      spawnp(x,y,vx,vy,.25,10)
      yield()
    end
  end
end

function game_mode.outro:update()
  if btnp(4) then _init() end
  particles:update()
  self.animtimer+=1
  if self.animtimer%2==0 then
    spawnp(
      32+rnd(96),
      32+rnd(96),
      -3, -- x vel
      -3, -- y vel
      .1, -- jitter
      10  -- color
      )
  end
end

function game_mode.outro:draw()
  cls()
  music(-1,50)
  camera(0,0)
  particles:draw()
  local lines = {
    "you planted all the flowers!!",
    "your time: "..(flr(gametime/60)).." seconds",
    "press z to restart"
  }

  for i,line in pairs(lines) do
    local x = 64-#line*2
    local y = 45 + i*8
    print(line,x,y,7)
  end
end

-- pathfinder class
pathfinder_class={
  enabled=true,
  depth_limit=20 -- search depth limit
}

function pathfinder_class:new(agent)
  return setmetatable({agent=agent,path={}}, {__index=pathfinder_class})
end

function pathfinder_class:update(target_entity)
  if not self.enabled then return end
  if target_entity.dead then return end
  -- get the cell coordinate of the target
  self.goal_cell=pos_to_cell(target_entity.x+target_entity.wr,target_entity.y+target_entity.hr)
  self.goal_index=cell_to_index(self.goal_cell)

  -- set frontier to start with bee's current map position
  local start_cell=pos_to_cell(self.agent.x,self.agent.y)
  local start_index=cell_to_index(start_cell)

  self.frontier={{cell=start_cell,index=start_index}}
  self.came_from={}
  self.came_from[start_index]=start_cell
  self.cost_so_far={}
  self.cost_so_far[start_index]=0

  self.visited={}

  self.search_bound=manhattan_distance(start_cell,self.goal_cell)

  local path_cell = self:search_frontier()
  if not path_cell then return end
  self.path={path_cell,self.goal_cell}
  local path_index=cell_to_index(path_cell)

  while path_index != start_index do
    insert(self.path, path_cell)
    path_cell = self.came_from[path_index].cell
    path_index = self.came_from[path_index].index
  end
end

function pathfinder_class:search_frontier()
  local search_depth=0
  while #self.frontier>0 do
    -- grab the first item in priority queue (frontier)
    local current=pop_end(self.frontier)
    -- stop searching once goal is found
    if current.index==self.goal_index then
      return current.cell
    end

    -- get the neighboring cells of current search cell
    local neighbor_cells=self.get_neighbor_cells(current.cell)
    self:expand_frontier(neighbor_cells,current,search_depth)
    search_depth+=1
  end -- while #frontier>0
end


function pathfinder_class.get_neighbor_cells(cell)
  local neighbors={}
  local x,y=cell[1],cell[2]

  local possible_neighbors={
    {x-1,y-1},
    {x,y-1},
    {x+1,y-1},
    {x-1,y},
    {x+1,y},
    {x-1,y+1},
    {x,y+1},
    {x+1,y+1}
  }

  for _,pn in pairs(possible_neighbors) do
    local admissible=pn[1]>lvl.cx1 and pn[1]<lvl.cx2 and
    pn[2]>lvl.cy1 and pn[2]<lvl.cy2 and
    not lvl.obstacles[pn[2]][pn[1]]
    if admissible then add(neighbors,pn) end
  end

  if (cell[1] + cell[2])%2 == 0 then
    reverse_table(neighbors)
  end

  return neighbors
end

function pathfinder_class:expand_frontier(neighbor_cells,current,search_depth)
  for neighbor_cell in all(neighbor_cells) do
    local neighbor_index=cell_to_index(neighbor_cell)
    local new_cost=self.cost_so_far[current.index]+1

    -- a* epsilon weighting
    local e=.6
    local weight=1
    --if search_depth <= self.search_bound then
      --weight=1+e*(1-search_depth/self.search_bound)
    --end

    if (not self.cost_so_far[neighbor_index]) or (new_cost < self.cost_so_far[neighbor_index]) then
      add(self.visited,{neighbor_cell,new_cost})
      self.cost_so_far[neighbor_index]=new_cost
      if toggles.a_star then
        insert_sorted(self.frontier,{
            cell=neighbor_cell,
            index=neighbor_index,
            priority=new_cost+weight*manhattan_distance(neighbor_cell,self.goal_cell)
          })
      else
        insert(self.frontier,{cell=neighbor_cell,index=neighbor_index})
      end
      self.came_from[neighbor_index]=current
    end
  end
end

function pathfinder_class:next_target()
  local next_cell = self.path[1]
  if not next_cell then return end
  if self.agent.cx == next_cell[1] and self.agent.cy == next_cell[2] then
    del(self.path,next_cell)
    next_cell = self.path[1]
    if not next_cell then return end
  end
  return next_cell[1]*8+4,next_cell[2]*8+4
end

-- utility functions
--------------------------------
function truncate(tbl)
  for o in all(tbl) do
    del(tbl,o)
  end
end

function manhattan_distance(start, target)
  local m = abs(start[1]-target[1]) + abs(start[2]-target[2])
  local c = max( abs(start[1]-target[1]) , abs(start[2]-target[2]) )
  return (m+c)/2
end
-- converts x/y coordinate to map cell coords
function pos_to_cell(x,y)
  return {
    flr(x/8),
    flr(y/8)
  }
end

function pop_end(tbl)
  local top = tbl[#tbl]
  del(tbl,tbl[#tbl])
  return top
end

-- draw a box object (has x,y,w,h,color)
function draw_box(box)
  rectfill(
    box.x,box.y,
    box.x+box.w,box.y+box.h,
    box.color)
end

function reverse_table(tbl)
  for i=1,(#tbl/2) do
    local temp = tbl[i]
    local oppindex = #tbl-(i-1)
    tbl[i] = tbl[oppindex]
    tbl[oppindex] = temp
  end
end

-- converts x/y coordinates to a unique index
function cell_to_index(cell)
  return (cell[1]+1)*128+cell[2]
end

-- converts a map index back to x/y coords
function index_to_cell(index)
  local y=index%128
  local x=((index-y)/128)-1

  return {x,y}
end

-- inserts a value at beginning of table,
-- assuming table index starts at 1
function insert(tbl,val)
  for i=#tbl,1,-1 do
    tbl[i+1]=tbl[i]
  end
  tbl[1]=val
  return val
end

-- insert a value into a priority sorted table
-- assumes the new entry and all prioer entries
-- has a "priority" key
function insert_sorted(tbl,new_entry)
  if #tbl==0 then
    add(tbl,new_entry)
    return
  end

  add(tbl,{})
  for i=#tbl,2,-1 do
    local next=tbl[i-1]
    if new_entry.priority < next.priority then
      tbl[i]=new_entry
      return
    else
      tbl[i]=next
    end
  end
  tbl[1]=new_entry
end

function draw_debug()
  rectfill(cam.x-63,cam.y+56,cam.x+63,cam.y+62,1)
  print(
    "mem: "..(flr(stat(0)/2048*100)).."% "..
    "cpu: "..flr(stat(1)*100).."% "..
    "fps: "..stat(7),
    cam.x-62,cam.y+57,7)
end
-- animation functions

-- wrapper for resuming w/ error
function cowrap(cor,...)
  local ok,err=coresume(cor,...)
  -- if the coroutine throws an error,
  -- halt the program and show it
  assert(ok, err)
end

function deferred_animate(obj,params)
  add(coroutines,
    cocreate(make_animation(obj,params))
  )
end

-- create an animation function to be
-- used in a coroutine
-- params: {x, y, duration, easing}
function make_animation(obj,params)
  return function()
    local duration=params.duration
    local hold=params.hold or 0
    local easing=params.easing or ease_out_quad
    local percent=0

    local anims={}
    for property,value in pairs(params.props) do
      anims[property]={
        orig=obj[property],
        target=value,
        delta=value-obj[property]
      }
    end

    if params.draw then add(deferred_draws,params.draw) end

    for frames=1,duration do
      percent=easing(frames/duration)
      for property,anim in pairs(anims) do
        obj[property]=anim.orig+percent*anim.delta
      end
      yield()
    end

    for property,anim in pairs(anims) do
      obj[property]=anim.target
    end

    while hold>0 do
      hold-=1
      yield()
    end

    if params.draw then del(deferred_draws,params.draw) end
  end
end

function make_delay(dur)
  return function() for i=1,dur do yield() end end
end

function coroutine_sequence(fns,stop_if_player_dead)
  return cocreate(function()
    for _,fn in pairs(fns) do
      if stop_if_player_dead and player.dead then return end
      fn()
    end
  end)
end

-- easing function, meant to be
-- used with a num ranging 0-1
-- from: https://gist.github.com/gre/1650294
function ease_out_quad(t)
  return t*(2-t)
end

function ease_in_quad(t)
  return t*t
end

function linear(t)
  return t
end

-- debug menu
-------------
game_mode.debug_menu.sel=1
game_mode.debug_menu.items={}

toggles={
  a_star=true,
  max_beez=false,
}

function game_mode.debug_menu:update()
  if btnp(2) then
    self.sel=self.sel==1 and #self.items or self.sel-1
  end
  if btnp(3) then
    self.sel=self.sel==#self.items and 1 or self.sel+1
  end
  self.sel=mid(self.sel,1,#self.items)
  if btnp(4) then self.items[self.sel][2]() end
  if btnp(6) then
    poke(0x5f30,1)
    current_game_mode=game_mode.game
  end

  self.items={}
  add(self.items,{
      "skip to next level", function() levels:goto_next() end
    })
  add(self.items,{
      "reset game", function() run() end
    })

  self:make_toggle"performance"
  --self:make_toggle"path_vis"
  self:make_toggle"a_star"
  self:make_toggle"max_beez"

  --add(self.items,{
      --"spawn bee", function()
        --insert(entities, bee_class:new({x=lvl.sx1+12,y=lvl.sy1+12}))
      --end
    --})

  --add(self.items,{
      --"open current door", function() lvl:open_door() end
    --})
end

function game_mode.debug_menu:draw()
  cls()
  camera(0,0)
  print("--- debugging ---",10,2,15)
  print("press enter to exit",10,10,15)
  cursor(10,10)
  for index,item in pairs(self.items) do
    local y_off=24+(index-1)*8
    if index==self.sel then
      rectfill(8,y_off-1,10+#item[1]*4+5,y_off+5,15)
      print(item[1],13,y_off,0)
    else
      print(item[1],10,y_off,15)
    end
  end
end

function game_mode.debug_menu:make_toggle(name)
  add(self.items,{
      name..": "..(toggles[name] and "enabled" or "disabled"),
      function() toggles[name] = not toggles[name] end
    })
end

__gfx__
00000000d55555550000d66dd666666dd66d000000000000d66d00000000d66d000000000000000033333333323223333333333376d766d676d766d6666d666d
000000006576666600006dd56dddddd56dd50000000000006dd5000000006dd500000000000000003333333333332323333333336ddddddd6ddddddd76d76666
00700700d166666600006dd56dddddd56dd50000000000006dd5000000006dd50000000000000000333b3333316363363dd3d333dd7d65d5dd0d65d0d70d776d
00077000d56ddddd00006dd5d55555516dd5000000000000d55100000000d55100000000000000003333333bd56dd3dd355355317dddddd50dd0ddd5ddd00dd0
000770005155151100006dd5000000006dd50000d666666d00000000000000000000d66dd66d00003b33353351551511300300306d65d6dd6d6006dd50500d05
00700700666d576600006dd5000000006dd500006dddddd5000000000000000000006dd56dd50000336d3736666d576600030000ddddd5d5dddd05d00dd5055d
00000000666d566600006dd5000000006dd500006dddddd5000000000000000000006dd56dd50000366d5666666d5666000000006dddddd50dddddd000500050
00000000dddd56dd0000d55100000000d5510000d555555100000000000000000000d551d5510000dddd56dddddd56dd00000000555d5d55000d5d000000d000
0c0c000c000c000000b000000000000000b000b03232233300000000000000000770004000000000000000000000000000000000000000000000000000000000
0b00b00b00b0000004004b040040040b400400403333232300000000000000007667040000004400000440000000000000000000000000000000000000000000
070700070007000000000000b0b0b000000000003dd3dd35000000000000000007667a007777a000a66a00000000000000000000000000000000000000000000
0300300300300000000000000000000000000000d5535551000000000000000005a5a8a6666a8a056678a0000000000000000000000000000000000000000000
0808000800080000000000000000000000000000000000000000000000000000a5a5aaaa5a5aaaa777aaa0000000000000000000000000000000000000000000
0b00b00b00b0000000000000000000000000000000000000000000000000000005a5aa005a5aa005a5aa00000000000000000000000000000000000000000000
0a0a000a000a00000000000000000000000000000000000000000000000000004040400040404004040400000000000000000000000000000000000000000000
03003003003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c5c50000c5c50000c5c50000c5c50000c5c50000cccc0000cccc0000cccc0000cccc0000cccc0000000000000000000c0c000c000000000000000000000000
05c5a5a005c5a5a005c5a5a005c5a5a005c5a5a00cccaaa00cccaaa00cccaaa00cccaaa00cccaaa000000000000000000b00b0b0000000000000000000000000
c5c5a575c5c575a5c575a5a575c5a5a5c5c5a5a5cccca77cccc77aacc77caaac7cccaaacccccaaa7000000000000000007070007000000000000000000000000
c5c57575c57575a57575a5a575c5a5a5c5c5a575ccc77777c77777ac7777aaac77ccaaaccccca777000000000000000003003030000000000000000000000000
75c56565c56565c56565c57565c575c5c575c56577cc666ccc666ccc666ccc776ccc77cccc77cc66000000000000000008080008000000000000000000000000
7575c5c5c5c5c5c5c5c5c575c5c57575c57575c5777cccccccccccccccccc777ccc7777cc7777ccc00000000000000000b00b0b0000000000000000000000000
65c5c5c5c5c5c5c5c5c5c565c5c565c5c565c5c566cccccccccccccccccccc66cccc66cccc66cccc00000000000000000a0a000a000000000000000000000000
c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5cccccccccccccccccccccccccccccccccccccccc000000000000000003003030000000000000000000000000
000000000000077227000000222222220070000000077722200000002222222200000000000000000000000000000000000000000c00700800a0000000000000
000000000000777227770000772772770770007007777772222277702722222000000000000000000000000000000000000000000b00300b0030000000000000
00000000000000222200000077077070077700700000722222777777772027200000000000000000000000000000000000000000c00700800a00000000000000
000000000000777227700000070700700777007700000022222777007770772000000000000000000000000000000000000000000b00300b0030000000000000
0700707000000772277700000000000002770777007772222200000077007770000000000000000000000000000000000000000000c00700800a000000000000
070770770000002222000000000000000272027777777722222700000700777000000000000000000000000000000000000000000b00300b0030000000000000
77277277000077722777000000000000022222720777222227777770070007700000000000000000000000000000000000000000000000000000000000000000
22222222000000722770000000000000222222220000000222777000000007000000000000000000000000000000000000000000000000000000000000000000
00e0000000e0000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000e00000005550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44400000040000004440000000000000050055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04000000444000000440000044400000000005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
40400000040000004000000040400000000000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00e0000000e0000000e0000000e0000000e0000000e00000000000000b3033000b030000030000003000000300000303000b3033000000000000000000000000
00400000404000000040000040400000004000000040000000000000bfb33330bf333000bf330000b300003fb3003bf330bfb333300000000000000000000000
440000000400000004000000040000000400000044000000000000003fb333303f3330003f330000b300003f330033f3303fb333300000000000000000000000
0440000044000000044000000440000004000000044000000000000033f333300fb330003f3300003300003f330003fb3033f333300000000000000000000000
40000000004000000400000004000000404000000400000000000000033333000333300003300000330000033000033330033333000000000000000000000000
00000000000000000000000000000000000000000000000000000000003330000033000003300000330000033000003300003330000000000000000000000000
00000000000000000000000000000000000000000000000000000000000300000030000003000000300000030000003000000300000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0000000e0000000e0000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
404000004040000040400000404000000000000000000000000000000b3033100313100003100000310000031000031310000000000000000000000000000000
04000000040000000400000004000000000000000000000000000000b6b33330b6333100b6310000b1000036b1003b6331000000000000000000000000000000
0440000004000000040000000400000000000000000000000000000036b333303633310036310000b10000363100336331000000000000000000000000000000
04000000004000000400000000400000000000000000000000000000036b331006b3100036310000310000363100036b10000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000003331000033100003100000310000031000033310000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000310000031000003100000310000031000003100000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000100000011000001100000110000011000001100000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbbbb8bbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb8bbbbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb8bbbbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000002000001000001023000000000000004000008050505050505050505050505050505050505050505050505050505050505090
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000002000001000001023000000000000004000002000000000000000000000000000000000000000000000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000002000001000001010101010101000004000002000000000000000000000000000000000000000000000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000002000001000001033330000000000004000002000000000000000000000000000000000000000000000000010101010000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000002000001000000000000000000000004000002010101000000000000000000000000000000000000000000000000000000040
00000000000000000000000000000000000000000000000000805050505050505050505050505050900000000000000000000000000000000000000000000000
0000000000000000000000000000200000100000d0d0d0000000d0d0d04000002000000000000000000000000000000000000000000000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000002004001043434343434343434343434000002000000000000000000000000000000000000000000000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000007051513030303030303030303030306000002010101010101000001000000000000000000000000000001010101010100040
00000000000000000000000000000000000000000000000000200000000000007500000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000010000000101010100000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000100000100000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000b0000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000101010101040
00000000000000000000000000000000000000000000000000200000000000000000000000003200400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000001010101000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000100000000000000000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000010101000000000000000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000001010101010000000000000000000000000000040
00000000000000000000000000000000000000000000000000200000000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000101010101010100000000000000000000000000040
00000000000000000000000000000000000000000000000000200400000000000000000000000000400000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000003030310101000000000101000000000000000000000000040
00000000000000000000000000000000000000000000000000703030303030303030303030303030600000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000020000000b0b0b01010101000000000000000000000d000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000200000b0100000100000000000000000000000000000000000d0000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002032001000000010000000000000000000000000000000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000020b0b01000000033000000000000000000000000000000000000000000d00040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000020000000000000750000000000000000000000000000000000d0000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000200000000000004300000000000000b00000b00000d000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002004000000000010000000000000001000001000000000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000020b0b0b000000010000000000000001000001000000000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000020000000000000100000b0b0b000001000001000000000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000010000000000000001000001000000000000000000000000040
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020432043434343434310000000000000000000001043034303430343034303430340
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000070307030303030303030515151515151515151513030303030303030303030303060
__label__
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888eeeeee888888888888888888888888888888888888888888888888888888888888888888888888ff8ff8888228822888222822888888822888888228888
8888ee888ee88888888888888888888888888888888888888888888888888888888888888888888888ff888ff888222222888222822888882282888888222888
888eee8e8ee88888e88888888888888888888888888888888888888888888888888888888888888888ff888ff888282282888222888888228882888888288888
888eee8e8ee8888eee8888888888888888888888888888888888888888888888888888888888888888ff888ff888222222888888222888228882888822288888
888eee8e8ee88888e88888888888888888888888888888888888888888888888888888888888888888ff888ff888822228888228222888882282888222288888
888eee888ee888888888888888888888888888888888888888888888888888888888888888888888888ff8ff8888828828888228222888888822888222888888
888eeeeeeee888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd55555d55555555dd55555d5d55555ddd55555ddd55555d5d55555ddd55555ddd55555dd55555555555555555555555555555555555555555
5555555555555d5555555d5555555d5d55555d5d55555d5555555d5d55555d5d55555d5555555d5d55555d5d5555555555555555555555555555555555555555
5ddd5ddd55555dd555555d5555555d5d55555d5d55555dd555555dd555555ddd55555dd555555ddd55555d5d5555555555555555555555555555555555555555
5555555555555d5555555d5555555d5d55555ddd55555d5555555d5d55555d5d55555d5555555d5d55555d5d5555555555555555555555555555555555555555
5555555555555d5555555ddd55555dd555555ddd55555ddd55555d5d55555d5d55555ddd55555d5d55555ddd5555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd5d5d555555dd5d5d5ddd5ddd5d555ddd5ddd55555ddd5ddd5ddd5dd555555555555555555555555555555555555555555555555555555555
5555555555555d5d5d5d55555d555d5d5d5d5d5d5d5555d55d55555555d55d5d5d5d5d5d55555555555555555555555555555555555555555555555555555555
5ddd5ddd55555dd55ddd55555d555ddd5ddd5dd55d5555d55dd5555555d55dd55ddd5d5d55555555555555555555555555555555555555555555555555555555
5555555555555d5d555d55555d555d5d5d5d5d5d5d5555d55d55555555d55d5d5d5d5d5d55555555555555555555555555555555555555555555555555555555
5555555555555ddd5ddd555555dd5d5d5d5d5d5d5ddd5ddd5ddd555555d55d5d5d5d5d5d55555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd55dd5dd555dd5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555d55d5d5d5d5d5d5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5ddd5ddd555555d55d5d5d5d5d5d5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555d55d5d5d5d5d5d5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555d55dd55ddd5dd55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5ddd5ddd555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd5dd555dd5ddd5ddd5d5d55dd5ddd5ddd55dd5dd555dd5555555d55555ddd5d5d5ddd55dd5ddd5ddd5ddd5d55555555555555555555555555
55555555555555d55d5d5d5555d55d5d5d5d5d5555d555d55d5d5d5d5d55555555d5555555d55d5d55d55d5d5d5d55d55d5d5d55555555555555555555555555
5ddd5ddd555555d55d5d5ddd55d55dd55d5d5d5555d555d55d5d5d5d5ddd555555d5555555d55d5d55d55d5d5dd555d55ddd5d55555555555555555555555555
55555555555555d55d5d555d55d55d5d5d5d5d5555d555d55d5d5d5d555d555555d5555555d55d5d55d55d5d5d5d55d55d5d5d55555555555555555555555555
5555555555555ddd5d5d5dd555d55d5d55dd55dd55d55ddd5dd55d5d5dd555555d55555555d555dd55d55dd55d5d5ddd5d5d5ddd555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd5d5d5ddd5ddd5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555d555d5d55d555d55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5ddd5ddd55555dd555d555d555d55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555d555d5d55d555d55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd5d5d5ddd55d55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555d555ddd5d5d5ddd5d5555dd555555555dd55ddd5ddd5ddd55555ddd5ddd55dd55dd5ddd5ddd55dd55dd5ddd55dd5dd555555555555555555555
5555555555555d555d555d5d5d555d555d55555555555d5d55d55d555d5555555d5d5d5d5d5d5d555d5d5d555d555d5555d55d5d5d5d55555555555555555555
5ddd5ddd55555d555dd55d5d5dd55d555ddd555555555d5d55d55dd55dd555555ddd5dd55d5d5d555dd55dd55ddd5ddd55d55d5d5d5d55555555555555555555
5555555555555d555d555ddd5d555d55555d55d555555d5d55d55d555d5555555d555d5d5d5d5d5d5d5d5d55555d555d55d55d5d5d5d55555555555555555555
5555555555555ddd5ddd55d55ddd5ddd5dd55d5555555ddd5ddd5d555d5555555d555d5d5dd55ddd5d5d5ddd5dd55dd55ddd5dd55d5d55555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd55dd5ddd5ddd55555d5d5ddd5d555d5555dd55555ddd55dd5ddd555555dd5d555ddd5ddd5ddd5ddd5dd555dd555555555555555555555555
5555555555555d5d5d5d5ddd5d5d55555d5d5d5d5d555d555d5555555d555d5d5d5d55555d555d5555d55ddd5d5d55d55d5d5d55555555555555555555555555
5ddd5ddd55555dd55d5d5d5d5dd555555d5d5ddd5d555d555ddd55555dd55d5d5dd555555d555d5555d55d5d5dd555d55d5d5d55555555555555555555555555
5555555555555d5d5d5d5d5d5d5d55555ddd5d5d5d555d55555d55555d555d5d5d5d55555d555d5555d55d5d5d5d55d55d5d5d5d555555555555555555555555
5555555555555ddd5dd55d5d5ddd55555ddd5d5d5ddd5ddd5dd555555d555dd55d5d555555dd5ddd5ddd5d5d5ddd5ddd5d5d5ddd555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd5dd55ddd5ddd5ddd5ddd55dd5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555d555d5d5d555ddd55d55d555d555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5ddd5ddd55555dd55d5d5dd55d5d55d55dd55ddd5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555d555d5d5d555d5d55d55d55555d5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555555555555ddd5d5d5ddd5d5d5ddd5ddd5dd55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5eee5e5e5ee555ee5eee5eee55ee5ee5555555555666566556665666557555755555555555555555555555555555555555555555555555555555555555555555
5e555e5e5e5e5e5555e555e55e5e5e5e555555555565565655655565575555575555555555555555555555555555555555555555555555555555555555555555
5ee55e5e5e5e5e5555e555e55e5e5e5e555555555565565655655565575555575555555555555555555555555555555555555555555555555555555555555555
5e555e5e5e5e5e5555e555e55e5e5e5e555555555565565655655565575555575555555555555555555555555555555555555555555555555555555555555555
5e5555ee5e5e55ee55e55eee5ee55e5e555556665666565656665565557555755555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555d5d55dd5d5d55555ddd5ddd5dd55d5d55555ddd5ddd5d5d5ddd5d5555dd55555ddd5ddd5ddd55555ddd5ddd5ddd5ddd5ddd555555555555
55555555555555555d5d5d5d5d5d55555ddd5d5d5d5d5d5d55555d5d55d55d5d5d555d555d5555555d5d5d555d5d55555d555d5d5d5d5ddd5d55555555555555
55555ddd5ddd55555ddd5d5d5d5d55555d5d5ddd5d5d5ddd55555ddd55d555d55dd55d555ddd55555ddd5dd55dd555555dd55dd55ddd5d5d5dd5555555555555
55555555555555555d5d5d5d5ddd55555d5d5d5d5d5d555d55555d5555d55d5d5d555d55555d55555d555d555d5d55555d555d5d5d5d5d5d5d55555555555555
55555555555555555d5d5dd55ddd55555d5d5d5d5d5d5ddd55555d555ddd5d5d5ddd5ddd5dd555555d555ddd5d5d55555d555d5d5d5d5d5d5ddd555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
555555555555555555dd5d5d55dd5d5d5d555dd5555555dd5d5d5ddd55555d5d55555d5d5ddd5d5555dd55dd5ddd5ddd5d5d5555555555555555555555555555
55555555555555555d555d5d5d5d5d5d5d555d5d55555d5d5d5d5d5d55555d5d55555d5d5d555d555d5d5d5555d555d55d5d5555555555555555555555555555
55555ddd5ddd55555ddd5ddd5d5d5d5d5d555d5d55555d5d5d5d5dd555555ddd55555d5d5dd55d555d5d5d5555d555d55ddd5555555555555555555555555555
5555555555555555555d5d5d5d5d5d5d5d555d5d55555d5d5d5d5d5d5555555d55555ddd5d555d555d5d5d5555d555d5555d5555555555555555555555555555
55555555555555555dd55d5d5dd555dd5ddd5ddd55555dd555dd5d5d55555ddd555555d55ddd5ddd5dd555dd5ddd55d55ddd5555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555dd55ddd55dd5ddd5ddd5ddd55dd5ddd55555d5d5d5d5ddd5dd555555ddd5ddd5d555d555ddd5dd555dd5555555555555555555555555555
55555555555555555d5d5d555d555d5d5d555d5d5d555d5555555d5d5d5d5d555d5d55555d555d5d5d555d5555d55d5d5d555555555555555555555555555555
55555ddd5ddd55555d5d5dd55d555dd55dd55ddd5ddd5dd555555d5d5ddd5dd55d5d55555dd55ddd5d555d5555d55d5d5d555555555555555555555555555555
55555555555555555d5d5d555d555d5d5d555d5d555d5d5555555ddd5d5d5d555d5d55555d555d5d5d555d5555d55d5d5d5d5555555555555555555555555555
55555555555555555ddd5ddd55dd5d5d5ddd5d5d5dd55ddd55555ddd5d5d5ddd5d5d55555d555d5d5ddd5ddd5ddd5d5d5ddd5555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555566566656665656566656665656555555555ccc555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5555565556565656565655655565565657775555555c555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555655566556665656556555655666555555555ccc555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555656565656565666556555655556577755555c55555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555666565656565565566655655666555555755ccc555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
555556665666566655665666566655665665555555555ccc5ccc5555555555555555555555555555555555555555555555555555555555555555555555555555
555556555656556556555565556556565656577755555c5c5c5c5555555555555555555555555555555555555555555555555555555555555555555555555555
555556655665556556555565556556565656555555555ccc5ccc5555555555555555555555555555555555555555555555555555555555555555555555555555
555556555656556556555565556556565656577755555c5c5c5c5555555555555555555555555555555555555555555555555555555555555555555555555555
555556555656566655665565566656655656555555755ccc5ccc5555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
555555555555555555dd5ddd5ddd5ddd5dd5555555dd5ddd555555dd5d5d5ddd55555ddd5dd55ddd5ddd5ddd5ddd5ddd55dd5dd555555d5555dd55dd5ddd55dd
55555555555555555d555d5d5d555d555d5d55555d5d5d5555555d5d5d5d5d5d55555d5d5d5d55d55ddd5d5d55d555d55d5d5d5d55555d555d5d5d5d5d5d5d55
55555ddd5ddd55555ddd5ddd5dd55dd55d5d55555d5d5dd555555d5d5d5d5dd555555ddd5d5d55d55d5d5ddd55d555d55d5d5d5d55555d555d5d5d5d5ddd5ddd
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
82888222822882228888822288828228822282228222888888888888888888888888888888888888888882828222822882888882822282288222822288866688
82888828828282888888828888288828828888828288888888888888888888888888888888888888888882828882882882888828828288288282888288888888
82888828828282288888822288288828822288228222888888888888888888888888888888888888888882228822882882228828822288288222822288822288
82888828828282888888888288288828888288828882888888888888888888888888888888888888888888828882882882828828828288288882828888888888
82228222828282228888822282888222822282228222888888888888888888888888888888888888888888828222822282228288822282228882822288822288
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

__gff__
000301030101010101010101014141010000000000010000000000000000000008080808080c0c0c0c0c0000000000001010101010101010000000000000000000000000000000000000000000000000000000000000002020202020200000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0805050505050505050505050505050908050505050505050505050505050509080505050505050505050505050509000805050505050505050505050505050908050505050505050505050505090805050505050505050505050505050908050505050505050505050505050505050505050505050505050505050505050509
0270000000000000000000000000000402010100003132000037373700010104020000000000000000000000000004000200000000000000000000000000000402000000000000000000000000040200000000000000000000000000000402000000000000000000000000000000000000000000000000000000000000000004
0224700000000000000000000000000402010000003132000000000000000104020000000000000000000000000004000200000000000000000000000000000402000000000000000000000000040200000000000000000000000000000402230000000000000000000000000000000000000000000000000000000000000004
0201010101010101010101010000000402000000003132000000000000000004020000000000005700000000000004000200000000000000000000000000000402000000000000000000000000040200230000000000000000000000000402010000000000000000000000000000000000000000000000000000000000000004
0200000000000000000000010100000402000000003132000000000000000004020000000000000000000000000004000200000000000000000000000000000402000000000030000000000000040200010000570000000000000000000402000000000000000000000000000000000000000000000000000000000000000004
0200000000000000000000000000000402240000003132000000010000000004020000000000010101000000000004000200000000000000570000000000000402000001000001000000000023040200000000000030303030300000000402000000000101010101000000000000000000000000000000000000000000000004
020000000000000000000000000034040201340000000000000101010000000402000000000000000000000000000400024000000000000000000000000000040200000100000100010101010104020000000b0b0b0b0b0b0b0b0000000402000000000000000000000000000000000000000000000000000000000000000004
0200000000013030300101010101010402010101010101010101010101000004020100000000000000000000000004000200000000000000000000000000230402000001000001000000000000040200000000000000000000000000000402000000000000000000000001010101010000000000000000000000000000000004
0200010101010101010100000000000402000000003737000037370001010004020000000000000000000000000004000201010101000000000000010101010402000001000001000000000000040200003000000000000000000000000402000000000000000000000000000000000000000000000000000000000000000004
0200010000000000000000000000000402000000000000000000000001010004020000000101010101010000002304000200000000000000000000000000000402000001000001000000000000040200310100000000000000000000000402000000000000000000000000000000000000010101010100000000000000000004
0200010000000000000000000000400402000000000000000000000000010004020000000000000000000000010104000200000000000000000000000000000402000001000001000000000000040200000000000000000000000000000402000000000000000000000000000000000000000000000000000000000000000004
0200000000000101010000000000010402400000000000000000000000010004020000000000000000000001010104000200000000000000000000000000000402000001005701000000000000040200000000003000000000000000000402000000005700000000000000000000000000000000000000000101010101000004
0703030303030303030303030303030602000000003030000030300000000004020000000000000000000101010104000200000000000000000000000000000402000001000001000000000000040200000000000132000000000101000402000000000000000000000000000000000000000000000000000000000000000004
0000000000000000000000000000000007030303030303030303030303030306020000000000000000010101010104000200000000000000000000000000000402000001000001000000000000040200000040000000000000000000000402400000000000000000000000000000000000000000000000000000000000000004
000000000000000000000000000000000000000000000000000000000000000002400000000000000101010101010400023434343434343434343434343434040240000134340134343434343404023434340b3434343434343434343404020b0b0b0b0b0b0b0b0b0b0b34343434340b0b0b0b0b0b0b0b3434340b0b0b0b0b04
0000000000000000000000000000000000000000000000000000000000000000070303030303030303030303030306000703030303030303030303030303030607030303030303030303030303060703030303030303030303030303030607030303030303030303030303030303030303030303030303030303030303030306
0805050505050505050505050505050908050505050505050505050505050509080505050505050505050505050505090805050505050505050505050505050505050505050505050505050505090805050505050505050505050505050900000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000402000000000000000000000000000004023633333333333333333333333333040237373737010101010101010101010101373737373737373737010101040223000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000
020000000000000000000000000000040257000000000000000000000000400402360000000000000000000000004004023f003f3f330101010101010101010101000000000000000000010100040201000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000
02000000000000000000000000000004020d0b0b0b0b0b0b0b0b0b0b0b0b0b04023600000031010101010101010101040200000000003333010101010101010101000000000000000000010000040201010100000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000402000000000000000000000000000004023600000031010101010101010101040200000000000000333301010101010101000000000000000000003000040200000000000000000000010101010400000000000000000000000000000000000000000000000000000000000000000000
0200000000000057000000000000000402000000000000000000000000000004023600000035010101010101010101040200001200000000000033330101010101000000000000000000300100040200000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000000000000000402010101010101010101010101010d04023600003101010101010101010101040200120000000000000000000000000000000000000000000000010100040200000000000000000d00000000000400000000000000000000000000000000000000000000000000000000000000000000
020d0000000000000000000000000d0402000000000000000000000000000004023600003101010101010101010101040212000000000000000000000000000000000000000000000000010100040200000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000
0200000000000001000000000000000402000000000000000000000000000004023600003101010101010101010101040200000000000000000000000000005700000000000000000000010100040200000000000d00000000000000000400000000000000000000000000000000000000000000000000000000000000000000
0200000000000101010000000000000402000000000000000000000000000004020136000031010101010101010101040200000000000000000000000b0b0b0b0b00000000000d000000010100040200000000000000003434343434340400000000000000000000000000000000000000000000000000000000000000000000
020000000001010101010000000000040200000000000d00000000000000000402013600003101010101010101010104020000000000000000000b0b0101010101000000000000000000010100040200000000000000000101010101010400000000000000000000000000000000000000000000000000000000000000000000
02000000010101010101010000000004020000000000000000000d00000000040201013600003737373737373737350402000000000000000b0b01010101010101000000000000000000010100040201010101343400000133333333330400000000000000000000000000000000000000000000000000000000000000000000
0240000101010101010101010000000402000000000000000000000000000d04020101360000000000000000000035040201000000400b0b0101010101010101010d0d0d0d0000000000010100040237373701010100000100000000000400000000000000000000000000000000000000000000000000000000000000000000
02000101010101010101010101000004020000000000000000000000000000040201013600000000000000000000350402010100000b0101010101010101010101000000000000000000010100040200000000010100000000000000000400000000000000000000000000000000000000000000000000000000000000000000
0201010101010101010101010101230402002300343430343430343430343404020101343401010101013430243035040201010123010101010101010101010101343434343434343434010101040200005700000132000000000000000400000000000000000000000000000000000000000000000000000000000000000000
0703030303030303030303030303030607150315030303030303030303030306070303030303030303030303030303060703030303151515151515151515151515151515151515151515151515060200000b00000132000d00000000000400000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0107000025731257310b634166342b7342b734136341963431734317341a6341f63435734357340170607706397062a7062b7062b7062d7063770637706377063770636706157061870618706187061870600706
011800200c0533f2051b3031b303246150c0533f4053f3050c0533f2053f2051b303246151b3030c0531b3030c0533f4053f3053f205246153f3050c0533f4050c0530c0533f2053f20524615246150c05324615
01180020021500e05002155020500215002055021500205502150020500e1000e155021550e155021550e1550215002055021500e0500e1550205002150020500e150020550e1000e155021550e155021550e155
01180020001500c05000155000500015000055001500005500150000500e1000c155001550c155001550c1550015000055001500c0500c1550005000150000500c150000550e1000c155151550c155001550c155
01180020001500c0500e155000500e1500c005021500c155021500c0520e15010155001500e1550c1000c050000500c155001500c0550c0000005500150000500c0550e1050e100001551315215155101550c155
010c00200e732217301c732217301d732217301373213732157321573221732157322173221732217322172221722237022170200702000000000000000000000000000000000000000000000000000000000000
01100020001530c1552462324623131550c623246232462500155246233060324623001550015524623246030c15510155246231115524623180030c1550c1530c155180030c6230c623181550c1550c62300153
0108000018634365252c5251b52512525195252852531525255042750427504025040250402504185041850418504185041850418504185041850418504185041850418504185041850418504185041850400000
011400080001602716000160271600016027160201600716000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01030000216130c5001c5001050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300002d61318405000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400001a7210e7211a1010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d00080c111001110c1120c1110c1120c1120c1110c111180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400000e60024000307002450030500247003050018500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300000041500605000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01030000004770c675180001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010e002006136061260812608126041360612607136091260812607136071260213608136061260612606126061360613607136081260812609126091360a1260912609136081260813608126071260713607126
010b0000188051880016804168021880516805168041680218805188001b8041b802188051880016804168021880518800168041680218805188001b8041b8021880518800168041680218805188001680416802
010b000030e0530600306003060030e053060030600306003060530600306003060030e0530e0030e0030e0030e0530e0030e0030e0030e0530e0030e0030e0030e0530e0030e0030e0030e0530e0030e0030e00
010b000030e0530e0000c0530e0030e0530e0000c0530e0030e0530e0000c0530e0030e0530e0030e0530e0000c0530e0030e0530e0030e0530e0000c0530e0030e0530e0000c0530e0030e0530e0000c0530e00
010b00001ff0613f061ff0500f0000f0000f0000f0000f0000f0000f001ff0000f001ff0013f001ff0613f061ff0500f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f00
010b00001ff0613f061ff0500f001bf060ff061bf0500f0000f0000f001ff0000f001ff0013f001ff0613f061ff0500f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000f0000d00
010b00000ce0500e0000e000ce050ce0500e000ce0500e000ce000ce050ce0500e000ce0500e000ce050ce050ce0500e0000e000ce050ce050ce050ce050ce050ce000ce050ce050ce050ce050ce050ce050ce05
010b00001880418802188051680018800188001880418805188051880518800188001880516800168051680018804188052280018800188001880018805188001880518800188001880018800188001880516800
000100001fe0505e00180001800012e001ae001ee0023e0026e0026e0026e0028e0029e0029e0029e0028e0026e0025e0021e001fe001ee0018e0014e0011e000ee000be000be0007e0003e0003e0003e0002e00
010b00001ff0613f061ff0613f061ff0613f061ff0613f061ff0613f061ff0613f061bf060ff061bf060ff061bf060ff061bf060ff061bf060ff061bf060ff061bf060ff061bf060ff060ff050ff061bf060ff06
01090000001020010200100001000c10000100001000010000105001000c100001000c10000100001000010000102001020c100001000c10000100001000010000105001000c100001000c100001000010000100
010900000c5040c50500500005000e5040e50500500005000f5040f50500500005000050000500145041450500500005001450414505135041350511500005001150411505005000050000500005001350413505
0109000000500005001350413505115041150500500005000f5040f505005000050000500005001150411505005000050011504115050f5040f50500500005000e5040e505005000050000500005000050000500
010900000c5040c50500500005000e5040e50500500005000f5040f50500500005000050000500145041450500500005001450414505135041350511500005001150411505005000050000500005001850418505
0109000000500005001850000500145041450500500005001350413505005000050000500005001a5041a50500500005000050000500185041850500500005001350413505005000050000500005000050000500
01090000180060c006180000c0001a0060e0061a0000e0001b0060f0061b0060f00620006140062000614006180000c00020006140061f006130061d0000c0001d006110061d006110061f006130061f00613006
01090000180000c0001f006130061d006110061d006110061b0060f0061b0060f0061d006110061d00611006180000c0001d006110061b0060f0061b0060f0061a0060e0061a0060e006180060c006180060c006
01090000180060c006180060c0061a0060e0061a0060e0061b0060f0061b0060f00620006140062000614006180000c00020006140061f006130061f006130061d006110061d0061100624006180062400618006
01090000180060c006180060c006200061400620006140061f006130061f00613006260061a006260061a00624006180062400618006240061800624006180061f006130061f00613006180060c006180060c006
010900000c6050c6050c6050c6050c6050c6050c605000000c6050c6050c6050c6050c6050c6050c6050c6050c6050c6050c605000000c6050c6050c6050c6050c6050c6050c605000000c6050c6050c6050c605
010900000c6050c6050c6050c6050c6050c6050c605000000c6050c6050c6050c6050c6050c6050c6050c6050c6050c6050c605000000c6050c6050c6050c6050c6050c6050c605000000c6050c6050c6050c605
000900000c60500000000000000000000000000c60500000000000000000000000000c6050000000000000000c60500000000000000000000000000000000000006050000000605000000c605000000c60500000
0109000000506075060050607506075060f506075060f5060c5060f5060c5060f5060c506135060c50613506135060f506135060f506135061b506135061b506185061b506185061b50618506275061850627506
010900000040500000000000000000000000000040500000004030000000000000000040500000000000000000405000000000000000004050000000405000000040300000000000000000000000000000000000
01090000243330160018323046070c313026070031300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900002763307630016030c0000360014100026000f1000c6050c6050c6050c6050c1030c0000c1030c0000c0000c0000c1030c0000c6050c6050c1030c0000c6050c0000c0000c0000c1030c0000c6050c000
010c00003034324343183430034300303183030030300303003030c303003030c3030030300303003030c30300303003030030300303003031830300303003030030300303003030030300303003030030300303
010900000761000100001000c10000100001000010000105001000c100001000c10000100001000010000102001020c100001000c10000100001000010000105001000c100001000c10000100001000010000000
010900000710207102001000010000100001000010000100071050010000100001000010000100001000010007102071020010000100001000010000100001000710500100001000010000100001000010000100
010900000710207102001000010000100001000010000100071050010000100001000010000100001000010007102071020010000100001000010000100001000710500100001000010000100001000010000100
010300000e0000c0001800015000120000f0000f0000d0000c0000a0000a000080000400004000040000300003000020000100001000010000000000000000000000000000000000000000000000000000000000
010200000860006600076000560004600046000360003600026000260001600016000160004600046000360003600026000160001600016000000000000000000000000000000000000000000000000000000000
010300000c906189060c9062490618906249062490630906159000d9000d9000e900179000d90012900129000f9000e9000d9000f9001490015900169000c9000c9000f90011900139001490015900169000c900
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01120010181001a1000c1001b7001b404220001f1001f504181031a1021f1001d104201001f100371062b7041e1002200026000290002a0002a0002a0002a0002900027000240001d00000000000000000000000
011200100030000102003020010502201021060250402101033010310703107033010510605202057010520000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 0102427f
00 0103437f
00 0102437f
02 0104547f
00 1113197e
00 1113147f
00 1113197f
00 1113157f
03 0856547f
00 1716157f
04 0546597f
03 0656557f
01 1a252344
00 1a252444
00 1a1b2444
00 281c2444
00 2b1d2544
00 2b1e2644
00 1a1f2744
00 1a202744
00 1a212744
00 1a222744
00 2b252744
00 2b272944
00 2c2a2944
00 2c2a2944
00 1a272944
00 1a272d44
00 2c242744
02 2d242744
03 32334344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 1a1f4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
03 01424344

