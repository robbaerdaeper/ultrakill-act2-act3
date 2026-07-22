-- dev/test: toggle enrage on the UKBase NPC under the crosshair.
-- Visual comes from ultrakillbase itself (canon-v2 shim was reverted,
-- Kevin's effect reads better in GMod).

if not SERVER then return end

concommand.Add( "uk_enrage_test", function( mPlayer, _, tArgs )

	if IsValid( mPlayer ) and not game.SinglePlayer() and not mPlayer:IsSuperAdmin() then return end

	local mTarget = mPlayer:GetEyeTrace().Entity
	if not IsValid( mTarget ) or not mTarget.SetEnraged then
		mPlayer:PrintMessage( HUD_PRINTCONSOLE, "uk_enrage_test: aim at a UKBase NPC" )
		return
	end

	if mTarget:IsEnraged() then
		mTarget:SetEnraged( false )
		mPlayer:PrintMessage( HUD_PRINTCONSOLE, "uk_enrage_test: OFF " .. mTarget:GetClass() )
	else
		mTarget:SetEnraged( true )
		mTarget:CreateEnrage( 1, tonumber( tArgs and tArgs[ 1 ] ) or 1 )
		mTarget:EmitSound( "ultrakill/sound/enrage.wav", 80, 100, 1, CHAN_STATIC )
		mPlayer:PrintMessage( HUD_PRINTCONSOLE, "uk_enrage_test: ON " .. mTarget:GetClass() )
	end

end )
