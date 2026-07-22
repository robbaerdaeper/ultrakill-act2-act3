// Mirror Reaper — rigged canon model (2026-07-03 port).
// SMD sources: mirror_reaper_build_ref_mesh.py (mesh + corpse, exact bind skinning)
//              mirror_reaper_bake_anims.py (skeleton + 7 canon clips, 30 fps)
// Scale: canon rest height 7.33 m; 1 canon meter = 0.005 bone units,
// project convention 40 su/m  =>  $scale = 40 / 0.005 = 8000.
$modelname "ultrakill_prelude_test/mirror_reaper.mdl"
$upaxis Y
// prefab export faces +Z (virtue_v2 convention): $origin yaw 0
$origin 0 0 0 0
$scale 8000.0

// variant 1 = corpse mesh (canon Enemy.onDeath swaps sharedMesh); Lua switches on death
$bodygroup "body" {
    studio "mirror_reaper_body_ref.smd"
    studio "mirror_reaper_corpse_ref.smd"
}

$cdmaterials "models/ultrakill_prelude_test/mirror_reaper/"

$surfaceprop "flesh"
$contents "solid"

// all materials UnlitGeneric; $illumposition multiplied by $scale — keep zero
$illumposition 0 0 0

$attachment "chest"      "Spine_05" 0 0 0
$attachment "weakpoint"  "Scythe_2" 0 0 0
$attachment "scythe_tip" "Scythe_4" 0 0 0

$sequence Idle              "idle"              loop fps 30
$sequence GroundWave        "groundwave"             fps 30
$sequence ProjectileBarrage "projectilebarrage"      fps 30
$sequence SwingSpree        "swingspree"             fps 30
$sequence SwingTriple       "swingtriple"            fps 30
$sequence SwingVertical     "swingvertical"          fps 30
$sequence Teleport          "teleport"               fps 30

// simple box 4x7x4 m: DrGBase uses its own bounds; corpse = PhysicsInitBox in Lua
$collisionmodel "mirror_reaper_phys.smd" {
}
