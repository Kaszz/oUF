--[[
# Element: Power Bar

Handles updating of a status bar that displays the units power.

## Widget

Power - A StatusBar used to represent unit power.

## Sub-Widgets

.bg - A Texture which functions as a background. It will inherit the color of the main StatusBar.

## Notes

A default texture will be applied if the widget is a StatusBar and doesn't have a texture or color set.

## Options

.displayAltPower - Use this to let the widget display alternate power if the unit has one. If no alternate power the
                   display will fall back to primary power.
.useAtlas        - Use this to let the widget use an atlas for its texture if `.atlas` is defined on the widget or an
                   atlas is present in `self.colors.power` for the appropriate power type.
.atlas           - A custom atlas

The following options are listed by priority. The first check that returns true decides the color of the bar.

.colorTapping      - Use `self.colors.tapping` to color the bar if the unit isn't tapped by the player.
.colorDisconnected - Use `self.colors.disconnected` to color the bar if the unit is offline.
.altPowerColor     - A table containing the RGB values to use for a fixed color if the alt power bar is being displayed
                     instead.
.colorPower        - Use `self.colors.power[token]` to color the bar based on the unit's power type. This method will
                     fall-back to `:GetAlternativeColor()` if it can't find a color matching the token. If this function
                     isn't defined, then it will attempt to color based upon the alternative power colors returned by
                     [UnitPowerType](http://wowprogramming.com/docs/api/UnitPowerType). Finally, if these aren't
                     defined, then it will attempt to color the bar based upon `self.colors.power[type]`.
.colorClass        - Use `self.colors.class[class]` to color the bar based on unit class. `class` is defined by the
                     second return of [UnitClass](http://wowprogramming.com/docs/api/UnitClass).
.colorClassNPC     - Use `self.colors.class[class]` to color the bar if the unit is a NPC.
.colorClassPet     - Use `self.colors.class[class]` to color the bar if the unit is player controlled, but not a player.
.colorReaction     - Use `self.colors.reaction[reaction]` to color the bar based on the player's reaction towards the
                     unit. `reaction` is defined by the return value of
                     [UnitReaction](http://wowprogramming.com/docs/api/UnitReaction).
.colorSmooth       - Use `self.colors.smooth` to color the bar with a smooth gradient based on the player's current
                     health percentage.

## Sub-Widget Options

.multiplier - Defines a multiplier, which is used to tint the background based on the main widgets R, G and B values.
              Defaults to 1 if not present.

## Examples

    -- Position and size
    local Power = CreateFrame('StatusBar', nil, self)
    Power:SetHeight(20)
    Power:SetPoint('BOTTOM')
    Power:SetPoint('LEFT')
    Power:SetPoint('RIGHT')

    -- Add a background
    local Background = Power:CreateTexture(nil, 'BACKGROUND')
    Background:SetAllPoints(Power)
    Background:SetTexture(1, 1, 1, .5)

    -- Options
    Power.frequentUpdates = true
    Power.colorTapping = true
    Power.colorDisconnected = true
    Power.colorPower = true
    Power.colorClass = true
    Power.colorReaction = true

    -- Make the background darker.
    Background.multiplier = .5

    -- Register it with oUF
	Power.bg = Background
    self.Power = Power
--]]

local _, ns = ...
local oUF = ns.oUF

-- sourced from FrameXML/UnitPowerBarAlt.lua
local ALTERNATE_POWER_INDEX = ALTERNATE_POWER_INDEX or 10

local function getDisplayPower(unit)
	local _, min, _, _, _, _, showOnRaid = UnitAlternatePowerInfo(unit)
	if(showOnRaid) then
		return ALTERNATE_POWER_INDEX, min
	end
end

local function UpdateColor(element, unit, cur, min, max, displayType)
	local parent = element.__owner
	local ptype, ptoken, altR, altG, altB = UnitPowerType(unit)

	local r, g, b, t
	if(element.colorTapping and element.tapped) then
		t = parent.colors.tapped
	elseif(element.colorDisconnected and element.disconnected) then
		t = parent.colors.disconnected
	elseif(displayType == ALTERNATE_POWER_INDEX and element.altPowerColor) then
		t = element.altPowerColor
	elseif(element.colorPower) then
		t = parent.colors.power[ptoken]
		if(not t) then
			if(element.GetAlternativeColor) then
				r, g, b = element:GetAlternativeColor(unit, ptype, ptoken, altR, altG, altB)
			elseif(altR) then
				r, g, b = altR, altG, altB

				if(r > 1 or g > 1 or b > 1) then
					-- BUG: As of 7.0.3, altR, altG, altB may be in 0-1 or 0-255 range.
					r, g, b = r / 255, g / 255, b / 255
				end
			else
				t = parent.colors.power[ptype]
			end
		end
	elseif(element.colorClass and UnitIsPlayer(unit)) or
		(element.colorClassNPC and not UnitIsPlayer(unit)) or
		(element.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)
		t = parent.colors.class[class]
	elseif(element.colorReaction and UnitReaction(unit, 'player')) then
		t = parent.colors.reaction[UnitReaction(unit, 'player')]
	elseif(element.colorSmooth) then
		local adjust = 0 - (min or 0)
		r, g, b = parent.ColorGradient(cur + adjust, max + adjust, unpack(element.smoothGradient or parent.colors.smooth))
	end

	if(t) then
		r, g, b = t[1], t[2], t[3]
	end

	t = parent.colors.power[ptoken or ptype]

	local atlas = element.atlas or (t and t.atlas)
	if(element.useAtlas and atlas and displayType ~= ALTERNATE_POWER_INDEX) then
		element:SetStatusBarAtlas(atlas)
		element:SetStatusBarColor(1, 1, 1)

		if(element.colorTapping or element.colorDisconnected) then
			t = element.disconnected and parent.colors.disconnected or parent.colors.tapped
			element:GetStatusBarTexture():SetDesaturated(element.disconnected or element.tapped)
		end

		if(t and (r or g or b)) then
			r, g, b = t[1], t[2], t[3]
		end
	else
		element:SetStatusBarTexture(element.texture)

		if(r or g or b) then
			element:SetStatusBarColor(r, g, b)
		end
	end

	local bg = element.bg
	if(bg and b) then
		local mu = bg.multiplier or 1
		bg:SetVertexColor(r * mu, g * mu, b * mu)
	end
end

local function Update(self, event, unit)
	if(self.unit ~= unit) then return end
	local element = self.Power

	--[[ Callback: Power:PreUpdate(unit)
	Called before the element has been updated.

	* self - the Power element
	* unit - the event unit that the update has been triggered for
	--]]
	if(element.PreUpdate) then element:PreUpdate(unit) end

	local displayType, min
	if(element.displayAltPower) then
		displayType, min = getDisplayPower(unit)
	end

	local cur, max = UnitPower(unit, displayType), UnitPowerMax(unit, displayType)
	local disconnected = not UnitIsConnected(unit)
	local tapped = not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)
	element:SetMinMaxValues(min or 0, max)

	if(disconnected) then
		element:SetValue(max)
	else
		element:SetValue(cur)
	end

	element.disconnected = disconnected
	element.tapped = tapped

	--[[ Override: Power:UpdateColor(unit, cur, min, max, displayType)
	Used to completely override the internal function for updating the widgets' colors.

	* self        - the Power element
	* unit        - the event unit that the update has been triggered for
	* cur         - the unit's current power value
	* min         - the unit's minimum possible power value
	* max         - the unit's maximum possible power value
	* displayType - the alternative power display type, if any
	--]]
	element:UpdateColor(unit, cur, min, max, displayType)

	--[[ Callback: Power:PostUpdate(unit, cur, min, max, powerToken, powerType)
	Called after the element has been updated.

	* self       - the Power element
	* unit       - the event unit that the update has been triggered for
	* cur        - the unit's current power value
	* min        - the unit's minimum possible power value
	* max        - the unit's maximum possible power value
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(unit, cur, min, max)
	end
end

local function Path(self, ...)
	--[[ Override: Power:Override(event, unit, ...)
	Used to completely override the internal update function.

	* self  - the Power element
	* event - the event triggering the update
	* unit  - the unit accompanying the event
	* ...   - the arguments accompanying the event
	--]]
	return (self.Power.Override or Update) (self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local function Enable(self, unit)
	local element = self.Power
	if(element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		if(element.frequentUpdates and (unit == 'player' or unit == 'pet')) then
			self:RegisterEvent('UNIT_POWER_FREQUENT', Path)
		else
			self:RegisterEvent('UNIT_POWER', Path)
		end

		self:RegisterEvent('UNIT_POWER_BAR_SHOW', Path)
		self:RegisterEvent('UNIT_POWER_BAR_HIDE', Path)
		self:RegisterEvent('UNIT_DISPLAYPOWER', Path)
		self:RegisterEvent('UNIT_CONNECTION', Path)
		self:RegisterEvent('UNIT_MAXPOWER', Path)
		self:RegisterEvent('UNIT_FACTION', Path) -- For tapping

		if(element:IsObjectType('StatusBar')) then
			element.texture = element:GetStatusBarTexture() and element:GetStatusBarTexture():GetTexture() or [[Interface\TargetingFrame\UI-StatusBar]]
			element:SetStatusBarTexture(element.texture)
		end

		if(not element.UpdateColor) then
			element.UpdateColor = UpdateColor
		end

		return true
	end
end

local function Disable(self)
	local element = self.Power
	if(element) then
		element:Hide()

		self:UnregisterEvent('UNIT_POWER_FREQUENT', Path)
		self:UnregisterEvent('UNIT_POWER', Path)
		self:UnregisterEvent('UNIT_POWER_BAR_SHOW', Path)
		self:UnregisterEvent('UNIT_POWER_BAR_HIDE', Path)
		self:UnregisterEvent('UNIT_DISPLAYPOWER', Path)
		self:UnregisterEvent('UNIT_CONNECTION', Path)
		self:UnregisterEvent('UNIT_MAXPOWER', Path)
		self:UnregisterEvent('UNIT_FACTION', Path)
	end
end

oUF:AddElement('Power', Path, Enable, Disable)
