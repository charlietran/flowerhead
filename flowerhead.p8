pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- f l o w e r h e a d
-- by charlie tran

game_mode={
  intro={is_intro=1},
  game={is_game=1},
  lvl_complete={is_lvl_complete=1,lines={}},
  outro={is_outro=1},
  debug_menu={}
}
current_game_mode=game_mode.intro

function _init()
	printh("------\n")

	gravity=.2
	friction=.88

	-- speed of our animation loops
	runanimspeed=.12
	wallrunanimspeed=.2

	-- delta time multiplier,
	-- essentially controls the
	-- speed of the game
	dt=.5

	-- game length timer
	gametime=0

  coroutines={}
  deferred_draws={}

	game_mode.intro:init()
	clouds:init()
	cam:init()
	levels:init()
	tutorials:init()
	player:init()
end

function _update60()
  run_coroutines()
	current_game_mode:update()
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
  if(toggles.performance) draw_debug()
end

function game_mode.game:update()
	gametime+=1
	cam:update()
	levels:update()
	player:update()
	bees:update()
	specks:update()
	bombs:update()
	explosions:update()
end

function game_mode.game:draw()
  cls()

  clouds:draw()
  cam:draw()
  levels:draw()
  tutorials:draw()
  grasses:draw()
  bees:draw()
  player:draw()
  specks:draw()
  bombs:draw()
  explosions:draw()
  banners:draw()
  cam:fade()
end

function round(num, numdecimalplaces)
  if numdecimalplaces and numdecimalplaces>0 then
    local mult = 10^numdecimalplaces
    return flr(num * mult + 0.5) / mult
  end
  return flr(num + 0.5)
end

clouds={
  speed=0.1,
  padding=40,
}
clouds.list={}

function reset_level()
	player:init()
	cam.fadeout=1
	gametime=0

  if not levels.current.started then
    levels.current.started=true
		banners:add(levels.current.banner)
		grasses.map={}
		levels.current.percent_complete=0
		levels.current.planted=0
  else
    truncate(grasses.map)
    truncate(bombs.list)
    truncate(specks.list)
    truncate(explosions.list)
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
  local t=time()
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

      local xdrift  = 0.1*cam.x+t
      local xoffset = cloud.x-xdrift*cloud.size*clouds.speed
      local xrange  = 128+clouds.padding+2*cloud.size

      cloudx=xoffset%xrange-cloud.size

      fillp(0b0110111110111111)

			-- draw our cloud circle
      circfill(cloudx,cloudy,cloud.size,1)
	end

	fillp()
end

levels={
	index=1, -- current lvl index
	list={}
}

levels.list[1]={
  cx1=0,cy1=0,
  timer_disabled=true,
  banner={
    title="level 1",
    caption="welcome to the dungeon"
  }
}
levels.list[2]={
  cx1=16,cy1=0,
  enemies_disabled=true,timer_disabled=true,
  banner={
    title="level 2",
    caption="plant some flowers!"
  }
}
levels.list[3]={
  cx1=94,cy1=28,
  enemies_disabled=true,timer_disabled=true,
  banner={
    title="level 3",
    caption=""
  }
}

-- find each level block, add
-- it to the list with coords
function levels:init()
	-- tile 6 is bottom right
	-- tile 7 is bottom left
	-- tile 8 is the top left
	-- tile 9 is top right
  for level in all(levels.list) do
    levels.setup(level)
  end

	levels.current=levels.list[1]

end -- levels:init

function levels.setup(lvl)
  local cx1,cy1=lvl.cx1,lvl.cy1
  -- initialize the level object
  -- with initial coordinates
  -- from the top-left block
  -- x/y = pixel coords
  -- cx/cy = map cell coords
  lvl.sx1=cx1*8
  lvl.sy1=cy1*8

  lvl.plantable=0
  lvl.planted=0
  lvl.percent_complete=0

  -- determine level bounds
  -- set the pixel bounds in x/y
  -- and cell bounds as cx/cy
  for cx2=cx1,127 do
    if mget(cx2,cy1)==9 then
      lvl.cx2=cx2
      lvl.sx2=cx2*8+8
      break
    end
  end

  for cy2=cy1,63 do
    if mget(cx1,cy2)==7 then
      lvl.cy2=cy2
      lvl.sy2=cy2*8+8
      break
    end
  end

  for cy=cy1,lvl.cy2 do
    for cx=cx1,lvl.cx2 do
      -- check for plantable tiles and set the level's plantable count

      if is_plantable(cx,cy) then
        lvl.plantable+=1
      end

      -- if door found, set level's door location
      local tile=mget(cx,cy)
      if tile==35 or tile==36 then
        lvl.door_cx=cx
        lvl.door_cy=cy
        lvl.door_sx=cx*8
        lvl.door_sy=cy*8
        lvl.dooropen=tile==36
      end
    end
  end

  -- get closed door location, if there
  levels.set_spawn(lvl)
end

function levels.set_spawn(lvl)
	-- find start sprite (#64) and
	-- set initial x/y position
	for i=lvl.cx1,lvl.cx2 do
		for j=lvl.cy1,lvl.cy2 do
			if mget(i,j)==64 then
				lvl.spawnx=i*8+3
				lvl.spawny=j*8
				mset(i,j,0)
				break
			end
		end
		if lvl.spawnx then break end
	end
end

function levels:update()
	local c=self.current

  if not c.dooropen and not c.exited and c.planted>=c.plantable then
    self:open_door()
  end
end

function levels:draw()
  local c=self.current

  -- if exited, only draw the door at its screen location
  if c.exited then
    map(c.door_cx,c.door_cy,c.door_sx,c.door_sy,1,1)
  else
  -- otherwise, draw the whole current level
    map(c.cx1,c.cy1, -- cell coords of level origin
        c.sx1,c.sy1, -- screen coords of level origin
        c.cx2-c.cx1+1,
        c.cy2-c.cy1+1)
  end

  -- draw plant remainder above a locked exit
  if not c.dooropen then
    print(c.plantable-c.planted,c.door_sx+1,c.door_sy-6,7)
  end
end

function levels:open_door()
    self.current.dooropen=true
    sfx(0)
    mset(self.current.door_cx,self.current.door_cy,36)
    add(deferred_draws,self:make_door_anim())
end
  local frame=0

  return function()
		frame=(frame+1/16)%5
		mset(doorx,doory,36+frame)

    local t=time()
    --local radius=sqrt((player.x-x)^2+(player.y-y)^2)-16+8*cos(t/4)
    --local factor=.4
    --local center_x=x+factor*(player.x-x)
    --local center_y=y+factor*(player.y-y)
    --local radius=0.6*sqrt((player.x-center_x)^2+(player.y-center_y)^2)*(1-(.2*cos(t/4)))


    local rays=16
    local dx,dy=player.x-x,player.y-y
    local radius=sqrt((dx/1000)^2+(dy/1000)^2)*1000

    angle=0.5+atan2(dx,dy)

    local ease_angle=function(t) return -t^2+t+1 end
    --local ease_angle=function(t) return 3-(2^(-t/2+3/2)) end

    for i=1,rays do
      local tmod=t/rays+i/rays
      local rmod=(0.35-0.35*ease_angle(cos(tmod-angle)))*(1-.2*cos(t/4))

      line(
        x,y,
        x+rmod*radius*cos(tmod),
        y+rmod*radius*sin(tmod),
        10)
    end

  end
end

function levels:goto_next()
	self.index+=1
	self.current=self.list[self.index]

	if not self.current then
		current_game_mode=game_mode.outro
		return
	end

	current_game_mode=game_mode.game
	truncate(bees.list)
	reset_level()
end

banners={list={}}

function banners:add(_banner)
  local banner={
    title=_banner.title or "",
    caption=_banner.caption or "",
    height=_banner.height or 32,
    x=0,
  }
  banner.y=-banner.height -- start banner off screen
  add(self.list,banner)

  local anim1={duration=45,x=0,y=0}
  local anim2={duration=45,x=0,y=-banner.height,
               easing=ease_in_quad}
  local seq=coroutine_sequence({
    make_animation(banner,anim1),
    make_delay(30),
    make_animation(banner,anim2),
    function() del(self.list,banner) end })

  add(coroutines,seq)
end

function banners:draw()
  --local ox,oy=cam.x-64,cam.y-64
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
      y+b.height/4+sin(i/#b.title + t()/2),
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
	current_game_mode=game_mode.lvl_complete
	levels.current.exited=true
	player.vx=0
	self.box1={x=cam.x-64,y=cam.y-64-127,w=127,h=127,color=1}
	self.box2={x=cam.x-64,y=cam.y+64,w=127,h=127,color=1}
	defer_animation(self.box1,{x=cam.x-64,y=player.y-15-127,duration=30})
	defer_animation(self.box2,{x=cam.x-64,y=player.y+15,duration=30})
  add(coroutines,coroutine_sequence({
      make_delay(120),
      function()
        music(0)
        truncate(deferred_draws)
        levels:goto_next()
      end
  }))
	music(10)
end

function game_mode.lvl_complete:update()
end

function game_mode.lvl_complete:draw()
	cls()
	clouds:draw()
	cam:draw()
  levels:draw()
	player:draw()
	bees:draw()
  draw_box(self.box1)
  draw_box(self.box2)
end

--------------------------------
--entities----------------------
-- describes a world object that
-- has a position, velocity, a
-- sprite to draw, collides
-- with the map or other entities
-- and can be destroyed

entity_class={
		x=0, y=0, vx=0, vy=0,
		w=0, h=0, wr=0, hr=0,
		anim={timer=0,frames=0,speed=1},
		spr_x=0,spr_y=0,
		flipx=false,
		dead=false,
		dying=false,
		has_gravity=true,
		collide_callback=function(self,collision) end,
		die=function(self) self.dead=true end
}

function entity_class:new(o)
	return setmetatable(o or {}, {__index=entity_class})
end

function entity_class:collide_callback(collision)
end

function entity_class:move()
	-- move through all our x steps, then our y steps
	local xsteps=abs(self.vx)*dt
	local step,collision
	for i=xsteps,0,-1 do
		step=min(i,1)*sgn(self.vx)
		collision=collide(self,'x',step)
		if collision then
			self:collide_callback(collision)
			break
		else
			self.x+=step
		end
	end

	if self.has_gravity then
		self.vy+=gravity*dt
	end

	local ysteps=abs(self.vy)*dt
	for i=ysteps,0,-1 do
		step=min(i,1)*sgn(self.vy)
		collision=collide(self,'y',step)
		if collision then
			self:collide_callback(collision)
			break
		else
			self.y+=step
		end
	end
end

function entity_class:animate()
	if(self.dead) return

	self.anim.timer += self.anim.speed
	if self.anim.timer >= self.anim.frames then
		self.anim.timer=0
	end

	sspr(
		self.spr_x + flr(self.anim.timer)*self.w,self.spr_y,
		self.w,self.h,
		self.x-self.wr,self.y-self.hr,
		self.w,self.h,
		self.flipx
	)
end

--------------------------------
--player object-----------------
player={}

function player:init()
  self.is_player=1

	-- velocity
	self.vx=0
	self.vy=0

	--lists of our previous
	--positions/flippage for
	--effects rendering
	self.prevx=0
	self.prevy=0
	self.prevf=0

	--the "effects" timer
	self.etimer=0

	--the sprite is 3x5, so the
	--wr and hr dimensions are
	--radii, and x/y is the
	--initial center position

	self.wr=1
	self.hr=2
	self.w=3
	self.h=5

	self.hit_jump=false

	--instantaneous jump velocity
	--the "power" of the jump
	self.jumpv=3

	--movement states
	self.standing=false
	self.wallsliding=false

  self.disable_input=false

	--what direction we're facing
	--1 or -1, used when we're
	--facing away from a wall
	--while sliding
	self.facing=1

	--timers used for animation
	--states and particle fx
	self.falltimer=7
	self.landtimer=0
	self.runtimer=0
	self.headanimtimer=0
	self.throwtimer=0

	self.dead=false
	self.dying=false
	self.dying_timer=0

  self.exit_timer=0

	self.spr=64

	--sprite numbers------
	--64 standing
	--65 running 1
	--66 running 2
	--67	crouching (post landing)
	--80 jumping
	--81 falling
	--96 sliding 1
	--97 sliding 2
	--98 sliding 3 / hanging
	--99 sliding 4

	self.x=levels.current.spawnx
	self.y=levels.current.spawny
  if debug then
    printh("--player init--")
    printh("player.x: "..self.x)
    printh("player.y: "..self.y)
    printh("cam.x: "..cam.x)
    printh("cam.y: "..cam.y)
  end
end

function player:draw()
	if player.dead then
		player:draw_death()
		return
	end

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
		self.spr=96+flr(player.runtimer%4)
	else
		if self.vy<0 then
			self.spr=80 -- jumping up
		else
		 self.spr=81 -- falling down
		end
	end

	-- draw the player sprite
	spr(
		self.spr,   -- sprite
		self.x-self.wr,-- x pos
		self.y-self.hr,-- y pos
		0.375,   -- width .375*8=3px
		0.625,   -- height.625*8=5px
		self.flipx  -- flip x
	)
end

function player:draw_death()
end

function player:update()
	if self.dead then
    player.dying_timer-=1
    if self.dying_timer<=0 then
      if(current_game_mode.is_game) reset_level()
		end
		return false
  end

  if self.exit_timer >= 15 then
    game_mode.lvl_complete:start()
    return
  end
	self.standing=self.falltimer<7
	--move the player, x then y
	if(not self.disable_input) self:handleinput()
	self:movex()
	self:movey()
	self:movejump()
	self:checksliding()
	self:effects()
end

function player:checksliding()
	self.wallsliding=false
	--sliding on wall to the right?
  if not collide(self,'y',1) then
    if collide(self,'x',1) then
      self.wallsliding=true
      self.facing=-1
      if self.vy>0 then self.vy*=.97 end
    --sliding on wall to the left?
    elseif collide(self,'x',-1) then
      self.wallsliding=true
      self.facing=1
      if self.vy>0 then self.vy*=.97 end
    else
      self.facing=self.flipx and -1 or 1
    end
  end
end

function player:handleinput()
	if self.standing then
		self:groundinput()
	else
		self:airinput()
	end
	self:jumpinput()
	self:bombinput()

  -- press lshift or tab for debug menu
  if btnp(4,1) then
    game_mode.debug_menu:init()
    current_game_mode=game_mode.debug_menu
  end

	--overall x speed tweak to
	--make things feel right
	self.vx*=0.98
end

function player.jumpinput(p)
	local jump_pressed=btn(4)
	if jump_pressed and not p.is_jumping then
		p.hit_jump=true
	else
		p.hit_jump=false
	end
	p.is_jumping=jump_pressed
end --player.jumpinput

function player.bombinput(p)
	local bomb_pressed=btn(5)
	if bomb_pressed and not p.is_bombing then
		p.hit_bomb=true
	else
		p.hit_bomb=false
	end
	p.is_bombing=bomb_pressed
	if p.hit_bomb then
		p:throw_flowerbomb()
		p.throwtimer=7
	end
end

function player.movejump(p)
	--if standing, or if only just
	--started falling, then jump
	if(not p.hit_jump) return false
	if p.standing then
		p.vy=min(p.vy,-p.jumpv)
	-- allow walljump if sliding
	elseif p.wallsliding then
		--use normal jump speed,
		--but proportionate to how
		--fast player is currently
		--sliding down wall
		p.vy-=p.jumpv
		p.vy=mid(p.vy,-p.jumpv/3,-p.jumpv)

		--set x velocity / direction
		--based on wall facing
		--(looking away from wall)
		p.vx=p.facing*2
		p.flipx=(p.facing==-1)

		sfx(9)
	end
end --player.movejump

function player.groundinput(p)
	-- pressing left
	if btn(0) then
		p.flipx=true
		p.facing=-1
		--brake if moving in
		--opposite direction
		if p.vx>0 then p.vx*=.9 end
		p.vx-=.2*dt
	--pressing right
	elseif btn(1) then
		p.flipx=false
		p.facing=1
		if p.vx<0 then p.vx*=.9 end
		p.vx+=.2*dt
	--pressing neither, slow down
	--by our friction amount
	else
		p.vx*=friction
	end
end --player.groundinput

function player:throw_flowerbomb()
  bombs:add(self.x,self.y-1,self.facing,self.vx)
end

function player.airinput(p)
	if btn(0) then
		p.vx-=0.15*dt
	elseif btn(1) then
		p.vx+=0.15*dt
	end
end --player.airinput

function player.movex(p)
	--xsteps is the number of
	--pixels we think we'll move
	--based on player.vx
	local xsteps=abs(p.vx)*dt

	--for each pixel we're
	--potentially x-moving,
	--check collision
	for i=xsteps,0,-1 do
		--our step amount is the
		--smaller of 1 or the current
		--i, since p.vx can be a
		--decimal, multiplied by the
		--pos/neg sign of velocity
		local step=min(i,1)*sgn(p.vx)

		--check for x collision
		if collide(p,'x',step) then
			--if hit, stop x movement
			p.vx=0
			break
		else
			--move if we didn't hit
			p.x+=step
		end
	end
end --player.movex

function player.movey(p)
	--always apply gravity
	--(downward acceleration)
	p.vy+=gravity*dt

	local ysteps=abs(p.vy)*dt
	for i=ysteps,0,-1 do
		local step=min(i,1)*sgn(p.vy)
		if collide(p,'y',step) then
			--y collision detected

			--trigger a landing effect
			if p.vy > 1 then
				p.landing_v=p.vy
			end

			--zero out y velocity and
			--reset falling timer
			p.vy=0
			p.falltimer=0
		else
			--no y collision detected
			p.y+=step
			p.falltimer+=1
		end
	end
end --player.movey

function player.effects(p)
	if p.standing then
		p:running_effects()
		p:landing_effects()
	elseif p.wallsliding then
		p:sliding_effects()
	end

	p:head_effects()
end --player.effects

function player.running_effects(p)
		-- updates the run timer to
		-- inform running animation

		-- if we're slow/still, then
		-- zero out the run timer
		if abs(p.vx)<.3 then
			p.runtimer=0
		-- otherwise if we're moving,
		-- tick the run timer and
		-- spawn running particles
		else
			local oruntimer=p.runtimer
			p.runtimer+=abs(p.vx)*runanimspeed
			if flr(oruntimer)!=flr(p.runtimer) then
				spawnp(
					p.x,     --x pos
					p.y+2,   --y pos
					-p.vx/3, --x vel
					-abs(p.vx)/6,--y vel,
					.5 --jitter amount
				)
			end
		end

		--update the "landed" timer
		--for crouching animation
		if p.landtimer>0 then
			p.landtimer-=0.4
		end
end

function player.landing_effects(p)
	--only spawn landing effects
	--if we've a landing velocity
	if(not p.landing_v) return

	--play a landing sound
	--based on current y speed
	if p.landing_v>5 then
		sfx(15)
	else
		sfx(14)
	end

	--set the landing timer
	--based on current speed
	p.landtimer=p.landing_v

	--spawn landing particles
	for j=0,p.landing_v*2 do
		spawnp(
			p.x,
			p.y+2,
			p.landing_v/8*(rnd(2)-1),
			-p.landing_v/7*rnd(),
			.3
		)
	end

	--slight camera shake
	--shakevy+=p.landing_v/6

	--reset landing velocity
	p.landing_v=nil
end

function player.sliding_effects(p)
		local oruntimer=p.runtimer
		p.runtimer-=p.vy*wallrunanimspeed

		if flr(oruntimer)!=flr(p.runtimer) then
			spawnp(
				p.x-p.facing,
				p.y+1,
				p.facing*abs(p.vy)/4,
				0,
				0.2
			)
		end
end

function player.head_effects(p)
	if p.etimer%19==0 then
		local ex,evx,edir
		edir=p.prevf and -1 or 1
		spawnp(
			p.prevx,
			p.prevy - p.hr,
			-edir*0.3, -- x vel
			-0.1, -- y vel
			0, --jitter
			10, -- color
			.7 -- duration
			)
		p.prevx=p.x
		p.prevy=p.y
		p.prevf=p.flipx
	end

	p.etimer+=1
	if(p.etimer>20) p.etimer=1
end

-- spawn a particle effect
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
		d=d or 0.5
	}
	s.duration=s.d+rnd(s.d)
	s.life=1

	add(specks.list,s)
end

function player:hit_spike()
	self.dead=true
	self.dying_timer=30
	for i=1,100 do
		spawnp(
			self.x,
			self.y+2,
			sgn(self.vx)*rnd(3), -- vx
			-7.5*rnd(), -- vy
			1, -- jitter
			7, -- color
			.75 -- duration
		)
		sfx(42)
	end
	cam:shake(30,2)
end

--collision code----------------
--------------------------------

-- given an agent and velocity,
-- this returns the coords of
-- which two coords should
-- be checked for collisions
function col_points(p,a,v)
	local x1,x2,y1,y2

	-- x movement and y movement
	-- are calc'd separately. when
	-- this func is called, we only
	-- need to check one axis

	if a=='x' then
		-- if we have x-velocity, then
		-- return the coords for the
		-- right edge or left edge of
		-- our agent sprite
		x1=p.x+sgn(v)*p.wr
		y1=p.y-p.hr
		x2=x1
		y2=p.y+p.hr
	elseif a=='y' then
		-- if we have y-velocity, then
		-- return the coords for the
		-- top edge or bottom edge of
		-- our p sprite
		x1=p.x-p.wr
		y1=p.y+sgn(v)*p.hr
		y2=y1
		x2=p.x+p.wr
	end

	-- x1,y1 now represents the
	-- "near" corner to check
	-- (based on velocity), and
	-- x2,y2 the "far" corner
	return x1,y1,x2,y2
end

-- check if the given entity (e)
-- collides on the axis (a)
-- within the distance (d)
function collide(e,a,d,nearonly)
	-- init hitmover checks
	justhitmover=false
	lasthitmover=nil

	-- get the 2 corners that
	-- should be checked
	x1,y1,x2,y2=col_points(e,a,d)

	-- add our potential movement
	if a=='x' then
		x1+=d
		x2+=d
	else
		y1+=d
		y2+=d
	end

  local coll={axis=a}

	-- query our 2 points to see
	-- what tile types they're in
  local cx1,cy1,cx2,cy2=flr(x1/8),flr(y1/8),flr(x2/8),flr(y2/8)
	local tile1=mget(cx1,cy1)
	local tile2=mget(cx2,cy2)

  -- start the exit timer when player touches door
  if not levels.current.exited and e.is_player and (is_open_exit(tile1) or is_open_exit(tile2)) then
    e.exit_timer+=1
  end

  if is_spike(tile1) or is_spike(tile2) then
    e:hit_spike()
  end

	-- "nearonly" indicates we only
	-- want to know if our near
	-- corner will be in a wall
	if nearonly and is_wall(tile1) and (tile1!=2 or y1%8<4) then
    coll.tile,coll.cx,coll.cy=tile1,cx1,cy1
	elseif not nearonly then
    --if not nearonly, check if
    --either corner will hit a wall
    if is_wall(tile1) then
      coll.tile,coll.cx,coll.cy=tile1,cx1,cy1
    elseif is_wall(tile2) then
      coll.tile,coll.cx,coll.cy=tile2,cx2,cy2
    end
	end

  if coll.tile then
    return coll
  else
    return false
  end
end

-- sprite flags:
-- 0: collidable wall
-- 1: plantable
-- 2: open exit
-- 3: is exit (open or closed)

function is_wall(tile)
  return fget(tile,0)
end

function is_spike(tile)
	return tile==48
end

function is_exit(tile)
  return fget(tile,3)
end

function is_open_exit(tile)
  return fget(tile,2)
end

-- a tile is plantable if it has flag 1 set
-- and the tile above it is not a wall, exit or spike
function is_plantable(cx,cy)
  local tile=mget(cx,cy)
  local above_tile=mget(cx,cy-1)
  return fget(tile,1) and
          not is_wall(above_tile) and
          not is_spike(above_tile) and
          not is_exit(above_tile)
end

--effects-----------------------
--------------------------------

--specks holds all particles to
--be drawn in our object loop
specks={list={}}
function specks:update()
	for _,speck in pairs(self.list) do
		speck.ox=speck.x
		speck.oy=speck.y
		speck.x+=speck.vx
		speck.y+=speck.vy
		speck.vx*=.85
		speck.vy*=.85
		speck.life-=1/30/speck.duration

		if speck.life<0 then
			del(self.list,speck)
		end

    if current_game_mode.is_game and is_wall(mget(speck.x/8,speck.y/8)) then
			del(self.list,speck)
    end
	end
end

function specks:draw()
	for _,speck in pairs(self.list) do
		line(
			speck.x,
			speck.y,
			speck.ox,
			speck.oy,
			speck.c+(speck.life/2)*3
		)
	end
end

--grass objects-----------------
--------------------------------
grasses={
  map={},
  tiles={},
  anim={timer=0,frames=4,speed=1/15}
}


function grasses:draw()
	self.anim.timer+=self.anim.speed
	if(self.anim.timer>=self.anim.frames) self.anim.timer=0

	local spr_x,spr_y
	for grass_row,grasses in pairs(self.map) do
		for grass_col,grass_value in pairs(grasses) do
			spr_x=3 * flr(self.anim.timer)
			spr_y=8 + 2*grass_value
			sspr(
				spr_x,spr_y,
				3,2,
				grass_col-1,grass_row
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
  if grasses.tiles[cy][cx]>=6 then
    grasses.tiles[cy][cx]=8
    levels.current.planted+=1

    -- draw the tile differently now that it is planted
    -- the sprite sheet is arbitrarily set up so that
    -- the planted version of a tile is 9 sprites
    -- to the right
    ot=mget(cx,cy)
    mset(cx,cy,ot+9)
  end
end

--flower bombs------------------
--------------------------------
bomb_class={
  w=3,h=3,
  wr=1,hr=1,
  vy=-2.5,
  spr_x=16,spr_y=8,
  anim={timer=0,frames=8,speed=1/3}
}
setmetatable(bomb_class,{__index=entity_class})

function bomb_class:new(obj)
  return setmetatable(obj or {}, {__index=bomb_class})
end

function bomb_class:collide_callback(collision)
  -- when a bomb x-collides with wall, bounce back
  if collision.axis=='x' then
    self.vx=-self.vx/4
    -- only explode when a bomb hits the floor
  elseif collision.axis=='y' then
    if self.vy>0 then
      if not is_plantable(collision.cx,collision.cy) then
        self:dud()
      else
        self:explode()
      end
    else
      self.vy=0
    end
  end
end

function bomb_class:hit_spike()
  self:dud()
end

function bomb_class:dud()
	explosions.add(self.x,self.y+2,2)
  sfx(41,3,1)
  del(bombs.list,self)
end

laffs={"woo","haa","hoo","hee","hii","yaa"}
function bomb_class:explode()
	explosions.add(self.x,self.y,4)
  local prev_planted=levels.current.planted
	for i=self.x+bombs.plant_radius,self.x-bombs.plant_radius,-1 do
		grasses.plant(i,self.y)
	end
  if levels.current.planted-prev_planted>4 then
    local laff={x=self.x,y=self.y,t=laffs[ceil(rnd(6))]}
    defer_animation(laff,{
        x=self.x,y=self.y-10,duration=60,
        draw=function() print(laff.t,laff.x+cos(t()),laff.y,3) end
    })
  end
	sfx(40,-1)
	sfx(41,-1)
	cam:shake(6,1)
	del(bombs.list,self)
end

bombs={
  plant_radius=5,
  list={}
}

function bombs:draw()
	for _,bomb in pairs(self.list) do bomb:animate() end
end

function bombs.update(b)
	for _,bomb in pairs(b.list) do bomb:move() end
end -- bombs.update()

function bombs:add(x,y,dir,vx)
	add(self.list,bomb_class:new({
    x=x,
    y=y,
    vx=(.5+rnd(.25))*dir + (vx*0.6),
}))
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
			s.r-=0.2
			if s.r<0.5 then
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
		spark.mass=0.5+rnd(2)
		spark.r=0.25+rnd(intensity)
		spark.vx=(-1+rnd(2))*0.5
		spark.vy=(-1+rnd(2))*0.5
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
	self.prompt="press up to start"
  self.animtimer=0
  self.animlength=8
	music(1)
end

function game_mode.intro:update()
	if btnp(2) then
		current_game_mode=game_mode.game
    reset_level()
    music(0)
	end

  specks:update()

  -- spawn speed streaks
  if self.animtimer%2==0 then
    spawnp(
      16+rnd(96),
      32+rnd(96),
      -3, -- x vel
      -3, -- y vel
      0.1, --jitter
      6, -- color
      0.5 -- duration
    )
  end
end

function game_mode.intro:draw()
  cls()
  specks:draw()
  map(0,48,0,0,16,16)

  local time=t()

  self.animtimer+=0.25
  if self.animtimer>self.animlength then
    self.animtimer=1
  end

  for i=1,#self.title do
    y=sin(i/16+time/8)*4
    print(
      sub(self.title,i,i),
      64 - #self.title*4  + ((i-1)*8),
      50+y,
      3)
    if i==5 then sy=50+y-5 end
  end

  spr(64,56,sy)

  if self.animtimer%3==0 then
    spawnp(
      57,
      sy,
      -.7, -- x vel
      -.2, -- y vel
      0, --jitter
      10, -- color
      .7 -- duration
    )
  end
	-- print "press x to start"
	-- in a static position
  if self.animtimer < 6 then
	print(
    self.prompt,
		64-#self.prompt*2,
		80,
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
	self.x=mid(self.x,levels.current.sx1+64,levels.current.sx2-64)
	self.y=mid(self.y,levels.current.sy1+64,levels.current.sy2-64)
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
	anim={timer=0,frames=3,speed=1/4},
  spr_x=64,spr_y=8,
  is_bee=true,
  has_gravity=false,
  vx_turning=0.05,
  vy_turning=0.1,
  w=7,h=7,wr=3,hr=3,
  flipx=false,
  update_counter=0,
  max_vx=1,
  max_vy=1,
  path={}
}
setmetatable(bee_class,{__index=entity_class})

function bee_class:hit_spike()
end

function bee_class:new(obj)
  local bee=obj or {}
	bee.pathfinder=pathfinder_class:new(bee)
  return setmetatable(obj or {}, {__index=bee_class})
end

function bee_class:jitter()
	local time=t()
	local offset=sin(time)*0.3
	self.vy=mid(self.vy+offset,-self.max_vy,self.max_vy)
end
bees={
  list={},
	update_interval=15
}

function bees:update()
  for _,bee in pairs(bees.list) do
		bee.update_counter+=1
		if bee.update_counter == bees.update_interval then
			bee.update_counter=0
			bee.pathfinder:update(player)
		end
			bee.cx=flr(bee.x/8)
			bee.cy=flr(bee.y/8)
			bee.pathfinder:aim(bee)
		if toggles.bee_move then
			bee:jitter()
			bee:move()
		end
	end
end

function bees:draw()
	for _,bee in pairs(self.list) do
		if(toggles.path_vis) bees.draw_paths(bee)
		bee:animate()
	end
end

function bees.draw_paths(bee)
		for cell in all(bee.visited) do
			local px,py=cell[1][1]*8,cell[1][2]*8
			fillp(0b0000111100001111)
			rectfill(px,py, px+7,py+7,3)
			fillp()
			print(cell[2],px,py+2,11)
		end

		if bee.next_cell then
			rectfill(
				bee.next_cell[1]*8,bee.next_cell[2]*8,
				bee.next_cell[1]*8+7,bee.next_cell[2]*8+7,
				7)
		end

		local points={}
		for cell in all(bee.path) do
			add(points,{cell[1]*8+4,cell[2]*8+4})
		end

		for i=2,#points do
			local x1=points[i-1][1]
			local y1=points[i-1][2]
			local x2=points[i][1]
			local y2=points[i][2]
			line(x1,y1,x2,y2,8)
		end
end

function bees:add(x,y)
  add(self.list,bee_class:new({x=x,y=y}) )
end

--tutorials---------------------
--------------------------------
-- in game tutorial text
-- the index is the sprite num
tutorials={list={}}

tutorials.list[113]={
	lines={
		{c=7,t="⬅️➡️⬆️⬇️: move"},
		{c=7,t="z:jump/walljump"},
	}
}

tutorials.list[114]={
  lines={
    {c=7,t="fill the dungeon with"},
    {c=7,t="flowers to unlock exit"},
    {c=7,t=""},
    {c=7,t="x:throw flower bomb"},
  }
}

function tutorials:init()
	for i=0,127 do
		for j=0,63 do
			local spr_num=mget(i,j)
			if self.list[spr_num] then
				self.list[spr_num].x=i*8+1
				self.list[spr_num].y=j*8
				mset(i,j,0)
			end
		end
	end
end

function tutorials:draw()
	for _,tut in pairs(self.list) do
		if tut.x then
			for i,line in pairs(tut.lines) do
				print(
					line.t,
					tut.x,
					tut.y + i*7,
					line.c or 7)
			end
		end
	end
end

outro={}
function outro:init()
end

function outro:update()
	if btnp(4) then
		reset_level()
		current_game_mode=game_mode.intro
	end
end

function outro:draw()
	cls()
	music(-1,50)
	camera(0,0)
	print("you planted all the flowers!!", 16, 54, 7)
	print("your time: "..round(gametime/60,2).." seconds", 24, 62, 7)
	print("press z to restart", 32, 70, 7)
end

-- pathfinder class
pathfinder_class={}

function pathfinder_class:new(agent)
	return setmetatable({agent=agent}, {__index=pathfinder_class})
end

function pathfinder_class:update(target_entity)
  if(target_entity.dead) return
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

	self.agent.visited={}

	local path_cell = self:search_frontier()

	self.agent.path={path_cell,self.goal_cell}
	local path_index=cell_to_index(path_cell)

	while path_index != start_index do
		insert(self.agent.path, path_cell)
		path_cell = self.came_from[path_index].cell
		path_index = self.came_from[path_index].index
	end
end

function pathfinder_class:search_frontier()
	while #self.frontier>0 do
		local current=pop_end(self.frontier)
		if current.index==self.goal_index then
			return current.cell
		end

		local neighbor_cells=self.get_neighbor_cells(current.cell)
		for neighbor_cell in all(neighbor_cells) do
			local neighbor_index=cell_to_index(neighbor_cell)
			local new_cost=self.cost_so_far[current.index]+1

			if (not self.cost_so_far[neighbor_index]) or (new_cost < self.cost_so_far[neighbor_index]) then
				add(self.agent.visited,{neighbor_cell,new_cost})
				self.cost_so_far[neighbor_index]=new_cost
				if toggles.a_star then
					insert_sorted(self.frontier, {
							cell=neighbor_cell,
							index=neighbor_index,
							priority=new_cost+manhattan_heuristic(neighbor_cell,self.goal_cell)
					})
				else
					insert(self.frontier,{cell=neighbor_cell,index=neighbor_index})
				end
				self.came_from[neighbor_index]=current
			end
		end
	end -- while #frontier>0
end


function pathfinder_class.get_neighbor_cells(cell)
  local neighbors={}
  local lvl=levels.current
	local x,y=cell[1],cell[2]

	local neighbor_cells={
		{x-1,y-1},
		{x,y-1},
		{x+1,y-1},
		{x-1,y},
		{x+1,y},
		{x-1,y+1},
		{x,y+1},
		{x+1,y+1}
	}

	for _,check in pairs(neighbor_cells) do
		if check[1]>lvl.cx1 and check[1]<lvl.cx2 and
			check[2]>lvl.cy1 and check[2]<lvl.cy2 and
			not is_wall(mget(check[1],check[2])) and
			not is_spike(mget(check[1],check[2]))
		then
			add(neighbors,check)
		end
	end

	if (cell[1] + cell[2])%2 == 0 then
		reverse_table(neighbors)
	end

  return neighbors
end

function pathfinder_class:aim(agent)
	local next_cell = agent.path[1]
	if(not next_cell) return

	if(agent.cx == next_cell[1] and agent.cy == next_cell[2]) do
		del(agent.path,next_cell)
		next_cell = agent.path[1]
		if(not next_cell) return
	end
	agent.next_cell=next_cell

	local targetx = next_cell[1]*8+4
	local targety = next_cell[2]*8+4

	if(targetx<agent.x) agent.vx=max(agent.vx-agent.vx_turning,-agent.max_vx)
	if(targetx>agent.x) agent.vx=min(agent.vx+agent.vx_turning,agent.max_vx)
	if(targetx==flr(agent.x)) agent.vx=0
	agent.flipx=agent.vx<0


	if(targety<agent.y) agent.vy=max(agent.vy-agent.vy_turning,-agent.max_vy)
	if(targety>agent.y) agent.vy=min(agent.vy+agent.vy_turning,agent.max_vy)
	if(targety==flr(agent.y)) agent.vy=0
end


-- utility functions
--------------------------------
function truncate(tbl)
	for o in all(tbl) do
		del(tbl,o)
	end
end

function manhattan_heuristic(start, target)
	return abs(start[1]-target[1]) + abs(start[2]-target[2])
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

function defer_animation(obj,params)
  add(coroutines,
    cocreate(make_animation(obj,params))
  )
end

-- create an animation function to be
-- used in a coroutine
-- params: {x, y, duration, easing}
function make_animation(obj,params)
  return function()
    local x1,y1,x2,y2,dx,dy,duration,easing,percent
    x1,y1,x2,y2=obj.x,obj.y,params.x,params.y
    dx,dy=x2-x1,y2-y1
    duration=params.duration
    easing=params.easing or ease_out_quad
    percent=0
    if(params.draw) add(deferred_draws,params.draw)
    for dt=1,duration do
      percent=easing(dt/duration)
      obj.x=x1+(percent*dx)
      obj.y=y1+(percent*dy)
      yield()
    end
    obj.x=x2
    obj.y=y2
    if(params.draw) del(deferred_draws,params.draw)
  end
end

function make_delay(duration)
  return function()
    for i=1,duration do
      yield()
    end
  end
end

function coroutine_sequence(fns)
  return cocreate(function()
    for _,fn in pairs(fns) do fn() end
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

game_mode.debug_menu.sel=1
game_mode.debug_menu.items={}

function game_mode.debug_menu:update()
  if btnp(2) then self.sel-=1 end
  if btnp(3) then self.sel+=1 end
  self.sel=mid(self.sel,1,#self.items)
  if btnp(4) then self.items[self.sel][2]() end
  if btnp(4,1) then current_game_mode=game_mode.game end
end

function game_mode.debug_menu:draw()
  cls()
  camera(0,0)
  print("-- debug --",10,2,15)
  cursor(10,10)
  for index,item in pairs(self.items) do
    local y_off=10+(index-1)*8
    if index==self.sel then
      rectfill(8,y_off-1,10+#item[1]*4+5,y_off+5,15)
      print(item[1],13,y_off,0)
    else
      print(item[1],10,y_off,15)
    end
  end
end

function game_mode.debug_menu:init()
  self:make_toggle("performance",1)
  self:make_toggle("path_vis",2)
  self:make_toggle("a_star",3)
  self.items[4] = {
    "spawn bee", function()
      bees:add(levels.current.sx1+12,levels.current.sy1+12)
    end
  }
  self:make_toggle("bee_move",5)
  self.items[6]={
    "skip to next level", function() levels:goto_next() end
  }
  self.items[7]={
    "open current door", function() levels:open_door() end
  }
  self.items[8]={
    "return to game", function() current_game_mode=game_mode.game end
  }
end

function game_mode.debug_menu:make_toggle(name,index)
	self.items[index]={
    name..": "..(toggles[name] and "enabled" or "disabled"),
    function()
      toggles[name] = not toggles[name]
      self:make_toggle(name,index)
    end
  }
end

toggles={
	bee_move=true,
	a_star=true
}

__gfx__
00000000555555550005555555555555555550000000000055555000000555550000000000000000333333335555555533333333000000000000000000000000
000000005d5dd5650005d565565dd5d55d5650000000000055555000000555550000000000000000333333335c5dd5c533333333000000000000000000000000
00700700555555550005555555555555555550000000000055555000000555550000000000000000333333335555555535535333000000000000000000000000
000770005d5555d50005d5d55d5dd5655d5d50005555555555555000000555550005555555555000333333335d5555d53d5dd535000000000000000000000000
000770005d5555d50005d5d5555555555d5d5000565dd5d555555000000555550005555555555000333335335d5555d555555555000000000000000000000000
00700700555555550005555500000000555550005555555500000000000000000005555555555000335535355555555500000000000000000000000000000000
00000000565dd5d5000565d500000000565d50005d5dd5650000000000000000000555555555500035dd5d555c5dd5c500000000000000000000000000000000
00000000555555550005555500000000555550005555555500000000000000000005555555555000555555555555555500000000000000000000000000000000
0c0c000c000c000000b000000000000000b000b00000000000000000000000000770004000000000000000000000000000000000000000000000000000000000
0b00b00b00b0000004004b040040040b400400400000000000000000000000007667040000004400000440000000000000000000000000000000000000000000
070700070007000000000000b0b0b0000000000000000000000000000000000007667a007777a000a66a00000000000000000000000000000000000000000000
030030030030000000000000000000000000000000000000000000000000000005a5a8a6666a8a056678a0000000000000000000000000000000000000000000
0808000800080000000000000000000000000000000000000000000000000000a5a5aaaa5a5aaaa777aaa0000000000000000000000000000000000000000000
0b00b00b00b0000000000000000000000000000000000000000000000000000005a5aa005a5aa005a5aa00000000000000000000000000000000000000000000
0a0a000a000a00000000000000000000000000000000000000000000000000004040400040404004040400000000000000000000000000000000000000000000
03003003003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000cccc0000cccc0000cccc0000cccc0000cccc0000cccc000000000000000000000000000c0c000c000000000000000000000000
0455554000000000000000000c6666c00cccaaa00cccaaa00cccaaa00cccaaa00cccaaa00000000000000000000000000b00b0b0000000000000000000000000
0455554000000000000000000c6cc6c0cccca77cccc77aacc77caaac7cccaaacccccaaa700000000000000000000000007070007000000000000000000000000
455555540000000000000000cc6cc6ccccc77777c77777ac7777aaac77ccaaaccccca77700000000000000000000000003003030000000000000000000000000
455555540000000000000000c555555c77cc666ccc666ccc666ccc776ccc77cccc77cc6600000000000000000000000008080008000000000000000000000000
455559540000000000000000c555555c777cccccccccccccccccc777ccc7777cc7777ccc0000000000000000000000000b00b0b0000000000000000000000000
455555540000000000000000c555555c66cccccccccccccccccccc67cccc66cccc66cccc0000000000000000000000000a0a000a000000000000000000000000
455555540000000000000000cccccccccccccccccccccccccccccccccccccccccccccccc00000000000000000000000003003030000000000000000000000000
007000000000000000000000000000000001000001110000000000100000000000000000000000000000000000000000000000000c00700800a0000000000000
077000700000000000000000222222220001100001011000000001100000000000000000000000000000000000000000000000000b00300b0030000000000000
07770070000000000000000022222222000010000110100000001100111000000000000000000000000000000000000000000000c00700800a00000000000000
577756770000000000000000222222220000110000001110001111100011000000000000000000000000000000000000000000000b00300b0030000000000000
5677567600000000000000002222222200011110000111000010110001110000000000000000000000000000000000000000000000c00700800a000000000000
567656660000000000000000222222221111101000011000000011100101100000000000000000000000000000000000000000000b00300b0030000000000000
56665555000000000000000022222222001100000011110000001100001111000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000011111100111111000011110011111100000000000000000000000000000000000000000000000000000000000000000
00e0000000e0000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000e00000005550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66600000060000006660000000000000050055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000666000000660000066600000000005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60600000060000006000000060600000000000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00e0000000e0000000e0000000e0000000e0000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000606000000060000060600000006000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66000000060000000600000006000000060000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06600000660000000660000006600000060000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000000006000000600000006000000606000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0000000e0000000e0000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60600000606000006060000060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000060000000600000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06600000060000000600000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000006000000600000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbbbb8bbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb8bbbbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb8bbbbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020101010000000000000000000000000000000000000000000000013131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020000000001000000000000000000000000000000000000000000013131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000013131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020101010101010000010000000000000000000000000000010101010101013401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020000000000000000000000000100000001010101000000000000000131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000001000001000000000000000131313401300
0000000000000000000000000000000000000013131313131313131313131313131313f0f0f0f0f0f0f000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020100000000000000000000000000000000000000000000000000000101313401300
0000000000000000000000000000000000000013131313131313131313131313131313f0f0f0f0f0f0f000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000131313401300
0000000000000000000000000000000000000013131313131313131313131313131313f0f0f0f0f0f0f000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000013131313401300
0000000000000000000000000000000000000013131313131313131313131313131313f0f0f0f0f0f0f000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020005100001313000000000000000000000000000000000000001010101010401300
0000000000000000000000000000000000000013131313131313131313131313131313f0f0f0f0f0f0f000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020101010001313100000100000100000000010101010000000000000001313401300
0000000000000000000000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000001000000000004013f0
00f0f0f0f0f00000000000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131313131313000000000013131313131313131313131313131313134013f0
00f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131313131313131313137113135113131313131313131303030313134013f0
00f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131313131313131313101010101010131313131313101010101013134013f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131313130303031010101313131310101313131313000000000013134013f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131310101010101013131313131313101010131313131313131313134013f0
f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000010100000000000000000004000f0
f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020320000000000000000000000000000000000131310101313131313131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020b01000000000000000000000000000000000131313131313101313131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020000000000000000000000000000010000010131313130000131313131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020000000000000000000000000000010000010131313000000000013101313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020040000000000000000000000000010000010101013131313131313131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020101010000000100000000000000010000010131313131313131313131300401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020000000100000100000101010000010000010131313101013131313131300401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020000000000000100000000000000010000010131313131310101010101300401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020000000000000100000000000000000000010030303030303030303030303401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000070303030303030303030303030303030303030303030303030303030303030601300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000131313131313131313131313131300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0003010301010101010101010100000000000000000000000000000000000000000000080c0c0c0c0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0805050505050505050505050505050908050505050505050505050505050509000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000000402310031313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200700000000000000000000000000402313131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000000402313131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000230402313131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
02000000000000000000000000000b0402313131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000010402313131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000001000001010100000101010402313131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000001000000000000000101010402313131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0240000001303030303030300101010402313131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0703030303030303030303030303030602234031313131310101010131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
00000000000000000000000000000000020b0131313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000002010101313131313131313131313104000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000007030303030303030303030303030306000000000000000000000000000000000031000000000000000000000000000000000031313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000000313131313131313131313131313131000000000000000000000000000000000031313131313131313131313131313100313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000313131313131313131313131313100313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000000000000000000000000000000000031000000000000000000000000000000000031313131313131313131313131313100313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000000000000000000000000000000000031000000000000000000000000000000000031313131313131313131313131313100313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000000000000000000000000313131313131000000000000000000000000000000000031313131313131313131000000313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000000000000000000000000003131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000008050505050505050505050505050505050505050505050505050505050505093100
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000031313131043100
0000000000000000000000000000000031313131313131313131313131313100000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000031313131043100
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000010101013131043100
__sfx__
0007000025756257560b656166562b7562b756136561965631756317561a6561f65635756357560170607706397062a7062b7062b7062d7063770637706377063770636706157061870618706187061870600706
011800200c0533f2051b3031b303246150c0533f4053f3050c0533f2053f2051b303246151b3030c0531b3030c0533f4053f3053f205246153f3050c0533f4050c0530c0533f2053f205246153f2050c0531b303
01180020021500e05002155020500215002055021500205502150020500e1000e155021550e155021550e1550215002055021500e0500e1550205002150020500e150020550e1000e155021550e155021550e155
011800200f0350f0350a0351603501035220050f0351e0050f0352200503035140350a0350f035080351e005120350a035060350a0351603512035060351e005060350603506035140351403516035120351e005
0018002017017170170d0171a0171b017250170d01713054130171601711017080170f0170a0170a017080570a0170c017070170c017080170d0170d0170d0540d0170c0170b0170a0170701706017050171b307
010c00200e742217401c742217401d742217401374213742157421574221742157422173221742217422173221732237022170200702000000000000000000000000000000000000000000000000000000000000
010c00100c0332463324633246330c0332463324633246330c0332463330603246330c03324633246332460318003180031800318003180031800318003180031800318003180031800318003180031800318003
010200201870018700187001870018700187001870018700187001870018700187001870018700187001870018700187001870018700187001870018700187001870018700187001870018700187001870018700
01020000101030c500105001050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01030000151130c5001c5001050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300000c1030c405000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300001010300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0104000010604106051e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400000e60024000307002450030500247003050018500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300000041500605000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01030000004770c675180001800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010b00001880018800188001880518800168041680200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
01090000243530160018323046070c313026070031300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900002764307640016030c0000360014100026000f1000c6050c6050c6050c6050c1030c0000c1030c0000c0000c0000c1030c0000c6050c6050c1030c0000c6050c0000c0000c0000c1030c0000c6050c000
010c00003035324353183530035300303183030030300303003030c303003030c3030030300303003030c30300303003030030300303003031830300303003030030300303003030030300303003030030300303
01090000001020010200100001000c10000100001000010000105001000c100001000c10000100001000010000102001020c100001000c10000100001000010000105001000c100001000c100001000010000100
010900000710207102001000010000100001000010000100071050010000100001000010000100001000010007102071020010000100001000010000100001000710500100001000010000100001000010000100
010900000710207102001000010000100001000010000100071050010000100001000010000100001000010007102071020010000100001000010000100001000710500100001000010000100001000010000100
010300000e0000c0001800015000120000f0000f0000d0000c0000a0000a000080000400004000040000300003000020000100001000010000000000000000000000000000000000000000000000000000000000
010200000860006600076000560004600046000360003600026000260001600016000160004600046000360003600026000160001600016000000000000000000000000000000000000000000000000000000000
010300000c906189060c9062490618906249062490630906159000d9000d9000e900179000d90012900129000f9000e9000d9000f9001490015900169000c9000c9000f90011900139001490015900169000c900
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01120010181001a1000c1001b7001b404220001f1001f504181031a1021f1001d104201001f100371062b7041e1002200026000290002a0002a0002a0002a0002900027000240001d00000000000000000000000
011200100030000102003020010502201021060250402101033010310703107033010510605202057010520000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
03 0102427f
03 0143437f
02 0104437f
00 1013147f
00 1113197e
00 1113147f
00 1113197f
00 1113157f
00 1716147f
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

