if not SERVER then return end

-- Apply Sand status to a target. Handles puppet+sand canon interaction:
--   * puppeted (non-Stalker) → instakill + cloud (canon EnemyIdentifier.cs:2235)
--   * puppeted Stalker → no instakill (canon exception); sand applied normally
--   * blessed → NOT immune (canon: bless gives dmg immunity, not sand immunity)
--   * Idol / Deathcatcher → sanded like anyone else (canon Sandify
--     EnemyIdentifier.cs:2040 has no support-unit exclusion). Their self-defense
--     hooks only zero the blast DAMAGE — the sand coat is applied separately here.
function UKSand.Apply( target, source )
  if not IsValid( target ) then return end
  if UKSand.IsSand( target ) then return end                         -- idempotent (covers Stalker permanent-sand)
  if target:IsPlayer() then return end                                -- players never sandifiable
  if not UKSand.IsSandable( target ) then return end                  -- non-UK + not registered → skip

  -- Puppet+sand: instakill UNLESS target is a Stalker (canon exception).
  if UKPuppet and UKPuppet.IsApplied and UKPuppet.IsApplied( target )
     and target:GetClass() ~= "ultrakill_test_stalker" then
    ParticleEffect( "Ultrakill_SandExplosion", target:WorldSpaceCenter(), target:GetAngles() )
    sound.Play( "ultrakill_test/sand_hit.wav", target:GetPos(), 75, 100, 1 )
    target:TakeDamage( 99999, IsValid( source ) and source or target, IsValid( source ) and source or target )
    return
  end

  target:SetNW2Bool( UKSand.NW2.Sand, true )
  ParticleEffect( "Ultrakill_SandExplosion", target:WorldSpaceCenter(), target:GetAngles() )
  ParticleEffectAttach( "Ultrakill_Sand_Drip", PATTACH_ABSORIGIN_FOLLOW, target, 0 )
  sound.Play( "ultrakill_test/sand_hit.wav", target:GetPos(), 75, 100, 1 )
end

-- Debug / manual clear. Removes Sand flag and stops drip particles.
function UKSand.Clear( target )
  if not IsValid( target ) then return end
  target:SetNW2Bool( UKSand.NW2.Sand, false )
  -- Particles attached via ParticleEffectAttach detach automatically when the NW2 driver
  -- stops, BUT we explicitly StopParticles to be safe across save-load.
  target:StopParticles()
end

-- Console command for debug.
concommand.Add( "uksand_apply", function( ply, _, args )
  local ent = ply:GetEyeTrace().Entity
  if IsValid( ent ) then UKSand.Apply( ent, ply ); ply:ChatPrint( "Sand applied to " .. tostring( ent ) ) end
end, nil, "[debug] Apply UKSand to entity in front of you" )

concommand.Add( "uksand_clear", function( ply, _, args )
  local ent = ply:GetEyeTrace().Entity
  if IsValid( ent ) then UKSand.Clear( ent ); ply:ChatPrint( "Sand cleared from " .. tostring( ent ) ) end
end, nil, "[debug] Clear UKSand from entity in front of you" )
