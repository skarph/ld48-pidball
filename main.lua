DEBUG = false
PAUSE = false

local highscore = 0
local hsDisp = "000"

--helper functions
local function clamp(x,max,min)
    if(x<min) then return min end
    if(x>max) then return max end
    return x
end

local function pointInCircle(x,y,cx,cy,cr)
    local dx, dy = x - cx, y - cy
    return dx*dx + dy*dy < cr*cr
end

local function generatePoly(x,y,r,s)
    local p = {}
    for i=1,s do
        p[2*i-1] = math.cos(2*math.pi*(i-1)/s - 0.5*math.pi)*r + x
        p[2*i] = math.sin(2*math.pi*(i-1)/s - 0.5*math.pi)*r + y
    end
    return p
end

--Dial class 
local Dial = {
    inArea = function(self,x,y)
        return pointInCircle(x,y,self.x,self.y,self.r)
    end,

    updateIsHeld = function(self,x,y)
        self.held = pointInCircle(x,y,self.x,self.y,self.r)
    end,

    getValue = function(self) --normalized from 0 to 1
        return (self.rot-self.cMin)/(self.cMax-self.cMin)
    end,

    update = function(self) -- main function
        if(not self.held) then return end
        if(self.isBig) then
            self.rot = (math.atan2(love.mouse.getY() - self.y,love.mouse.getX() - self.x) + 0.5*math.pi) % (2*math.pi)
        else
            self.rot = (math.atan2(love.mouse.getY() - self.y,love.mouse.getX() - self.x) + math.pi) - 0.5*math.pi
        end
        if(self.cMin) then self.rot = clamp(self.rot,self.cMax,self.cMin) end
    end,

    draw = function(self,debug)
        if(debug) then
            love.graphics.circle("fill",self.x,self.y,self.r)
        end
        love.graphics.draw(self.img,self.x,self.y,self.rot,4,4,self.disp,self.disp)
    end
}
Dial.__index = Dial

local function newDial(x,y,r, isBig, cMin,cMax, initRot)
    local t = {x=x,y=y,r=r,rot=initRot or 0,held=false,cMin=cMin,cMax=cMax,isBig=isBig}
    if(isBig) then
        t.disp = 19.5
        t.img = bigDialImg
    else
        t.disp = 8.5
        t.img = dialImg
    end
    setmetatable(t,Dial)
    return t
end

--vector drawer, draw area is (rounded square) from 40, 44 to 548, 552
local vectorCanvas = love.graphics.newCanvas()
local GREEN = {0,1,0.5,1} --green color
local WHITE = {1,1,1,1} --white color

local function drawPoly(p)
    local tp = {}
    for k,v in ipairs(p) do
        tp[k] = 4*v + 40 + 4*(k%2) --add 40 or 44 depending on whether x or y. [0-127] to [40-548]
    end
    love.graphics.polygon("line",tp)
end

local function drawPolyFixture(f)
    drawPoly( {f:getBody():getWorldPoints(f:getShape():getPoints())} )
end

local function updatePID(p,i,d,current,dt)
    local cE = target-current
    if(math.abs(cE) > 2*math.pi - math.abs(cE)) then cE = 2*math.pi - cE end
    local val = p*cE + i*accumulator + d*(cE-pE)/dt
    accumulator = accumulator + cE*dt
    pE = cE
    return val
end

local function setTarget(t,current)
    target = t
    pE = target - current
    if(math.abs(pE) > 2*math.pi - math.abs(pE)) then pE = 2*math.pi - pE end
end

--main game loop(s)
local function reset() --reset gamestate, poorly
    bigDial = newDial(171*4-2,54*4-2, 70, true)
    pDial = newDial(149*4-2,103*4-2, 32.5, false, -0.5*math.pi, 0.5*math.pi, -0.5*math.pi)
    iDial = newDial(170*4-2,103*4-2, 32.5, false, -0.5*math.pi, 0.5*math.pi, -0.5*math.pi)
    dDial = newDial(190*4-2,103*4-2, 32.5, false, -0.5*math.pi, 0.5*math.pi, -0.5*math.pi)
    --physics systems/objects
    World = love.physics.newWorld(0,0, true)

    --drill
    ballBody = love.physics.newBody(World,64,-30,"dynamic")
    ballShape = love.physics.newCircleShape(5)
    ballFixture = love.physics.newFixture(ballBody,ballShape,10)

    --planet mechanics
    planetBody = love.physics.newBody(World,64,64,"dynamic")
    planetShape = love.physics.newPolygonShape(generatePoly(0,0,40,7))
    planetFixture = love.physics.newFixture(planetBody,planetShape,1)
    planetBody:setMass(0.1)

    --pid control
    accumulator = 0
    pE = 2*math.pi
    target = 2*math.pi
    --timer
    time = 0
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest", 1);

    consoleImg = love.graphics.newImage("console.png")
    bigDialImg = love.graphics.newImage("dialbig.png")
    dialImg = love.graphics.newImage("dial.png")
    reset()
end


function love.update(dT)
    
    bigDial:update()
    pDial:update()
    iDial:update()
    dDial:update()
    
    if(PAUSE) then return end

    time = time + dT
    ballShape:setRadius(400 + time*0.5)
    ballBody:applyForce(0,10)

    p,i,d = 100*pDial:getValue(),20*iDial:getValue(),100*dDial:getValue()
    torque = updatePID(p,i,d,planetBody:getAngle() % (2*math.pi),dT)
    planetBody:applyTorque(300*torque)
    planetBody:setLinearVelocity(0,0)
    planetBody:setPosition(64,64)
    World:update(dT)

    if(ballBody:getY()>200) then
        hsDisp = frmtstr
        reset()
    end
end

function love.draw()
    love.graphics.setColor(0,0.1,0.1,1)
    love.graphics.rectangle("fill",0,0,800,600)
    --draw to the miniscreen
    love.graphics.setColor(GREEN)
    for k,b in ipairs(World:getBodies()) do
        for j,f in ipairs(b:getFixtures()) do
            if(f:getShape().getPoints) then
               drawPolyFixture(f)
            else
                local x,y = f:getBody():getPosition()
                love.graphics.circle("line",4*x+40,4*y+44,4*f:getShape():getRadius())
            end
        end
    end
    frmtstr = tostring(math.floor(time))
    if(#frmtstr==1) then frmtstr = "00"..frmtstr
    elseif(#frmtstr==2) then frmtstr = "0"..frmtstr
    end
    love.graphics.print("     "..frmtstr.."\nHI: "..hsDisp,70,90,0,2)
    love.graphics.setColor(WHITE)
    --background
    love.graphics.draw(consoleImg,0,0,0,4,4)
    --big dial
    bigDial:draw(DEBUG)
    
    --lil dials, from left to right
    pDial:draw(DEBUG)
    iDial:draw(DEBUG)
    dDial:draw(DEBUG)
    love.graphics.setColor(0,0,0,1)
    [[love.graphics.print(
        "p,i,d: "..(math.floor(p*10)*0.1)..","..(math.floor(i*10)*0.1)..","..(math.floor(d*10)*0.1)..
        "\naccumulator"..accumulator..
        "\ntarget: "..target..
        "\ncurrent: "..(planetBody:getAngle() % (2*math.pi))..
        "\npreErr: "..pE..
        "\ntorque: "..(torque)
    )]]
end

function love.keypressed(key, scancode, isrepeat)
    if(key=="space") then PAUSE = not PAUSE end
end  


function love.mousepressed(x,y,button,istouch,presses)
    bigDial:updateIsHeld(x,y)
    pDial:updateIsHeld(x,y)
    iDial:updateIsHeld(x,y)
    dDial:updateIsHeld(x,y)
end

function love.mousereleased(x,y,button,istouch,presses)
    bigDial.held = false
    pDial.held = false
    iDial.held = false
    dDial.held = false
    setTarget(bigDial.rot,planetBody:getAngle() % (2*math.pi))
end

function love.mousemoved(x,y,dx,dy,istouch)

end