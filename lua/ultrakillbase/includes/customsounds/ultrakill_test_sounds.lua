-- will convert MOST of the emitsounds into here if possible later

UltrakillBase.AddSoundScript( "Ultrakill_PunchHeavy", "ultrakill/sound/punch_heavy 1.wav", 0, 1, 1, nil, false, 0, false )

UltrakillBase.AddSoundScript( "Ultrakill_GuttermanBonk", "ultrakill_prelude_test/gutterman/bonk.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_GuttermanDeath", "ultrakill_prelude_test/gutterman/death.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_GuttermanShieldBreak", "ultrakill_prelude_test/gutterman/shield_break.wav", 0, 1, 1, nil, false, 0, false )

UltrakillBase.AddSoundScript( "Ultrakill_GuttertankShootPrep", "ultrakill_prelude_test/guttertank/rocket_prep.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_GuttertankShoot", "ultrakill_prelude_test/guttertank/rocket_fire.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_GuttertankPunchPrep", "ultrakill_prelude_test/guttertank/punch_prep.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_GuttertankPunchHit", "ultrakill_prelude_test/guttertank/punch_hit.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_GuttertankMinePrep", "ultrakill_prelude_test/guttertank/mine_prep.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_GuttertankFallImpact", "ultrakill_prelude_test/guttertank/fall_impact.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_GuttertankDeath", "ultrakill_prelude_test/guttertank/death.wav", 0, 1, 1, nil, false, 0, false )

UltrakillBase.AddSoundScript( "Ultrakill_VirtueDeath", "ultrakill_test/virtue_death.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_VirtueCharge", "ultrakill_test/virtue_charge.wav", 0, 1, 1, nil, false, 0, false )

UltrakillBase.AddSoundScript( "Ultrakill_MinotaurRoar", "ultrakill_prelude_test/minotaur/roar.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_MinotaurRoarShort", "ultrakill_prelude_test/minotaur/roar_short.wav", 0, 3, 2, 2, false, 1, true, function( self )
	self.mPitch = Lerp( ( CurTime() - self.mInitTime ) / self.mDieTime, 3, 4 )
end)
UltrakillBase.AddSoundScript( "Ultrakill_MinotaurGrunt1", "ultrakill_prelude_test/minotaur/grunt1.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_MinotaurGrunt2", "ultrakill_prelude_test/minotaur/grunt2.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_MinotaurGruntLong", "ultrakill_prelude_test/minotaur/grunt_long.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_MinotaurSqueal", "ultrakill_prelude_test/minotaur/squeal.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_MinotaurExhale", "ultrakill_prelude_test/minotaur/exhale.wav", 0, 1, 1, nil, false, 0, false )
UltrakillBase.AddSoundScript( "Ultrakill_MinotaurDie", "ultrakill_prelude_test/minotaur/roar.wav", 0, 0.8, 2, 8, false, 1, true, function( self )
	self.mPitch = Lerp( ( CurTime() - self.mInitTime ) / self.mDieTime, 0.8, 0 )
end)

