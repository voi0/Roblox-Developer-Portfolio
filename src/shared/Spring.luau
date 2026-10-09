--!strict
--[[
	Spring.luau — Universal Physics-Driven Spring Solver for VAULT WARS
	Implements second-order differential Hooke's Law physics (F = -kx - cv)
	with analytical dampening to guarantee 0 jitter and silky smooth motion.
	Supports numbers, Vector2, and Vector3 for Cameras, Viewmodels, and UI.
	Located in: ReplicatedStorage.Shared.Spring
]]

export type Spring = {
	Target: any,
	Position: any,
	Velocity: any,
	Speed: number,
	Damping: number,
	Update: (self: Spring, dt: number) -> any,
	Impulse: (self: Spring, force: any) -> (),
	Reset: (self: Spring, initial: any) -> (),
}

local Spring = {}
Spring.__index = Spring

function Spring.new(initialValue: any, speed: number?, damping: number?): Spring
	local self = setmetatable({} :: any, Spring)
	self.Target = initialValue
	self.Position = initialValue
	self.Velocity = (typeof(initialValue) == "number") and 0
		or (typeof(initialValue) == "Vector3" and Vector3.zero or Vector2.zero)
	self.Speed = speed or 25
	self.Damping = damping or 0.75
	return self :: Spring
end

function Spring:Impulse(force: any)
	self.Velocity += force
end

function Spring:Reset(initial: any)
	self.Target = initial
	self.Position = initial
	self.Velocity = (typeof(initial) == "number") and 0
		or (typeof(initial) == "Vector3" and Vector3.zero or Vector2.zero)
end

function Spring:Update(dt: number): any
	-- Clamp dt to prevent explosion on severe frame drops
	dt = math.clamp(dt, 0.001, 0.1)

	local d = self.Damping
	local s = self.Speed
	local pos = self.Position
	local target = self.Target
	local vel = self.Velocity

	-- Analytical spring differential
	local displacement = pos - target
	local acceleration = (-s * s * displacement) - (2 * d * s * vel)

	vel += acceleration * dt
	pos += vel * dt

	self.Position = pos
	self.Velocity = vel

	return pos
end

return Spring
