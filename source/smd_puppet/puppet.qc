// Puppet — port QC (ULTRAKILL Puppet enemy).
// IMPORTANT: Puppet.glb contained only seasonal-hat overlays + colliders, no body mesh.
// In Unity the Puppet prefab pulls the body from a referenced SkinnedMeshRenderer that
// resolves to the same Filth/Husk skeleton. We therefore reuse the already-validated
// Melee_Husk.smd / filth_physics.smd from smd_v11/. The Puppet visual identity comes
// from the translucent red puppet_blood material (VertexLitGeneric + $rimlight + $alpha 0.666).

$modelname     "ultrakill_puppet/puppet.mdl"
$cdmaterials   "models/ultrakill_puppet/"
$surfaceprop   "flesh"
$contents      "solid"

$scale 5

$body          "body" "puppet_ref.smd"

// Canonical Puppet.controller has exactly 3 motions: Idle / ZombieWalk / Swing.
// Puppet does NOT run and does NOT bite — those sequences are intentionally absent.
// Falling falls back to Idle (DrGBase looks up the name; missing seqs would error).
// SMD filenames come straight from Blender Source Tools per-Action export.
$sequence Idle       "anims/Idle"          loop fps 60
$sequence ZombieWalk "anims/ZombieWalk"    loop fps 60
$sequence Walk       "anims/ZombieWalk"    loop fps 60
$sequence Falling    "anims/Idle"          loop fps 60
$sequence Swing      "anims/ChargeAttack"  fps 60

$collisionmodel "puppet_phys.smd" {
    $concave
    $maxconvexpieces 256
}
