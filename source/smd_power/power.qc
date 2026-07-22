// Power (Greater Angel, Layer 8 / 8-3 Disintegration Loop) — canon 1:1.
// SMD source: power_build_assets.py (prefab-skeleton bake, no Blender).
// Prefab: gameprefabs 'Power' (Power + EnemyIdentifier + Enemy MBs).
// Model node 'Power' scale 1.75 => 1 model unit = 1.75 m = 70 su ($scale 70).
// Model origin = feet/capsule bottom; enemy fly-pivot is 3.38 m above it.
$modelname "ultrakill_prelude_test/power.mdl"
$upaxis Y
$scale 35.0 // 2026-07-10 workshop size report: rescaled to match Kevin-pack proportions (was 70)

$body "body" "power_ref.smd"

$bodygroup "cape"
{
    studio "power_cape.smd"
    blank
}

// weapons of light: spawned/despawned per-attack by animation events
$bodygroup "weapon"
{
    blank
    studio "power_wep_sword.smd"
    studio "power_wep_zwei.smd"
    studio "power_wep_glaive.smd"
    studio "power_wep_spinner.smd"
    studio "power_wep_spear.smd"
}

$cdmaterials "models/ultrakill_prelude_test/power/"
$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 0

// skin 0 = normal (silver/blue), skin 1 = enraged (gold/red)
$texturegroup "skinfamilies"
{
    { "power_body"         "power_cape"         }
    { "power_body_enraged" "power_cape_enraged" }
}

// canon points: Weapon bone (weapon fx + spinner throw origin), chest
// (Spine_03 = Enemy.chest), gauntlet hand. "head" LAST: ukcoin ricochets
// target the last attachment (weakPoint = Head).
$attachment "weapon"   "Weapon" 0 0 0
$attachment "chest"    "Spine_03" 0 0 0
$attachment "gauntlet" "Hand_L" 0 0 0
$attachment "head"     "Head" 0 0 0

$hboxset "default"
$hbox 1 "Head" -0.196 -0.078 -0.250 0.196 0.204 0.148
$hbox 3 "Spine_01" -0.301 -0.165 -0.234 0.300 0.328 0.240
$hbox 2 "Spine_02" -0.283 0.045 -0.245 0.301 0.280 0.193
$hbox 2 "Spine_03" -0.442 -0.080 -0.276 0.415 0.396 0.242
$hbox 2 "Spine_04" -0.138 0.136 -0.131 0.138 0.288 0.092
$hbox 2 "Neck" -0.101 0.076 -0.004 0.094 0.102 0.104
$hbox 4 "Forearm_L" -0.111 -0.111 -0.118 0.133 0.572 0.132
$hbox 4 "Hand_L" -0.108 -0.264 -0.132 0.130 0.327 0.138
$hbox 5 "UpperArm_R" -0.197 -0.261 -0.288 0.166 0.690 0.185
$hbox 5 "Forearm_R" -0.117 -0.171 -0.179 0.105 0.609 0.073
$hbox 5 "Hand_R" -0.070 -0.012 -0.078 0.053 0.199 0.084
$hbox 6 "Thigh_L" -0.154 0.005 -0.244 0.191 0.786 0.227
$hbox 6 "Calf_L" -0.134 -0.032 -0.292 0.148 0.892 0.212
$hbox 6 "Foot_L" -0.106 -0.196 -0.312 0.142 0.500 0.169
$hbox 7 "Thigh_R" -0.191 0.005 -0.244 0.154 0.790 0.227
$hbox 7 "Calf_R" -0.148 -0.032 -0.292 0.134 0.892 0.212
$hbox 7 "Foot_R" -0.142 -0.196 -0.312 0.106 0.500 0.169

$sequence Idle       "power_idle" loop fps 30
$sequence Intro      "power_intro" fps 30
$sequence Backdash   "power_backdash" fps 30
$sequence Death      "power_death" fps 30
$sequence Enrage     "power_enrage" fps 30
$sequence Glaive     "power_glaive" fps 30
$sequence Juggle     "power_juggle" loop fps 30
$sequence Rapier     "power_rapier" fps 30
$sequence SpearDrop  "power_speardrop" loop fps 30
$sequence SpearSpawn "power_spearspawn" fps 30
$sequence SpearThrow "power_spearthrow" fps 30
$sequence Throw      "power_throw" fps 30
$sequence Zweihander "power_zweihander" fps 30

$collisionmodel "power_phys.smd" {
}
