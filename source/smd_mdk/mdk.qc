// Mysterious Druid Knight (& Owl) — canon 4-3 secret boss, 1:1.
// SMD source: mdk_build_assets.py (static full-matrix bake: prefab has no
// Animator, non-uniform (2.4,2.4,1.8) skeleton scale baked into verts).
// Units: meters, $scale 40 (40 su/m). Feet offset +1.3351 baked (y_off).
$modelname "ultrakill_prelude_test/mdk.mdl"
$upaxis Y
$scale 40.0

$body "body" "mdk_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/mdk/"
$surfaceprop "bone"
$contents "solid"
$illumposition 0 1.35 1.0

// canon: projectiles spawn at prefab root (transform.position). "head" LAST:
// ukcoin ricochets target the last attachment (weakPoint = Head).
$attachment "muzzle" "Mandalore" 0 1.2 1.0
$attachment "owl"    "Shammy" 0.2 0 0
$attachment "head"   "Head" 0.2 0 0

$hboxset "default"
// bone-local vert bboxes from mdk_events.json (w>=0.3)
$hbox 1 "Head"    -0.17 -0.40 -0.66  0.79 0.40 0.40
$hbox 2 "Chest"    0.05 -0.70 -0.43  1.48 0.69 0.46
$hbox 3 "Hips"    -0.35 -0.60 -0.33  0.77 0.60 0.49
$hbox 0 "Shammy"   0.00 -0.07 -0.25  0.40 0.65 0.17
$hbox 4 "ArmU.L"  -0.06 -0.13 -0.10  1.41 0.22 0.26
$hbox 4 "ArmL.L"  -0.10 -0.17 -0.09  1.01 0.09 0.18
$hbox 4 "Hand.L"  -0.06 -0.02 -0.16  0.70 0.12 0.26
$hbox 5 "ArmU.R"  -0.04 -0.31 -0.13  1.33 0.04 0.21
$hbox 5 "ArmL.R"  -0.10 -0.09 -0.14  1.02 0.18 0.14
$hbox 5 "Hand.R"  -0.04 -0.09 -0.18  0.61 0.09 0.22
$hbox 6 "LegU.L"  -0.10 -0.18 -0.43  1.66 0.40 0.12
$hbox 6 "LegL.L"  -0.12 -0.15 -0.16  1.54 0.23 0.26
$hbox 6 "Foot.L"  -0.10 -0.31 -0.26  0.93 0.05 0.17
$hbox 7 "LegU.R"  -0.09 -0.40 -0.43  1.67 0.13 0.13
$hbox 7 "LegL.R"  -0.12 -0.19 -0.21  1.66 0.12 0.10
$hbox 7 "Foot.R"  -0.11 -0.06 -0.30  0.92 0.37 0.12

$sequence Idle "mdk_idle" loop fps 30

$collisionmodel "mdk_phys.smd" {
}
