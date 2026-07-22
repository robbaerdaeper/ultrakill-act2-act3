-- Sound script registration for Puppet spawn audio.
-- Two random variants pulled when "Ultrakill_Puppet_Spawn" plays.

sound.Add( {
  name      = "Ultrakill_Puppet_Spawn",
  channel   = CHAN_AUTO,
  volume    = 0.85,
  level     = 75,
  pitch     = { 95, 105 },
  sound     = {
    "ultrakill_puppet/puppet_spawn.wav",
    "ultrakill_puppet/puppet_spawn_high.wav",
  },
} )
