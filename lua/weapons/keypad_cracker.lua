-- This is sorta horrible

AddCSLuaFile()

local keypad_crack_time = CreateConVar("keypad_crack_time", "30", {FCVAR_ARCHIVE}, "The number of seconds required for a keypad cracker to crack a keypad.", 0)

SWEP.PrintName = "Keypad Cracker"
SWEP.Slot = 4
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Author = "Willox"
SWEP.Instructions = "Left click to crack keypad.\nRight click to deploy a cracker.\nHit Use on your deployed cracker to pick it up."
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.IconOverride = "spawnicons/models/weapons/w_c4_planted.png"

SWEP.ViewModelFOV = 62
SWEP.ViewModelFlip = false
SWEP.ViewModel = Model("models/weapons/cstrike/c_c4.mdl")
SWEP.WorldModel = Model("models/weapons/w_c4.mdl")
SWEP.UseHands = true

SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.AnimPrefix = "python"

SWEP.Sound = "weapons/deagle/deagle-1.wav"

SWEP.AttackTimer = 0.4
SWEP.AttackDistance = 50

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.KeyCrackSound = "buttons/blip2.wav"
SWEP.CantUseSound = "buttons/combine_button_locked.wav"
SWEP.FailSound = "buttons/blip1.wav"
SWEP.MiscSoundVolume = 0.35

SWEP.IdleStance = "slam"

local crackableClasses = {
	["keypad"] = true,
	["keypad_wire"] = true,
	["gmod_wire_keypad"] = true, -- Wiremod's own keypad
}

function SWEP:Initialize()
	self:SetHoldType(self.IdleStance)

	if SERVER then
		net.Start("KeypadCracker_Hold")
			net.WriteEntity(self)
			net.WriteBit(true)
		net.Broadcast()

		self:SetCrackTime(keypad_crack_time:GetInt())
	end
end

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "CrackTime")
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.AttackTimer)

	local owner = self:GetOwner()
	if self.IsCracking or not IsValid(owner) then return end
	if owner:GetNWBool("_Kyle_Buildmode", false) then return end -- Only allow use while in PVP

	local tr = owner:GetEyeTrace()
	local ent = tr.Entity
	local withinRange = tr.HitPos:Distance(owner:GetShootPos()) <= self.AttackDistance
	local inBuild = owner:GetNWBool("_Kyle_Buildmode", false) -- Only allow use while in PVP

	if IsValid(ent) and withinRange and not inBuild and crackableClasses[ent:GetClass():lower()] and not ent.IsBeingCracked then
		local crackTime = keypad_crack_time:GetInt()
		local entindex = self:EntIndex()

		self.IsCracking = true
		self.StartCrack = CurTime()
		self.EndCrack = CurTime() + crackTime

		self:SetCrackTime(crackTime)
		self:SetWeaponHoldType("pistol") -- TODO: Send as networked message for other clients to receive
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

		if SERVER then
			net.Start("KeypadCracker_Hold")
				net.WriteEntity(self)
				net.WriteBit(true)
			net.Broadcast()

			timer.Create("KeyCrackSounds: " .. entindex, 1, crackTime, function()
				if IsValid(self) and self.IsCracking then
					local soundPitch = Lerp((CurTime() - self.StartCrack) / crackTime, 75, 125)
					-- Setting the channel prevents the viewmodel sounds from interfering with these ones
					self:EmitSound(self.KeyCrackSound, 100, soundPitch, 1, CHAN_AUTO)
				end
			end)

			timer.Create("KeyCrackAnims: " .. entindex, 2.75, crackTime, function()
				if IsValid(self) and self.IsCracking then
					self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
				end
			end)
		else
			self.Dots = self.Dots or ""

			timer.Create("KeyCrackDots: " .. entindex, 0.5, 0, function()
				if not IsValid(self) then
					timer.Remove("KeyCrackDots: " .. entindex)
				else
					local len = string.len(self.Dots)
					local dots = {[0] = ".", [1] = "..", [2] = "...", [3] = ""}

					self.Dots = dots[len]
				end
			end)
		end
	else
		self:EmitSound(self.CantUseSound, 100, 100, self.MiscSoundVolume)
	end
end

function SWEP:SecondaryAttack()
	local curTime = CurTime()
	self:SetNextSecondaryFire(curTime + self.AttackTimer)

	local owner = self:GetOwner()
	if self.IsCracking or not IsValid(owner) then return end

	local tr = owner:GetEyeTrace()
	local ent = tr.Entity
	local withinRange = tr.HitPos:Distance(owner:GetShootPos()) <= self.AttackDistance
	local inBuild = owner:GetNWBool("_Kyle_Buildmode", false) -- Only allow use while in PVP

	if IsValid(ent) and withinRange and not inBuild and crackableClasses[ent:GetClass():lower()] and not ent.IsBeingCracked then
		owner:SetAnimation(PLAYER_ATTACK1)
		self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
		self:SetNextPrimaryFire(curTime + 1)
		self:SetNextSecondaryFire(curTime + 1)
		self:EmitSound("buttons/button6.wav", 100, 100, 0.35)

		timer.Simple(0.5, function()
			if CLIENT or not IsValid(self) or self.IsCracking then return end
			if not IsValid(ent) or ent.IsBeingCracked then return end

			local cracker = ents.Create("keypad_cracker_deployed")
			cracker:SetKeypad(ent)
			cracker:SetCrackerOwner(owner)
			cracker:Spawn()

			ent.IsBeingCracked = true
			owner:StripWeapon("keypad_cracker")
		end)
	else
		self:EmitSound(self.CantUseSound, 100, 100, 0.35)
	end
end

function SWEP:Deploy()
	self:EmitSound("npc/roller/mine/combine_mine_deploy1.wav", 75, 100, self.MiscSoundVolume)
end

function SWEP:Holster()
	self.IsCracking = false
	self:EmitSound("npc/roller/mine/combine_mine_deactivate1.wav", 75, 100, self.MiscSoundVolume)

	local entIndex = self:EntIndex()

	if SERVER then
		timer.Remove("KeyCrackSounds: " .. entIndex)
		timer.Remove("KeyCrackAnims: " .. entIndex)
	else
		timer.Remove("KeyCrackDots: " .. entIndex)
	end

	return true
end

function SWEP:Reload()
	return true
end

-- Adapted from Wiremod's keypad code
local function crackWiremodKeypad(ent)
	Wire_TriggerOutput(ent, "Valid", 1)
	ent:SetDisplayText("y")
	ent:EmitSound("buttons/button9.wav")

	ent.CurrentNum = -1

	timer.Simple(2, function()
		if IsValid(ent) then
			ent:SetDisplayText("")
			ent.CurrentNum = 0

			Wire_TriggerOutput(ent, "Valid", 0)
		end
	end)
end

function SWEP:Succeed()
	self.IsCracking = false

	local owner = self:GetOwner()
	local tr = owner:GetEyeTrace()
	local ent = tr.Entity

	self:SetWeaponHoldType(self.IdleStance)
	self:SendWeaponAnim(ACT_VM_IDLE)

	if SERVER and IsValid(ent) and tr.HitPos:Distance(owner:GetShootPos()) <= self.AttackDistance and crackableClasses[ent:GetClass():lower()] then
		if ent:GetClass() == "gmod_wire_keypad" then
			crackWiremodKeypad(ent)
		else
			ent:Process(true, owner)
		end

		net.Start("KeypadCracker_Hold")
			net.WriteEntity(self)
			net.WriteBit(true)
		net.Broadcast()

		net.Start("KeypadCracker_Sparks")
			net.WriteEntity(ent)
		net.Broadcast()
	end

	local entIndex = self:EntIndex()

	if SERVER then
		timer.Remove("KeyCrackSounds: " .. entIndex)
		timer.Remove("KeyCrackAnims: " .. entIndex)
	else
		timer.Remove("KeyCrackDots: " .. entIndex)
	end
end

function SWEP:Fail()
	self.IsCracking = false

	local entIndex = self:EntIndex()

	self:SetWeaponHoldType(self.IdleStance)
	self:SendWeaponAnim(ACT_VM_IDLE)
	self:EmitSound(self.FailSound, 100, 50, self.MiscSoundVolume)

	if SERVER then
		net.Start("KeypadCracker_Hold")
			net.WriteEntity(self)
			net.WriteBit(true)
		net.Broadcast()

		timer.Remove("KeyCrackSounds: " .. entIndex)
		timer.Remove("KeyCrackAnims: " .. entIndex)
	else
		timer.Remove("KeyCrackDots: " .. entIndex)
	end
end

function SWEP:Think()
	if not self.StartCrack then
		self.StartCrack = 0
		self.EndCrack = 0
	end

	local owner = self:GetOwner()

	if self.IsCracking and IsValid(owner) then
		local tr = owner:GetEyeTrace()

		if not IsValid(tr.Entity) or tr.HitPos:Distance(owner:GetShootPos()) > self.AttackDistance or not crackableClasses[tr.Entity:GetClass():lower()] then
			self:Fail()
		elseif self.EndCrack <= CurTime() then
			self:Succeed()
		end
	else
		self.StartCrack = 0
		self.EndCrack = 0
	end

	self:NextThink(CurTime())
	return true
end

if CLIENT then
	SWEP.BoxColor = Color(10, 10, 10, 200)

	-- HUD code adapted from https://github.com/AbstractDimension/gmod-keypad/blob/master/lua/weapons/keypad_cracker.lua#L201
	function SWEP:PostDrawViewModel(vm)
		if not self.IsCracking then return end

		local curTime = CurTime()

		if not self.StartCrack then
			self.StartCrack = curTime
			self.EndCrack = curTime + self:GetCrackTime()
		end

		if not IsValid(vm) then return end

		local bone = vm:LookupBone("v_weapon.c4")
		if not bone then return end

		local pos, ang = vm:GetBonePosition(bone)
		if not pos then return end

		ang:RotateAroundAxis(ang:Right(), 180)
		ang:RotateAroundAxis(ang:Forward(), -90)
		cam.Start3D2D(pos - ang:Right() * 0.75 + ang:Up() * 3.65 + ang:Forward() * 4.33, ang, 0.005)

		local frac = math.Clamp((curTime - self.StartCrack) / (self.EndCrack - self.StartCrack), 0, 1)
		local dots = self.Dots or ""
		local x, y = -340, -35
		local w, h = 680, 100
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

	SWEP.DownAngle = Angle(-10, 0, 0)
	SWEP.LowerPercent = 1
	SWEP.SwayScale = 0

	function SWEP:GetViewModelPosition(pos, ang)
		if self.IsCracking then
			local delta = FrameTime() * 3.5
			self.LowerPercent = math.Clamp(self.LowerPercent - delta, 0, 1)
		else
			local delta = FrameTime() * 5
			self.LowerPercent = math.Clamp(self.LowerPercent + delta, 0, 1)
		end

		ang:RotateAroundAxis(ang:Forward(), self.DownAngle.p * self.LowerPercent)
		ang:RotateAroundAxis(ang:Right(), self.DownAngle.p * self.LowerPercent)

		return self.BaseClass.GetViewModelPosition(self, pos, ang)
	end

	net.Receive("KeypadCracker_Hold", function()
		local ent = net.ReadEntity()
		local state = (net.ReadBit() == 1)
		local allowed = {
			["money_holder"] = true,
			["keypad_cracker"] = true,
		}

		if IsValid(ent) and allowed[ent:GetClass():lower()] and not game.SinglePlayer() and ent.SetWeaponHoldType then
			if not state then
				ent:SetWeaponHoldType(ent.IdleStance)
				ent.IsCracking = false
			else
				ent:SetWeaponHoldType("pistol")
				ent.IsCracking = true
			end
		end
	end)

	net.Receive("KeypadCracker_Sparks", function()
		local ent = net.ReadEntity()

		if IsValid(ent) then
			local vPoint = ent:GetPos()
			local effect = EffectData()
			effect:SetStart(vPoint)
			effect:SetOrigin(vPoint)
			effect:SetEntity(ent)
			effect:SetScale(2)
			util.Effect("cball_bounce", effect)

			ent:EmitSound("buttons/combine_button7.wav", 100, 100)
		end
	end)
end