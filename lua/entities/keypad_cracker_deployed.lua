AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Spawnable = false
ENT.AdminSpawnable = false

local crackTimeCvar = CreateConVar("keypad_deployed_crack_time", "45", {FCVAR_ARCHIVE + FCVAR_REPLICATED}, "The number of seconds required for a deployed keypad cracker to crack a keypad.", 0)
local keypadPosOffset = Vector(1.25, -1.5, -1.25)
local keypadAngOffset = Angle(-90, 180, 0)

ENT.CrackerHealth = 50
ENT.BoxColor = Color(10, 10, 10, 200)
ENT.Dots = ""

ENT.SpawnSound = "NPC_CombineMine.CloseHooks"
ENT.RemoveSound = "NPC_CombineMine.OpenHooks"
ENT.DeathSound = "npc/assassin/ball_zap1.wav"
ENT.KeyCrackSound = "buttons/blip2.wav"
ENT.SuccessSound = "buttons/combine_button7.wav"
ENT.FailSound = "buttons/blip1.wav"
ENT.MiscSoundVolume = 0.35

-- Adapted from Wiremod's keypad code
local function crackWiremodKeypad(ent)
	WireLib.TriggerOutput(ent, "Valid", 1)
	ent:SetDisplayText("y")
	ent:EmitSound("buttons/button9.wav")

	ent.CurrentNum = -1

	timer.Simple(2, function()
		if IsValid(ent) then
			ent:SetDisplayText("")
			ent.CurrentNum = 0

			WireLib.TriggerOutput(ent, "Valid", 0)
		end
	end)
end

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

	local curTime = CurTime()
	self.StartCrack = curTime
	self.EndCrack = curTime + crackTime

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
				local soundPitch = Lerp((CurTime() - self.StartCrack) / crackTime, 75, 125)
				self:EmitSound(self.KeyCrackSound, 100, soundPitch, 1)

				if timer.RepsLeft(timerName) == 0 then
					if keypad:GetClass() == "gmod_wire_keypad" then
						crackWiremodKeypad(keypad)
					else
						keypad:Process(true, owner)
					end

					self:EndCracking(false)
				end
			end
		end)
	else
		timer.Create(timerName, 0.5, crackTime * 2, function()
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
	effect:SetScale(2)
	util.Effect(effectName, effect, true, true)

	self:EmitSound(soundName)
	self:GetKeypad().IsBeingCracked = false

	timer.Simple(0, function()
		if IsValid(self) then
			self:Remove()
		end
	end)
end

function ENT:Use(activator)
	if activator ~= self:GetCrackerOwner() then return end

	self:EmitSound(self.RemoveSound)
	self:EmitSound(self.FailSound, 100, 50, self.MiscSoundVolume)
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
	self:EmitSound("npc/scanner/scanner_pain" .. math.random(1, 2) .. ".wav", 100, 100, 0.45)
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
	cam.Start3D2D(pos - ang:Right() * 3 + ang:Up() * 8.9 + ang:Forward() * 3.67, ang, 0.005)

	local frac = math.Clamp((curTime - self.StartCrack) / (self.EndCrack - self.StartCrack), 0, 1)
	local dots = self.Dots or ""
	local x, y = -340, -35
	local w, h = 1090, 100
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