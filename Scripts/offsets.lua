--[[
Offsets for the custom properties registered with RegisterCustomProperty.

The value stored in 'unk' corresponds to the "Unknown unreflected data"
entry visible in UE4SS Live View for SmallDeform_TERRAIN_EXPERIMENTAL_C.

Example:
    0x80C  RepBrushState
    0x840  Unknown unreflected data

The offsets above are examples only and may change after a game update.

All custom offsets below are relative to the start of the
"Unknown unreflected data" block (0x840 in the example above).

If the game is updated, verify this offset again in Live View, as the
position of the unreflected data block may change.
]]

local unk = 0x840

return {
	Deform_Normal1X = unk + 0x10,
	Deform_Normal1Y = unk + 0x14,
	Deform_Normal1Z = unk + 0x18,

	Deform_Normal2X = unk + 0xA4,
	Deform_Normal2Y = unk + 0xA8,
	Deform_Normal2Z = unk + 0xAC,

	Deform_Location1X = unk + 0x1C,
	Deform_Location1Y = unk + 0x20,
	Deform_Location1Z = unk + 0x24,

	Deform_Location2X = unk + 0x98,
	Deform_Location2Y = unk + 0x9C,
	Deform_Location2Z = unk + 0xA4,

	Deform_Location3X = unk + 0xB0,
	Deform_Location3Y = unk + 0xB4,
	Deform_Location3Z = unk + 0xB8,
}
