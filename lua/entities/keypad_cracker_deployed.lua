AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Spawnable = false
ENT.AdminSpawnable = false

local crackTimeCvar = CreateConVar("keypad_deployed_crack_time", "45", {FCVAR_ARCHIVE}, "The number of seconds required for a deployed keypad cracker to crack a keypad.")
local keypadPosOffset = Vector(1.25, -1.5, -1.25)
local keypadAngOffset = Angle(-90, 180, 0)

ENT.CrackerHealth = 25
ENT.BoxColor = Color(10, 10, 10, 200)
ENT.Dots = ""

ENT.SpawnSound = "NPC_CombineMine.CloseHooks"
ENT.RemoveSound = "NPC_CombineMine.OpenHooks"
ENT.DeathSound = "npc/assassin/ball_zap1.wav"
ENT.KeyCrackSound = "buttons/blip2.wav"
ENT.SuccessSound = "buttons/combine_button7.wav"

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Keypad")
	self:NetworkVar("Float", 0, "CrackTime")
	self:NetworkVar("Entity", 1, "CrackerOwner")
end

function ENT:Initialize()
	local keypad = self:GetKeypad()
	if not IsValid(keypad) then return end

	self:SetModel("models/weapons/w_c4_planted.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetPos(keypad:LocalToWorld(keypadPosOffset))
	self:SetAngles(keypad:LocalToWorldAngles(keypadAngOffset))
	self:SetParent(keypad)
	self:EmitSound(self.SpawnSound)

	local crackTime = crackTimeCvar:GetInt()
	local timerName = "KeyCrackDeployed: " .. self:EntIndex()
	self:SetCrackTime(crackTime)

	if SERVER then
		self:SetMaxHealth(self.CrackerHealth)
		self:SetHealth(self.CrackerHealth)
		self:SetUseType(SIMPLE_USE)

		if CPPI then
			self:CPPISetOwner(self:GetCrackerOwner())
		end

		keypad:DeleteOnRemove(self)

		timer.Create(timerName, 1, crackTime, function()
			if not IsValid(self) or not IsValid(keypad) then
				timer.Remove(timerName)
			else
				self:EmitSound(self.KeyCrackSound, 100, 100)

				if timer.RepsLeft(timerName) == 0 then
					keypad:Process(true, owner)
					self:EndCracking(false)
				end
			end
		end)
	else
		timer.Create(timerName, 0.5, crackTime, function()
			if not IsValid(self) then
				timer.Remove(timerName)
			else
				local len = string.len(self.Dots)
				local dots = {[0] = ".", [1] = "..", [2] = "...", [3] = ""}

				self.Dots = dots[len]
			end
		end)
	end
end

function ENT:EndCracking(wasKilled)
	local effectName = wasKilled and "cball_explode" or "cball_bounce"
	local soundName = wasKilled and self.DeathSound or self.SuccessSound

	local pos = self:GetPos()
	local effect = EffectData()
	effect:SetStart(pos)
	effect:SetOrigin(pos)
	util.Effect(effectName, effect, true, true)

	self:EmitSound(soundName)
	self:GetKeypad().IsBeingCracked = false
	self:Remove()
end

function ENT:Use(activator)
	if activator ~= self:GetCrackerOwner() then return end

	self:EmitSound(self.RemoveSound)
	self:GetKeypad().IsBeingCracked = false
	self:Remove()
	activator:Give("keypad_cracker")
	activator:SelectWeapon("keypad_cracker")
end

function ENT:OnTakeDamage(dmg)
	local oldHealth = self:Health()
	if oldHealth <= 0 then return end

	local newHealth = oldHealth - dmg:GetDamage()
	self:SetHealth(newHealth)
	if newHealth > 0 then return end

	self:EndCracking(true)
end

function ENT:Draw()
	self:DrawModel()

	local curTime = CurTime()

	if not self.StartCrack then
		self.StartCrack = curTime
		self.EndCrack = curTime + self:GetCrackTime()
	end

	local bone = self:LookupBone("mesh")
	if not bone then return end

	local pos, ang = self:GetBonePosition(bone)
	if not pos then return end

	ang:RotateAroundAxis(ang:Right(), 180)
	ang:RotateAroundAxis(ang:Forward(), 180)
	cam.Start3D2D(pos - ang:Right() * 3 + ang:Up() * 8.8 + ang:Forward() * 3.67, ang, 0.005)

	local frac = math.Clamp((curTime - self.StartCrack) / (self.EndCrack - self.StartCrack), 0, 1)
	local dots = self.Dots or ""
	local x, y = -340, -35
	local w, h = 1080, 100
	draw.RoundedBox(4, x, y, w, h, self.BoxColor)
	surface.SetDrawColor(Color(255 + frac * -255, frac * 255, 40))
	surface.DrawRect(x + 5, y + 5, frac * (w - 10), h - 10)
	surface.SetFont("KeypadCrack")

	local fontw, fonth = surface.GetTextSize("Cracking")
	local fontx, fonty = (x + w / 2) - fontw / 2, (y + h / 2) - fonth / 2

	surface.SetTextPos(fontx, fonty - 120)
	surface.SetTextColor(color_black)
	surface.DrawText("Cracking" .. dots)
	surface.SetTextPos(fontx, fonty - 120)
	surface.SetTextColor(color_white)
	surface.DrawText("Cracking" .. dots)

	local timeLeft = math.Round(self.EndCrack - curTime, 1)
	surface.SetFont("KeypadCrackNumbers")
	surface.SetTextPos(fontx - 90, fonty + 110)
	surface.SetTextColor(color_black)
	surface.DrawText(timeLeft .. " seconds left")
	surface.SetTextPos(fontx - 90, fonty + 110)
	surface.SetTextColor(color_white)
	surface.DrawText(timeLeft .. " seconds left")

	cam.End3D2D()
end