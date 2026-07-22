// The Corpse of King Minos — canon 2-4 boss, 1:1 scale.
// SMD source: minos_build_assets.py (scene-skeleton bake, no Blender).
// Scene: enemy root scale 5 => 1 model unit = 5 m = 200 su ($scale 200).
// Model origin = canon waterline (offset -117.8 units baked into skeleton);
// ~590 m of corpse hangs below z=0 (buried, as in canon).
$modelname "ultrakill_prelude_test/minos_corpse.mdl"
$upaxis Y
$scale 200.0

$body "body" "corpse_ref.smd"
$bodygroup "eyes"
{
    studio "corpse_eyes.smd"
    blank
}

$cdmaterials "models/ultrakill_prelude_test/minos/"
$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 0

$texturegroup "skinfamilies"
{
    { "minos_body" }
    { "minos_body_eyeless" }
}

// canon: chest/overrideCenter = Head, weakPoint = eyes (on Head).
// "head" LAST: ukcoin ricochets target the last attachment.
$attachment "lefthand"  "HandCenter_(1)" 0 0 0
$attachment "righthand" "HandCenter" 0 0 0
// BlackHoleSpawnPos: child of enemy root at (1,120,35.5)*mirrorX - waterline
$attachment "blackhole" "armed-minos2" -1 2.2 35.5
$attachment "head"      "Head" 0 0 0

$hboxset "default"
// canon Head colliders (box 15x30x15 @ y+10 merged with face plates)
$hbox 1 "Head" -7.5 -5.0 -7.5 7.5 25.0 7.5
$hbox 0 "neck" -5 -3 -5 5 8 5
$hbox 0 "spine.002" -12 0 -10 12 30 10
$hbox 0 "spine.001" -14 0 -12 14 18 12
// canon arm capsules (upperarm h40 r3, lowerarm h30 r2.5)
$hbox 0 "upperarm.l" -3 -5 -3 3 35 3
$hbox 0 "upperarm.r" -3 -5 -3 3 35 3
$hbox 0 "lowerarmtwist.l" -2.5 -2 -2.5 2.5 28 2.5
$hbox 0 "lowerarmtwist.r" -2.5 -2 -2.5 2.5 28 2.5
$hbox 0 "hand.l" -5 0 -5 5 12 5
$hbox 0 "hand.r" -5 0 -5 5 12 5

$sequence Idle           "corpse_idle" loop fps 30
$sequence SlamRight      "corpse_slamright" fps 30
$sequence SlamLeft       "corpse_slamleft" fps 30
$sequence SlamMiddle     "corpse_slammiddle" fps 30
$sequence SlamMiddleLow  "corpse_slammiddlelow" fps 30
$sequence ParryRight     "corpse_parryright" fps 30
$sequence ParryLeft      "corpse_parryleft" fps 30
$sequence SpawnBlackHole "corpse_spawnblackhole" fps 30
$sequence PhaseParasite  "corpse_phaseparasite" fps 30
$sequence Death          "corpse_death" fps 30

$collisionmodel "corpse_phys.smd" {
}
