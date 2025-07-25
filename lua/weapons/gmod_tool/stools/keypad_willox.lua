TOOL.Category = "Construction"
TOOL.Name = "Keypad"
TOOL.Command = nil

TOOL.Information = {
	{name = "left"},
	{name = "right"}
}

TOOL.ClientConVar["weld"] = '1'
TOOL.ClientConVar["freeze"] = '1'

TOOL.ClientConVar["password"] = '1234'
TOOL.ClientConVar["secure"] = '0'

TOOL.ClientConVar["repeats_granted"] = '0'
TOOL.ClientConVar["repeats_denied"] = '0'

TOOL.ClientConVar["length_granted"] = '0.1'
TOOL.ClientConVar["length_denied"] = '0.1'

TOOL.ClientConVar["delay_granted"] = '0'
TOOL.ClientConVar["delay_denied"] = '0'

TOOL.ClientConVar["init_delay_granted"] = '0'
TOOL.ClientConVar["init_delay_denied"] = '0'

TOOL.ClientConVar["key_granted"] = '0'
TOOL.ClientConVar["key_denied"] = '0'

TOOL.ClientConVar["wire_output_on"] = '1'
TOOL.ClientConVar["wire_output_off"] = '0'

cleanup.Register("keypads")
scripted_ents.Alias("keypad_wire", "keypad")

if CLIENT then
	language.Add("tool.keypad_willox.name", "Keypad")
	language.Add("tool.keypad_willox.desc", "Creates keypads for secure access")
	language.Add("tool.keypad_willox.left", "Create/update keypad")
	language.Add("tool.keypad_willox.right", "Copy keypad settings")

	language.Add("Undone_Keypad", "Undone Keypad")
	language.Add("Cleanup_keypads", "Keypads")
	language.Add("Cleaned_keypads", "Cleaned up all Keypads")

	language.Add("SBoxLimit_keypads", "You've hit the Keypad limit!")
end

function TOOL:SetupKeypad(ent, pass)
	local data = {
		Password = pass,

		RepeatsGranted = self:GetClientNumber("repeats_granted"),
		RepeatsDenied = self:GetClientNumber("repeats_denied"),

		LengthGranted = self:GetClientNumber("length_granted"),
		LengthDenied = self:GetClientNumber("length_denied"),

		DelayGranted = self:GetClientNumber("delay_granted"),
		DelayDenied = self:GetClientNumber("delay_denied"),

		InitDelayGranted = self:GetClientNumber("init_delay_granted"),
		InitDelayDenied = self:GetClientNumber("init_delay_denied"),

		KeyGranted = self:GetClientNumber("key_granted"),
		KeyDenied = self:GetClientNumber("key_denied"),

		OutputOn = self:GetClientNumber("wire_output_on"),
		OutputOff = self:GetClientNumber("wire_output_off"),

		Secure = tobool(self:GetClientNumber("secure")),
	}

	ent:SetKeypadOwner(self:GetOwner())
	ent:SetData(data)
end

function TOOL:RightClick(tr)
	local trace_ent = tr.Entity
	if not IsValid(trace_ent) then return false end

	local class = trace_ent:GetClass():lower()
	if class ~= "keypad" and class ~= "keypad_wire" then return false end

	if CLIENT then return true end

	local data = trace_ent:GetData()
	local ply = self:GetOwner()

	if trace_ent:GetKeypadOwner() ~= ply then return false end

	ply:ConCommand("keypad_willox_password " .. tostring(data.Password))
	ply:ConCommand("keypad_willox_secure " .. tostring(data.Secure))
	ply:ConCommand("keypad_willox_repeats_granted " .. tostring(data.RepeatsGranted))
	ply:ConCommand("keypad_willox_repeats_denied " .. tostring(data.RepeatsDenied))
	ply:ConCommand("keypad_willox_length_granted " .. tostring(data.LengthGranted))
	ply:ConCommand("keypad_willox_length_denied " .. tostring(data.LengthDenied))
	ply:ConCommand("keypad_willox_delay_granted " .. tostring(data.DelayGranted))
	ply:ConCommand("keypad_willox_delay_denied " .. tostring(data.DelayDenied))
	ply:ConCommand("keypad_willox_init_delay_granted " .. tostring(data.InitDelayGranted))
	ply:ConCommand("keypad_willox_init_delay_denied " .. tostring(data.InitDelayDenied))
	ply:ConCommand("keypad_willox_key_granted " .. tostring(data.KeyGranted))
	ply:ConCommand("keypad_willox_key_denied " .. tostring(data.KeyDenied))
	ply:ConCommand("keypad_willox_wire_output_on " .. tostring(data.OutputOn))
	ply:ConCommand("keypad_willox_wire_output_off " .. tostring(data.OutputOff))
end

function TOOL:LeftClick(tr)
	local trace_ent = tr.Entity
	local class

	if IsValid(trace_ent) then
		class = trace_ent:GetClass():lower()
	end

	if class == "player" then return false end
	if CLIENT then return true end

	local ply = self:GetOwner()
	local password = self:GetClientNumber("password")

	local spawn_pos = tr.HitPos + tr.HitNormal

	if password == nil or (string.len(tostring(password)) > 4) or (string.find(tostring(password), "0")) then
		ply:PrintMessage(3, "Invalid password!")
		return false
	end

	-- Update an existing keypad
	if (class == "keypad" or class == "keypad_wire") and trace_ent:GetKeypadOwner() == ply then
		self:SetupKeypad(trace_ent, password)

		return true
	end

	if not self:GetWeapon():CheckLimit("keypads") then return false end

	local ent = ents.Create("keypad")
	ent:SetPos(spawn_pos)
	ent:SetAngles(tr.HitNormal:Angle())
	ent:Spawn()

	ent:SetPlayer(ply)

	local freeze = tobool(self:GetClientNumber("freeze"))
	local weld = tobool(self:GetClientNumber("weld"))

	if freeze or weld then
		local phys = ent:GetPhysicsObject()

		if IsValid(phys) then
			phys:EnableMotion(false)
		end
	end

	if weld then
		constraint.Weld(ent, trace_ent, 0, 0, 0, true, false)
	end

	self:SetupKeypad(ent, password)

	undo.Create("Keypad")
		undo.AddEntity(ent)
		undo.SetPlayer(ply)
	undo.Finish()

	ply:AddCount("keypads", ent)
	ply:AddCleanup("keypads", ent)

	return true
end

if CLIENT then
	local function ResetSettings(ply)
		ply:ConCommand("keypad_willox_repeats_granted 0")
		ply:ConCommand("keypad_willox_repeats_denied 0")
		ply:ConCommand("keypad_willox_length_granted 0.1")
		ply:ConCommand("keypad_willox_length_denied 0.1")
		ply:ConCommand("keypad_willox_delay_granted 0")
		ply:ConCommand("keypad_willox_delay_denied 0")
		ply:ConCommand("keypad_willox_init_delay_granted 0")
		ply:ConCommand("keypad_willox_init_delay_denied 0")
		ply:ConCommand("keypad_willox_wire_output_on 1")
		ply:ConCommand("keypad_willox_wire_output_off 0")
	end

	concommand.Add("keypad_willox_reset", ResetSettings)

	function TOOL.BuildCPanel(CPanel)
		local r = CPanel:TextEntry("Access Password", "keypad_willox_password")
		r:SetTall(22)

		CPanel:ControlHelp("Max Length: 4\nAllowed Digits: 1-9")

		CPanel:CheckBox("Secure Mode", "keypad_willox_secure")
		CPanel:CheckBox("Weld", "keypad_willox_weld")
		CPanel:CheckBox("Freeze", "keypad_willox_freeze")

		local ctrl = vgui.Create("CtrlNumPad", CPanel)
			ctrl:SetConVar1("keypad_willox_key_granted")
			ctrl:SetConVar2("Keypad_willox_key_denied")
			ctrl:SetLabel1("Access Granted Key")
			ctrl:SetLabel2("Access Denied Key")
		CPanel:AddPanel(ctrl)

		if WireLib then
			CPanel:NumSlider("Wire Output On:", "keypad_willox_wire_output_on", -10, 10, 0)
			CPanel:NumSlider("Wire Output Off:", "keypad_willox_wire_output_off", -10, 10, 0)
		end

		local granted = vgui.Create("DForm")
			granted:SetName("Access Granted Settings")

			granted:NumSlider("Hold Length:", "keypad_willox_length_granted", 0.1, 10, 2)
			granted:NumSlider("Initial Delay:", "keypad_willox_init_delay_granted", 0, 10, 2)
			granted:NumSlider("Multiple Press Delay:", "keypad_willox_delay_granted", 0, 10, 2)
			granted:NumSlider("Additional Repeats:", "keypad_willox_repeats_granted", 0, 5, 0)
		CPanel:AddItem(granted)

		local denied = vgui.Create("DForm")
			denied:SetName("Access Denied Settings")

				denied:NumSlider("Hold Length:", "keypad_willox_length_denied", 0.1, 10, 2)
				denied:NumSlider("Initial Delay:", "keypad_willox_init_delay_denied", 0, 10, 2)
				denied:NumSlider("Multiple Press Delay:", "keypad_willox_delay_denied", 0, 10, 2)
				denied:NumSlider("Additional Repeats:", "keypad_willox_repeats_denied", 0, 5, 0)
		CPanel:AddItem(denied)

		CPanel:Button("Default Settings", "keypad_willox_reset")

		CPanel:Help("")

		local faq = CPanel:Help("Information")
			faq:SetFont("GModWorldtip")

		CPanel:Help("You can enter your password with your numpad when numlock is enabled!")

		CPanel:Help("")

		CPanel:Help("Created by Willox ( https://steamcommunity.com/id/wiox )")
	end
end