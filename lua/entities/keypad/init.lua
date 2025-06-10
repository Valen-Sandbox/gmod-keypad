AddCSLuaFile "cl_init.lua"
AddCSLuaFile "cl_maths.lua"
AddCSLuaFile "cl_panel.lua"
AddCSLuaFile "sh_init.lua"

include "sh_init.lua"

function ENT:SetValue(val)
	self.Value = val

	if self:GetSecure() then
		self:SetText(string.rep("*", #val))
	else
		self:SetText(val)
	end
end

function ENT:GetValue()
	return self.Value
end

function ENT:Process(granted)
	local length, repeats, delay, initdelay, key, outputKey

	if(granted) then
		self:SetStatus(self.Status_Granted)

		length = self.KeypadData.LengthGranted
		repeats = math.min(self.KeypadData.RepeatsGranted, 50)
		delay = self.KeypadData.DelayGranted
		initdelay = self.KeypadData.InitDelayGranted
		key = tonumber(self.KeypadData.KeyGranted) or 0
		outputKey = "Access Granted"
	else
		self:SetStatus(self.Status_Denied)

		length = self.KeypadData.LengthDenied
		repeats = math.min(self.KeypadData.RepeatsDenied, 50)
		delay = self.KeypadData.DelayDenied
		initdelay = self.KeypadData.InitDelayDenied
		key = tonumber(self.KeypadData.KeyDenied) or 0
		outputKey = "Access Denied"
	end

	local owner = self:GetKeypadOwner()

	timer.Simple(math.max(initdelay + length * (repeats + 1) + delay * repeats + 0.25, 2), function() -- 0.25 after last timer
		if(IsValid(self)) then
			self:Reset()
		end
	end)

	timer.Simple(initdelay, function()
		if(IsValid(self)) then
			for i = 0, repeats do
				timer.Simple(length * i + delay * i, function()
					if(IsValid(self) and IsValid(owner)) then
						numpad.Activate(owner, key, true)

						if WireLib then
							Wire_TriggerOutput(self, outputKey, self.KeypadData.OutputOn)
						end
					end
				end)

				timer.Simple(length * (i + 1) + delay * i, function()
					if(IsValid(self) and IsValid(owner)) then
						numpad.Deactivate(owner, key, true)

						if WireLib then
							Wire_TriggerOutput(self, outputKey, self.KeypadData.OutputOff)
						end
					end
				end)
			end
		end
	end)

	if granted then
		self:EmitSound("buttons/button9.wav")
	else
		self:EmitSound("buttons/button11.wav")
	end
end

function ENT:SetData(data)
	self.KeypadData = data

	self:SetPassword(data.Password or "1337")
	self:Reset()
	duplicator.StoreEntityModifier(self, "keypad_password_passthrough", self.KeypadData)
end

function ENT:GetData()
	if not self.KeypadData then
		self:SetData( {
			Password = 1337,

			RepeatsGranted = 0,
			RepeatsDenied = 0,

			LengthGranted = 0,
			LengthDenied = 0,

			DelayGranted = 0,
			DelayDenied = 0,

			InitDelayGranted = 0,
			InitDelayDenied = 0,

			KeyGranted = 0,
			KeyDenied = 0,

			OutputOn = 0,
			OutputOff = 0,

			Secure = false
		} )
	end

	return self.KeypadData
end

function ENT:Reset()
	self:SetValue("")
	self:SetStatus(self.Status_None)
	self:SetSecure(self.KeypadData.Secure)

	if WireLib then
		Wire_TriggerOutput(self, "Access Granted", self.KeypadData.OutputOff)
		Wire_TriggerOutput(self, "Access Denied", self.KeypadData.OutputOff)
	end
end

duplicator.RegisterEntityModifier("keypad_password_passthrough", function(ply, entity, data)
	entity:SetKeypadOwner(ply)
	entity:SetData(data)
end)