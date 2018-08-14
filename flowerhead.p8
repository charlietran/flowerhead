pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- f l o w e r h e a d
-- by charlie tran

function _init()
	-- how many pixels per frame
	-- should our y velocity
	-- decrease when falling
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

	-- clear screen every frame?
	clear_screen=true

	-- gamestate starts in "intro"
	-- and then move into "game"
	-- and then "end"
	gamestate="intro"
	intro:init()

	-- holds all objects that exist
	-- in the game loop. each object
	-- should have :update and :draw
	-- set up our objects table
	-- in draw order
	objects={
		clouds,
		cam,
		levels,
		tutorials,
		grasses,
		player,
		specks,
		bombs,
		explosions,
		levelcomplete
	}

	for object in all(objects) do
		if(object.init) object:init()
	end
end

function _update60()
	if gamestate=="intro" then
		intro:update()
	elseif gamestate=="outro" then
		outro:update()
	else
		_updategame()
	end
end

function _updategame()
	gametime+=1
	for object in all(objects) do
		cam:update()
		if(object.update) object:update()
	end
end

function _draw()
	if(clear_screen) cls()

	if gamestate=="intro" then
		intro:draw()
	elseif gamestate=="outro" then
		outro:draw()
	else
		_drawgame()
	end
end

function _drawgame()
	-- debug=true
	if(debug) draw_debug()

	for object in all(objects) do
		if(object.draw) object:draw()
	end

	-- rectfill(cam.x-61, cam.y-64, cam.x-44,cam.y-59, 11)

	local percent=(levels.current.planted / levels.current.plantable)*100
	print(round(percent,2).."%",cam.x-60,cam.y-64,11)

	if cam.fadeout>0 then
		for i=0,15 do
			pal(i,i*(1-cam.fadeout),1)
		end
	else
		pal()
	end
	if(cam.fadeout>0) cam.fadeout-=.1

end

function round(num, numdecimalplaces)
  if numdecimalplaces and numdecimalplaces>0 then
    local mult = 10^numdecimalplaces
    return flr(num * mult + 0.5) / mult
  end
  return flr(num + 0.5)
end

clouds={}
clouds.list={}

function reset_game()
	player:init()
	cam.fadeout=1
	grasses.map={}
	levels.current.percent_complete=0
	levels.current.planted=0
	gametime=0

	truncate(grasses.map)
	truncate(bombs.list)
	truncate(specks.list)
	truncate(explosions.list)
end

function clouds:init()
	for i=1,45 do
		srand(i)
		local size=i/3
		self.list[i]={
			x=rnd(192)-size,
			y=rnd(192)-size,
			size=size
		}
	end
	--reset randomness seed
	srand(bnot(time()))
end

clouds.pattern1=0b1110111110111111
clouds.pattern2=0b0111111111011111

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
	local t=time()*10

	-- draw the clouds as circles 
	-- drifting in the x direction 
	-- over time and with parallax
	local cloudalt=true
	for cloud in all(self.list) do
			local cloudx, cloudy
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
			cloudx=cloud.x-((cam.x+t)*cloud.size*.01)%192

			cloudalt=not cloudalt
			if cloudalt then
				fillp(clouds.pattern1)
			else
				fillp(clouds.pattern2)
			end

			-- draw our circle, with a 
			-- 128 modulo so that it
			-- cycles through the left
			-- to right screen edges
			-- local dx=cloudx-player.x+cam.x-64
			-- local dy=cloudy-player.y+cam.y-64
			circfill(
				cloudx,
				cloudy,
				cloud.size,
				-- cloud.size*1.7-(abs(dx)+abs(dy))*.07,
				1)
	end

	fillp()
end


levels={
	index=1, -- current lvl index
	list={} 
}

-- find each level block, add
-- it to the list with coords
function levels:init()
	-- tile 6 is bottom right
	-- tile 7 is bottom left
	-- tile 8 is the top left
	-- tile 9 is top right
	for i=0,127 do
		for j=0,63 do
			if mget(i,j)==8 then
				levels:add(i,j)
			end -- if mget(i,j)
		end -- for j=0,31
	end -- for i=0,127
	levels.current=levels.list[1]
end -- levels:init

function levels:add(cx1,cy1)
	-- initialize the level object
	-- with initial coordinates
	-- from the top-left block
	local lvl={
		cx1=cx1,x1=cx1*8,
		cy1=cy1,y1=cy1*8
	}
	-- x/y = pixel coords
	-- cx/cy = map cell coords

	-- determine level bounds
	-- set the pixel bounds in x/y
	-- and cell bounds as cx/cy
	for cx2=cx1,127 do
		if mget(cx2,cy1)==9 then
			lvl.cx2=cx2
			lvl.x2=cx2*8
			break
		end
	end

	for cy2=cy1,63 do
		if mget(cx1,cy2)==7 then
			lvl.cy2=cy2
			lvl.y2=cy2*8
			break
		end
	end

-- determine the number of plantable blocks
lvl.plantable=0
lvl.planted=0
for y=cy1,lvl.y2/8 do
	for x=cx1,lvl.x2/8 do
		local t=mget(x,y)
		local at=mget(x,y-1)
		if t==1 or t==3 then
			if not iswall(at) and not is_spike(at) then
				lvl.plantable+=8
			end
		end
	end
end

	levels:set_spawn(lvl)
	lvl.percent_complete=0
	add(self.list,lvl)
	printh("level added:")
	printh("x1: "..lvl.x1)
	printh("y1: "..lvl.y1)
	printh("x2: "..lvl.x2)
	printh("y2: "..lvl.y2)
	printh("spawn x: "..lvl.spawnx)
	printh("spawn x: "..lvl.spawny)
end

function levels:set_spawn(lvl)
	-- find start sprite (#64) and
	-- set initial x/y position
	for i=lvl.x1/8,lvl.x2/8 do
		for j=lvl.y1/8,lvl.y2/8 do
			if mget(i,j)==64 then
				lvl.spawnx=i*8+3
				lvl.spawny=j*8
				mset(i,j,0)
				break
			end
		end
		if(player.x) break
	end
end

function levels:draw()
	map(
		self.current.cx1,self.current.cy1,
		self.current.x1,self.current.y1,
		self.current.cx2-self.current.cx1+1,
		self.current.cy2-self.current.cy1+1
	)
end

function levels:update()
	if gamestate ~= "game" then
		return false
	end
	local c=self.current
	if c.planted/c.plantable>=1 then
		levelcomplete:start()
	end
end

levelcomplete={lines={}}

levelcomplete.lines[1]={
	x1=-5,y1=-5,x2=24,y2=60,
	duration=40,dt=1,
	text="level complete",
	chars={}
}

function levelcomplete:start()
	gamestate="lvlcomplete"
	player.vx=0
	for line in all(self.lines) do
		line.dt=1
		for i=1,#line.text do
			local char={}
			local offset=(i-1)*10
			char.string=sub(line.text,i,i)

			char.x1=line.x1 + (10*(i-1))
			char.x2=line.x2 + (6*(i-1))
			char.y1=line.y1-offset
			char.y2=line.y2

			char.x=char.x1
			char.y=char.y1
			line.chars[i]=char
		end
	end
	music(10)
end

function levelcomplete:update()
	if gamestate~="lvlcomplete" then
		return false
	end

	for line in all(self.lines) do
		if line.dt < line.duration then
			line.dt+=1
			local t=line.dt/line.duration
			for char in all(line.chars) do
				local dx=char.x2-char.x1
				local dy=char.y2-char.y1
				char.x=char.x1+ease_out_quad(t)*dx
				char.y=char.y1+ease_out_quad(t)*dy
			end
		end
	end

	if btnp(4) then
		levels.index+=1
		levels.current=levels.list[levels.index]
		reset_game()
		gamestate="game"
	end

end

function levelcomplete:draw()
		if gamestate=="lvlcomplete" then
			for line in all(self.lines) do
				for char in all(line.chars) do
					local color={}
					if(line.dt/line.duration<=1)color=3
					if(line.dt/line.duration<0.6)color=2
					if(line.dt/line.duration<0.3)color=1
					rectfill(
						char.x-1,char.y-1,
						char.x+4,char.y+5,color)
					print(char.string,char.x,char.y,color+4)
				end
			end
		end
end

--------------------------------
-->8
--player object-----------------
player={}

function player:init()
	-- velocity
	player.vx=0
	player.vy=0

	--lists of our previous
	--positions/flippage for
	--effects rendering
	player.prevx=0
	player.prevy=0
	player.prevf=0

	--the "effects" timer
	player.etimer=0

	--the sprite is 3x5, so the
	--wr and hr dimensions are 
	--radii, and x/y is the
	--initial center position

	player.wr=1
	player.hr=2
	player.w=3
	player.h=5

	player.hit_jump=false

	--instantaneous jump velocity
	--the "power" of the jump
	player.jumpv=3

	--movement states
	player.standing=false
	player.wallsliding=false

	--what direction we're facing
	--1 or -1, used when we're 
	--facing away from a wall
	--while sliding
	player.facing=1

	--timers used for animation
	--states and particle fx
	player.falltimer=7
	player.landtimer=0
	player.runtimer=0
	player.headanimtimer=0
	player.throwtimer=0

	player.dead=false
	player.dying=false
	player.dying_timer=0

	player.spr=64
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

	player.x=levels.current.spawnx
	player.y=levels.current.spawny
	printh("--player init--")
	printh("player.x: "..player.x)
	printh("player.y: "..player.y)
	printh("cam.x: "..cam.x)
	printh("cam.y: "..cam.y)
end

function player:draw()
	if player.dying then
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
	if(player.dead) return false

	if player.dying then
		if player.dying_timer==0 then
			player.vx=0
		 if(gamestate=="game")reset_game()
		else
			player.dying_timer-=1
		end
		return false
	end

	self.standing=self.falltimer<7
	self.moving=nil
	--move the player, x then y
	self:handleinput()
	self:movex()
	self:movey()
	self:movejump()
	self:checksliding()
	self:effects()
end

function player:checksliding()
	self.wallsliding=false
	--hanging on wall to the right?
	if collide(self,'x',1) then
		self.wallsliding=true
		self.facing=-1
		if(self.vy>0) self.vy*=.97
	--hanging on wall to the left?
	elseif collide(self,'x',-1) then
		self.wallsliding=true
		self.facing=1
		if(self.vy>0) self.vy*=.97
	end
end

function player:handleinput()
	if(gamestate~="game") return
	if self.standing then
		self:groundinput()
	else
		self:airinput()
	end
	self:jumpinput()
	self:bombinput()

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
	elseif p.wallsliding then
	-- allow walljump if sliding
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
		if(p.vx>0) p.vx*=.9
		p.vx-=.2*dt
	--pressing right
	elseif btn(1) then
		p.flipx=false
		p.facing=1
		if(p.vx<0) p.vx*=.9
		p.vx+=.2*dt
	--pressing neither, slow down
	--by our friction amount
	else
		p.vx*=friction
	end
end --player.groundinput

function player.throw_flowerbomb(p)
	bombs:add(p.x, p.y-1)
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

function player:die()
	self.dying=true
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

--------------------------------
-->8
--collision code----------------

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

	-- query our 2 points to see
	-- what tile types they're in
	local tile1=mget(x1/8,y1/8)
	local tile2=mget(x2/8,y2/8)


if is_spike(tile1) or is_spike(tile2) then
	e:die()
end

	-- "nearonly" indicates we only
	-- want to know if our near
	-- corner will be in a wall
	if nearonly and iswall(tile1) and (tile1!=2 or y1%8<4) then
		return true
	end

	--if not nearonly, check if
	--either corner will hit a wall
	if not nearonly and (iswall(tile1) or iswall(tile2)) then 
		return true
	end

	--now check if we will hit any
	--moving platforms

	-- no hits detected
	return false
end

function iswall(tile)
 --we know our tile sprites
 --our stored in slots 1-7
 return tile>=1 and tile<=7
end

function is_spike(tile)
	return tile==48
end

--------------------------------
-->8
--effects-----------------------

--specks holds all particles to
--be drawn in our object loop
specks={list={}}
function specks:update()
	for speck in all(self.list) do
		speck.ox=speck.x
		speck.oy=speck.y
		speck.x+=speck.vx
		speck.y+=speck.vy
		speck.vx*=.85
		speck.vy*=.85
		speck.life-=1/30/speck.duration

		if speck.life<0 or
			iswall(mget(speck.x/8,speck.y/8))
		then
			del(self.list,speck)
		end
	end 
end

function specks:draw()
	for speck in all(self.list) do
		line(
			speck.x,
			speck.y,
			speck.ox,
			speck.oy,
			speck.c+(speck.life/2)*3
		)
	end
end

--------------------------------
-->8
--grass objects-----------------
grasses={
	map={},
	t=0,
	anim=0,
	sp=16
}

function grasses.update(g)
	if (g.t>60) g.t=0
	g.t+=1
	if g.t<15 then
		g.anim=1
	elseif g.t<30 then
		g.anim=0
	elseif g.t<45 then
		g.anim=2
	else
		g.anim=0
	end
end

function grasses.draw(g)
	for grass_row,grasses in pairs(g.map) do
		for grass_col,spx in pairs(grasses) do
			sspr(3*spx,8+2*g.anim,3,2,grass_col-1,grass_row)
		end
	end
end

function grasses.plant(x,y)
	local x=flr(x)
	local y=flr(y)
	-- start a new grass map row
	-- if necessary
	grasses.map[y]=grasses.map[y] or {}

	-- return if grass already at x
	if(grasses.map[y][x]) return false

	local tile1,tile2
	tile1=mget(x/8,y/8)
	tile2=mget(x/8,(y+2)/8)
	
	-- insert one of four possible
	-- flower types
	if iswall(tile2) and tile1~=48 and not iswall(tile1) then
		levels.current.planted+=1
		grasses.map[y][x]=flr(rnd(4))
	end
end


--------------------------------
-->8
--flower bombs------------------
--------------------------------
bombs={}
bombs.list={}

function bombs.draw(b)
	for bomb in all(b.list) do
		if bomb.dead or bomb.exploded then 
			goto bomb_draw_continue
		end

		local anim_frame=flr(bomb.anim_timer/3)
		local sx,sy
		if anim_frame<3 then
			sx=16+3*anim_frame
			sy=8
		elseif anim_frame<6 then
			sx=16+3*(anim_frame-3)
			sy=11
		else
			sx=16+3*(anim_frame-6)
			sy=14
		end
		sspr(sx,sy,3,3,bomb.x-1,bomb.y-1)

		::bomb_draw_continue::
	end
end

function bombs.update(b)
	for bomb in all(b.list) do

		if bomb.exploded then
			bombs.exploding(bomb)
		elseif bomb.dead then
			del(bombs.list,bomb)
		else
			bomb.anim_timer+=1
			if bomb.anim_timer>23 then
				bomb.anim_timer=0
			end
			local xsteps=abs(bomb.vx)*dt

			for i=xsteps,0,-1 do
				local step=min(i,1)*sgn(bomb.vx)
				if collide(bomb,'x',step) then
					bomb.vx=-bomb.vx/4
					break
				else
					bomb.x+=step
				end
			end -- bomb for xstep

			bomb.vy+=gravity*dt
			local ysteps=abs(bomb.vy)*dt
			for i=ysteps,0,-1 do
				local step=min(i,1)*sgn(bomb.vy)
				if collide(bomb,'y',step) then
					if bomb.vy>0 then
						bombs.explode(bomb)
					else
						bomb.vy=0
					end
					break
				else
					bomb.y+=step
				end
			end -- bomb for ystep
		end -- if bomb.exploded
	end -- bomb for loop
end -- bombs.update()

function bombs.add(b,x,y)
	local bomb={}
	bomb.wr=1
	bomb.hr=1
	bomb.x=x
	bomb.y=y
	bomb.vx=(0.2+rnd(1.5))*player.facing
	bomb.vy=-3
	bomb.anim_timer=0
	bomb.die=function(self) 
		self.dead=true 
	end
	add(b.list,bomb)
end

function bombs.explode(bomb)
	explosions.add(bomb.x,bomb.y,6)
	for i=bomb.x+9,bomb.x-9,-1 do
		grasses.plant(i,bomb.y)
	end
	bomb.exploded=1
	bomb.vx=0
	bomb.vy=0
	sfx(40)
	sfx(41)
	cam:shake(20,3)
end

function bombs.exploding(bomb)
		bomb.exploded+=1
		if bomb.exploded>8 then
			del(bombs.list,bomb)
		end
end

explosions={}
explosions.list={}

function explosions.update()
	for e in all(explosions.list) do
		if #e.sparks==0 then
			del(explosions.list,e)
		end

		for s in all(e.sparks) do
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
	for e in all(explosions.list) do
		for s in all(e.sparks) do
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
	end --for e in all(explosions.list)
		-- circfill(
		-- 	e.x,
		-- 	e.y,
		-- 	e.r*(e.life_r/e.life),
		-- 	7)
		-- end
end

function explosions.add(x,y,intensity)
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


--------------------------------
-->8
--intro object------------------
intro={}
intro.a=0
intro.r=2

function intro:init()
	music(1)
end

function intro:draw()

	-- print "press x to start"
	-- in a static position
	print(
		"press up to start",
		32,
		90,
		7
	)

	--draw "flamehead" swirling in
	--a circular pattern

	-- intro.a is the "angle"
	-- pico8 sin() and cos() range
	-- from 0-1 instead of 0-2ã as
	-- most calculators, so we
	-- increment intro.a by 2/360
	-- to advance our sin/cos funcs
	-- by 2 "degrees"
	intro.a+=2/360

	-- flip back from 1 to 0 since
	-- 2ã==0 for the purposes of
	-- sin/cos
	if(intro.a>1)intro.a=0

	-- from colors 10 down to 7
	-- (yellow down to white)
	for i=10,7,-1 do
		-- print the game title in
		-- gradually smaller circles
		-- based on our current i
		-- "intro.r" is just a 
		-- distance multiplier to
		-- separate the colors more
		print(
			"flowerhead", 
			52 + intro.r*i*sin(intro.a), 
			48 + intro.r*i*cos(intro.a), 
			i
		)
	end
end

function intro:update()
	if btnp(2) then
		gamestate="game"
		reset_game()
		music(0)
	end
end

--------------------------------
-->8
--camera------------------------
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
	self.x=mid(self.x,levels.current.x1+56,levels.current.x2-56)
	self.y=mid(self.y,levels.current.y1+56,levels.current.y2-56)
	--c.y=mid(c.y,64,64)
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
	-- return 0,0
end

function cam:shake(ticks, force)
	self.shake_remaining=ticks
	self.shake_force=force
end

function cam:draw()
	camera(cam:position())
end

--tutorials---------------------
--------------------------------
-- in game tutorial text
-- the index is the sprite num
tutorials={list={}}

tutorials.list[113]={
	lines={
		{c=8,t="hello! welcome to"},
		{c=8,t="flamehead, a platform"},
		{c=8,t="mechanics demo"},
		{c=9,t="get to the"},
		{c=9,t="top left corner"},
		{c=7,t="???? move"},
		{c=7,t="  ? jump"},
	}
}
tutorials.list[114]={
	lines={
		{c=7,t="? to walljump"} 
	}
}

function tutorials.init(t)

	for i=0,127 do
		for j=0,31 do
			local spr_num=mget(i,j)
			if t.list[spr_num] then
				t.list[spr_num].x=i*8+1
				t.list[spr_num].y=j*8
				mset(i,j,0)
			end
		end
	end
end

function tutorials.draw(t)
	for _,tut in pairs(t.list) do
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
		reset_game()
		gamestate="intro"
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

-- utility functions
--------------------------------
function truncate(tbl)
	for o in all(tbl) do
		del(tbl,o)
	end
end

-- easing function, meant to be
-- used with a num ranging 0-1
-- use for levelcomplete anim
function ease_out_quad(t)
	return t*(2-t)
end

__gfx__
00000000555555550005555555555555555550000000000055555000000555550000000000000000000000000000000000000000000000000000000000000000
000000005d5dd5650005d565565dd5d55d5650000000000055555000000555550000000000000000000000000000000000000000000000000000000000000000
00700700555555550005555555555555555550000000000055555000000555550000000000000000000000000000000000000000000000000000000000000000
000770005d5555d50005d5d55d5dd5655d5d50005555555555555000000555550005555555555000000000000000000000000000000000000000000000000000
000770005d5555d50005d5d5555555555d5d5000565dd5d555555000000555550005555555555000000000000000000000000000000000000000000000000000
00700700555555550005555500000000555550005555555500000000000000000005555555555000000000000000000000000000000000000000000000000000
00000000565dd5d5000565d500000000565d50005d5dd56500000000000000000005555555555000000000000000000000000000000000000000000000000000
00000000555555550005555500000000555550005555555500000000000000000005555555555000000000000000000000000000000000000000000000000000
0300700800a0000000b0000008888888000100000111000000000010000000000000000000000000000000000000000000000000000000000000000000000000
0b00300b0030000004004b0408888888000110000101100000000110000000000000000000000000000000000000000000000000000000000000000000000000
300700800a00000000000000b8888888000010000110100000001100111000000000000000000000000000000000000000000000000000000000000000000000
0b00300b003000000000000008888888000011000000111000111110001100000000000000000000000000000000000000000000000000000000000000000000
00300700800a0000040040b408888888000111100001110000101100011100000000000000000000000000000000000000000000000000000000000000000000
0b00300b003000000b0b000008888888111110100001100000001110010110000000000000000000000000000000000000000000000000000000000000000000
0000000000000000b000b00008888888001100000011110000001100001111000000000000000000000000000000000000000000000000000000000000000000
00000000000000000400400008888888011111100111111000011110011111100000000000000000000000000000000000000000000000000000000000000000
ddddddddcd1d1d1c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd11111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddd1111111d8888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd11111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddd1111111d8888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddd11111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddd1111111d8888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddddc1d1d1dc8888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07770070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57775677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
56775676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
56765666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
56665555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
08888888bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88000008bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88000000bbb8bbbbbbbbb8bbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888bbb8bbbbbbb8bbbbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000088bbb8bbbbbbb8bbbbbbbbb8bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88000088bbb8bbbbbbb888bbbbb888bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888880bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000131313131313131313131313131313130000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020101010000000000000000000000000000000000000000000000013131313401300
00000000000000000000000000000000000000131313131313131313131313131313130000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000013131313401300
00000000000000000000000000000000000000131313131313131313131313131313130000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000013131313401300
00000000000000000000000000000000000000131313131313131313131313131313130000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020101010101010000010000000000000000000000000000010101010101013401300
00000000000000000000000000000000000000131313131313131313131313131313130000000000000000000000000000000000000000131313131313131313
13131313131313000000000000000000000000000000000000000000000020000000000000000000000000100000001010101000000000000000131313401300
00000000000000000000000000000000000000131313131313131313131313131313130000000000000000000000000000000000000000000000000000000000
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
f0f0f0f0f0f00000000000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131313131313000000000013131313131313131313131313131313134013f0
f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131313131313131313137113135113131313131313131303030313134013f0
f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131313131313131313101010101010131313131313101010101013134013f0
f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131341130303031010101313131310101313131313000000000013134013f0
f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000201313131310101010101013131313131313131010131313131313131313134013f0
f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000010100000000000000000004000f0
f0f0f0f0f0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020030300000000000000000000000000000000131310101313131313131313401300
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000020101000000000000000000000000000000000131313131313101313131313401300
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
__label__
15555551155555511555555115555551000000000000000000000000000101011555555101010101010101000000000015555551155555510000000000000000
5d5dd5655d5dd5655d5dd5655d5dd565000000000000000000000000000010105d5dd5651010101010101000000000005d5dd5655d5dd5650000000000000000
55555555555555555555555555555555000000000000000000000000000101015555555501010101010100000000000055555555555555550000000000000000
5d5555d55d5555d55d5555d55d5555d5000000000000000000000000000010105d5555d50010101010101000000000005d5555d55d5555d50000000000000000
5d5555d55d5555d55d5555d55d5555d5000000000000000000000000000001015d5555d50001010101010000000000005d5555d55d5555d50000000000000000
55555555555555555555555555555555000000000000000000000000000000105555555500001010101000000000000055555555555555550000000000000000
565dd5d5565dd5d5565dd5d5565dd5d500000000000000000000000000000101565dd5d5000001010101000000000000565dd5d5565dd5d50000000000000000
15555551155555511555555115555551000000000000000000000000000010101555555110000000100000000000000015555551155555510000000000000000
15555551000000010101010115555551155555511555555115555551155555511555555100000000000000000000000000000000000000000000000000000000
5d5dd56500000010101010105d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd56510101010000000000000000000000000000000000000000000000000
55555555000000010101010155555555555555555555555555555555555555555555555501010101000000000000000000000000000000000000000000000000
5d5555d500000010101010105d5555d55d5555d55d5555d55d5555d55d5555d55d5555d510101010100000000000000000000000000000000000000000000000
5d5555d500000001010101015d5555d55d5555d55d5555d55d5555d55d5555d55d5555d501010101010000010101000000000000000000000000000000000000
55555555000000001010101055555555555555555555555555555555555555555555555510101010101000101010100000000000000000000000000000000000
565dd5d50000000001010101565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d501010101010101010101010100000000000000000000000000000000
15555551000000000010101015555551155555511555555115555551155555511555555110101010101010101010101010000000000000000000000000000000
15555551000000000001010100000000000000000000000000000000155555511555555115555551155555511555555115555551000000000000000000000000
5d5dd5650000000000000000000000000000000000000000000000005d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd565000000000000000000000000
55555555000000000000000000000000000000000000000000000000555555555555555555555555555555555555555555555555000001000000000000000000
5d5555d50000000000000000000000000000000000000000000000005d5555d55d5555d55d5555d55d5555d55d5555d55d5555d5000000000000000000000000
5d5555d50000000000000000000000000000000000000000000000005d5555d55d5555d55d5555d55d5555d55d5555d55d5555d5000000000000000000000000
55555555000000000000000000001010000000001010000000000000555555555555555555555555555555555555555555555555000000000000000000000000
565dd5d5000000000000000000010101000000010101000000000000565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5000000000000000000000000
15555551000000000000000000001010000000101010100000000000155555511555555115555551155555511555555115555551000000000000000000000000
15555551000000000000000000010101000001010101010000000000000000000000000000000000010101010101010115555551155555511555555100000000
5d5dd56500000000000000000000101000000010101010000000000000000000000000000000000000101010101010105d5dd5655d5dd5655d5dd56500000000
55555555000000000000000000000000000001010101010000000000000000000000000000000000000101010101010155555555555555555555555500000000
5d5555d500000000000000000000000000000010101010000000000000000000000000000000000000101010101010105d5555d55d5555d55d5555d500000000
5d5555d500000000000000000000000000000001010100000000000000000000000000000000000000010101010101015d5555d55d5555d55d5555d500000000
55555555000000000000000000000000000000001010000000000000000000000000000000000000000000101010100055555555555555555555555500000000
565dd5d50000000000000000000000000000000000000000000000000000000000000000000000000000000101010000565dd5d5565dd5d5565dd5d500000000
15555551000000000808088808001810008800800000080808880800008800880888088800000888008800000000000015555551155555511555555100000000
15555551000000000808080008010801080800800000080808000800080008080888080000000080080800000000000000000000000000001555555100000000
5d5dd565000000000888088008101810180800800000080808800800080008080808088000000080080800000000000000000000000000005d5dd56500000000
55555555000000000808080008010801080800000000088808000800080008080808080000000080080800000000000000000000000000005555555500000000
5d5555d5000000000808088818881888188000800000088808880888008808800808088800000080088000000000101010100000000000005d5555d500000000
5d5555d5000000000000000101010101010000000000000000000000000000000000000000000000000000000001010101010000000000005d5555d500000000
55555555000000000000001010101010101000000000000000000000000000000000000000000000000000000010101010101000000000005555555500000000
565dd5d500000000088808010888088808880808088808880880000000000888000008880800088808880888018808880888010000000000565dd5d500000000
15555551000000000800181018181888180008080800080808080000000008080000080808000808008008001818181818881010000000001555555100000000
15555551000000000881080108880808088008880880088808080000000008880000088808000888008008810808088108080101000000001555555100000000
5d5dd565000000000810181018181818180008080800080808080080000008080000080008000808008008101818181818181010100000005d5dd56500000000
55555555000000000801088808080808088808080888080808880800000008080000080008880808008008010881080808080101010000005555555500000000
5d5555d5000000000010101010101010100000000000000000000000000000000000000000000000000000101010101010101010100000005d5555d500000000
5d5555d5000000000101010101010101010000000000000000000000000000000000000000000000000001010101010101010101010000005d5555d500000000
55555555000000000888188810881818188808800888008800880000088008880888008800000000000000101010101010101010100000005555555500000000
565dd5d500000000088808010801080808080808008008000800000008080800088808080000000000000101010101010101010101000000565dd5d500000000
15555551000000000818188018101888188808080080080008880000080808800808080800000000000000101010101010101010100000001555555100000000
15555551000000000808080108010808080808080080080000080000080808000808080800000000000001010101010101010101010000001555555100000000
5d5dd565000000000808188810881818080808080888008808800000088808880808088000000000000000101010101010101010100000005d5dd56500000000
55555555000000000000010101010100000000000000000000000000000000000000000000000000000100010101010101010101000000005555555500000000
5d5555d5000000000000001010101000000000000000000000000000000000000000000000000000001010001010101010101010000000005d5555d500000000
5d5555d5000000000099099909990000099900990000099909090999000000000000000000000000000100000101010101010100000000005d5555d500000000
55555555000000000900090000900000009009090000009009090900000000000000000000000000000000000010101010101000000000005555555500000000
565dd5d500000000090009900090000000900909000000900999099000000000000000000000000000000000000101010101000000000000565dd5d500000000
15555551000000000909090000900000009009090000009009090900000000000000000000000000000000000000101010100000000000001555555100000000
15555551010100000999099900900000009009900000009009090999000000000000000000000000000000000000000000000000000000001555555100000000
5d5dd565101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d5dd56500000000
55555555010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555555500000000
5d5555d5101010101999009909990000090009990999099900000099009909990990099909990000000000000000000000000000000000005d5555d500000000
5d5555d5010101010190090909090000090009000900009000000900090909090909090009090000000000000000000000000000000000005d5555d500000000
55555555101010101090090919991000090009900990009000000900090909900909099009900000000000000000000000000000000000105555555500000000
565dd5d501010101019009090901010009000900090000900000090009090909090909000909000000000000000000000000000000000101565dd5d500000000
15555551101010101090099019101010099909990900009000000099099009090909099909090000000000000000000000000000000000101555555100000000
15555551010101010100010101010101000000000000000000000000000000000000000000000000000000000000000000000000000001011555555100000000
5d5dd565101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000105d5dd56500000000
55555555010101010177777101777771000007770077070707770000000000000000000000000000000000000000000000000000000000005555555500000000
5d5555d5101010101777107717701777100007770707070707000000000000000000000000000000000000000000000000000000000000005d5555d500000000
5d5555d5010101010770017707710177000007070707070707700000000000000000000000000000000000000000000000000000000000005d5555d500000000
55555555101010101777007717701777000007070707077707000000000000000000000000000000000000000000000000000000000000005555555500000000
565dd5d501010101007777710177777000000707077000700777000000000000000000000000000000000000000000000000000000000000565dd5d500000000
15555551101010100000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000001555555100000000
15555551010100000000000001010000000000000000000000000000000000000000000000000000000000000000000000000000000000001555555100000000
5d5dd565000000000000000000777770000007770707077707770000000000000000000000000000000000000000000000000000000000005d5dd56500000000
55555555000000000000000007707077000000700707077707070000000000000000000000000000000000000000000000000000000000005555555500000000
5d5555d5000000000000000007770777000000700707070707770000000000000000000000000000000000000000000000000000000000005d5555d500000000
5d5555d5000000000000000007707077000000700707070707000000000000000000010000000000000000000000000000000000000000005d5555d500000000
55555555000000000000000000777770000007700077070707000000000000000000000000000000000000000000000000000000000000005555555500000000
565dd5d500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000565dd5d500000000
15555551000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000001555555100000000
15555551000000000000000001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d5dd565000000000000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d5555d5000000000000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d5555d5000000000000000001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
565dd5d5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
15555551000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
15555551000000000000000000000000000000000000000000000000000000000000000000000000000000001555555115555551155555511555555115555551
5d5dd565000000000000000000000000000000000000000000000000000000000000000000000000000000005d5dd5655d5dd5655d5dd5655d5dd5655d5dd565
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000005555555555555555555555555555555555555555
5d5555d5000000000000000000000000000000000000000000000000000000000000000000000000000000005d5555d55d5555d55d5555d55d5555d55d5555d5
5d5555d5000000000000000000000000000000000000000000000000000000000000000000000000000000005d5555d55d5555d55d5555d55d5555d55d5555d5
55555555000000000000000000000000000000000000000000000000001000000000000000000000000000005555555555555555555555555555555555555555
565dd5d500000000000000000000000000000000000000000000000001010000000000000000000000000000565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5
15555551000000000000000000000000000000000000000000000000101010000000000000000000000000001555555115555551155555511555555115555551
15555551000000000000000000000000000000000000000000000001010101000000000000000000155555511555555100000000000000000000000000000000
5d5dd5650000000000000000000000000000000000000000000000001010100000000000000000105d5dd5655d5dd56500000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000010100000000000000010101555555555555555500000000000000000000000000000000
5d5555d50000000000000000000000000000000000000000000000000010000000000000000010105d5555d55d5555d500000000000000000000000000000000
5d5555d50000000000000000000000000000000000000000000000000000000000000000000101015d5555d55d5555d500000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000101010555555555555555500000000000000000000000000000000
565dd5d5000000000000000000000000000000000000000000000000000000000000000000010101565dd5d5565dd5d500000000000000000000000000000000
15555551000090000000000000000000000000000000000000000000000000000000000000001010155555511555555100777770000007770077000007070777
15555551000000000000000000000000000000000000000000000000000000001555555100010101155555511555555107707077000000700707000007070707
5d5dd565000000000000000000000000000000000000000000000000000000005d5dd565000000105d5dd5655d5dd56507770777000000700707000007070777
55555555000000000000000000000000000000000000000000000000000000015555555500000000555555555555555507707077000000700707000007770707
5d5555d5000000000000000000000000000000000000000000000000000000105d5555d5000000005d5555d55d5555d500777770000000700770000007770707
5d5555d5000000000000000000000000000000000000000000000000000001015d5555d5000000005d5555d55d5555d500000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000010105555555500000000555555555555555500000000000000000000000000000000
565dd5d500000000000000000000000000000000000000000000000000000101565dd5d500000000565dd5d5565dd5d500000000000000000000000000000000
15555551000000000000000000000000000000000000000000000000000010101555555100000000155555511555555100000000000000000000000000000000
15555551000000000000000000000000000000000000000015555551000001011555555100000000155555511555555100000000000000000000000000000000
5d5dd56500000000000000000000000000000000000000005d5dd565000000105d5dd565000000005d5dd5655d5dd56500000000000000000000000000000000
55555555000090000000000000000000000000000000000055555555000000015555555500000000555555555555555500000000000000000000000000000000
5d5555d50000000aa90000000000000000000000000000005d5555d5000000005d5555d5000000005d5555d55d5555d500000000000000000000000000000000
5d5555d500000000000000000000000000000000000000005d5555d5000000005d5555d5000000005d5555d55d5555d500000000000000000000000000000000
55555555000000066600000000000000000000000000000055555555000000005555555500000000555555555555555500000000000000000000000000000000
565dd5d50000000060000000000000000000000000000000565dd5d500000000565dd5d500000000565dd5d5565dd5d500000000000000000000000000000000
15555551000000060600000000000000000000000000000015555551000000001555555100000010155555511555555100000000000000000000000000000000
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
5d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd5655d5dd565
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
5d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d5
5d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d55d5555d5
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5565dd5d5
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0805050505050505050505050505050931313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000000000000000000000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000000000001010100000000000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0200000001000000000000000100000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0240000001303030303030300100000431313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0703030303030303030303030303030631313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000003131313131313131313131313131000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131313131313131
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000008050505050505050505050505050505050505050505050505050505050505093100
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000031313131043100
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000031313131043100
0000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000031313131313131313131313131313131000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000010101013131043100
__sfx__
000300201a000180001a0001800019000180001a000180001a0001800018000180001800018000180001800018000180001800018000180001800018000180001800018000180001800018000180001800000000
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
01 0506597f
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

