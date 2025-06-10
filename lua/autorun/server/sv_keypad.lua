util.AddNetworkString("Keypad")
util.AddNetworkString("KeypadCracker_Hold")
util.AddNetworkString("KeypadCracker_Sparks")

CreateConVar("sbox_maxkeypads", 10)

net.Receive("Keypad", function(_, ply)
	local ent = net.ReadEntity()
	if not IsValid(ply) or not IsValid(ent) then return end

	local class = ent:GetClass():lower()
	if class ~= "keypad" and class ~= "keypad_wire" then return end

	if ent:GetStatus() ~= ent.Status_None then return end
	if ply:EyePos():Distance(ent:GetPos()) >= 120 then return end
	if ent.Next_Command_Time and ent.Next_Command_Time > CurTime() then return end

	ent.Next_Command_Time = CurTime() + 0.05

	local command = net.ReadUInt(4)

	if command == ent.Command_Enter then
		local val = tonumber(ent:GetValue() .. net.ReadUInt(8))

		if val and val > 0 and val <= 9999 then
			ent:SetValue(tostring(val))
			ent:EmitSound("buttons/button15.wav")
		end
	elseif command == ent.Command_Abort then
		ent:SetValue("")
	elseif command == ent.Command_Accept then
		if ent:GetValue() == ent:GetPassword() then
			ent:Process(true)
		else
			ent:Process(false)
		end
	end
end)