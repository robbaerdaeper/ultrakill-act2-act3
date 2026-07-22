// Leviathan — canon 5-4 boss.
// SMD source: leviathan_build_assets.py (scene-skeleton bake, no Blender).
// Model node = LeviathanHead GO (scene meters) => $scale 40 = 1:1 canon.
// Origin = canon waterline; head bone rides ~84 m above it at rest,
// ~500 m of body trails below/behind (submerged, as in canon).
// Same mdl serves head, tail (Lua SetModelScale 0.75) and the phase-3
// Ouroboros ring (sequence "Ouroboros").
$modelname "ultrakill_prelude_test/leviathan.mdl"
$upaxis Y
$scale 40.0

$body "body" "leviathan_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/leviathan/"
$surfaceprop "flesh"
$contents "solid"
$illumposition 0 0 50

// canon: weakPoint = Heart (Statue extraDamageZones x3), tail weak = Bone086.
// "heart" LAST: ukcoin ricochets target the last attachment.
$attachment "muzzle"  "ShootPoint" 0 0 0
$attachment "head"    "Bone001" 0 0 0
$attachment "tailtip" "Bone086" 0 0 0
$attachment "heart"   "WeakpointBone" 0 5 0

$hboxset "default"
// per-bone vertex bboxes (bone-local metres) — the whole serpent is hittable;
// group 1 = head cluster, group 2 = heart weak point (Lua x3)
$hbox 0 "Bone043" -10.62 -1.3 -12.87 12.94 25.89 12.87
$hbox 1 "Bone001" -11.35 -4.47 -11.67 11.41 26.54 13.8
$hbox 1 "Bone039" -7.38 -1.28 -9.39 4.68 21.41 9.39
$hbox 1 "Bone041" -6.48 -1.35 -10.19 11.03 28.65 10.19
$hbox 1 "ArmBone_L" -2.65 0.27 -2.72 1.39 15.7 2.85
$hbox 1 "ArmBone_R" -1.18 0.68 -2.98 3.1 15.56 2.02
$hbox 2 "WeakpointBone" -2.57 -0.95 -6.95 2.56 11.49 5.02
$hbox 0 "Bone044" -10.5 2.9 -13.08 8.8 14.43 13.08
$hbox 0 "Bone045" -14.44 -6.44 -11.39 14.15 16.6 11.4
$hbox 0 "Bone046" -15.84 -1.47 -11.21 15.16 21.75 11.21
$hbox 0 "Bone047" -15.98 -0.3 -11.05 15.18 23.25 11.05
$hbox 0 "Bone048" -10.66 0.18 -11.18 14.56 21.75 11.18
$hbox 0 "Bone049" -13.54 -6.68 -11.45 14.97 17.42 11.44
$hbox 0 "Bone050" -13.21 -4.45 -11.18 15.31 18.69 11.18
$hbox 0 "Bone051" -15.04 -1.37 -11.45 15.6 21.63 11.44
$hbox 0 "Bone052" -14.13 1.85 -11.18 15.64 16.25 11.18
$hbox 0 "Bone053" -14.01 -2.68 -11.45 15.45 21.63 11.44
$hbox 0 "Bone054" -15.28 0.31 -11.18 15.37 20.03 11.18
$hbox 0 "Bone055" -13.91 1.94 -11.44 15.26 16.85 11.44
$hbox 0 "Bone056" -15.01 -2.39 -11.18 15.42 18.47 11.18
$hbox 0 "Bone057" -15.31 -0.14 -11.45 15.54 21.66 11.44
$hbox 0 "Bone058" -14.36 1.99 -11.18 15.61 16.51 11.18
$hbox 0 "Bone059" -14.34 -2.05 -11.45 15.34 23.63 11.44
$hbox 0 "Bone060" -16.19 -0.64 -11.18 14.95 23.69 11.18
$hbox 0 "Bone061" -15.28 1.63 -11.44 13.59 17.77 11.45
$hbox 0 "Bone062" -16.55 -4.88 -11.18 13.7 19.27 11.18
$hbox 0 "Bone063" -15.53 -0.14 -11.44 13.71 26.47 11.45
$hbox 0 "Bone064" -16.7 3.99 -11.18 13.84 16.79 11.18
$hbox 0 "Bone065" -15.62 -4.11 -11.44 14.2 17.13 11.44
$hbox 0 "Bone066" -15.77 -1.75 -11.18 14.88 20.28 11.18
$hbox 0 "Bone067" -14.34 0.49 -11.45 15.08 16.89 11.44
$hbox 0 "Bone068" -15.41 -4.39 -11.18 15.3 16.32 11.18
$hbox 0 "Bone069" -14.94 -1.8 -11.45 15.2 24.18 11.44
$hbox 0 "Bone070" -15.62 2.36 -11.18 15.19 14.68 11.18
$hbox 0 "Bone071" -14.64 -4.27 -11.45 15.07 16.95 11.44
$hbox 0 "Bone072" -15.62 -1.36 -11.18 15.18 20.38 11.18
$hbox 0 "Bone073" -14.43 0.43 -11.45 15.07 16.91 11.44
$hbox 0 "Bone074" -15.62 -4.01 -11.18 15.18 16.57 11.18
$hbox 0 "Bone075" -15.01 -2.38 -11.45 15.07 24.0 11.44
$hbox 0 "Bone076" -15.62 1.38 -11.18 15.18 13.58 11.18
$hbox 0 "Bone077" -14.87 -4.5 -11.45 15.07 16.72 11.44
$hbox 0 "Bone078" -15.62 -1.55 -11.18 15.18 19.52 11.18
$hbox 0 "Bone079" -14.43 0.44 -11.44 15.07 16.91 11.44
$hbox 0 "Bone080" -16.07 -4.2 -10.91 15.18 15.79 10.91
$hbox 0 "Bone081" -14.67 -4.12 -10.88 14.76 21.52 10.88
$hbox 0 "Bone082" -9.29 2.01 -10.88 13.54 15.22 10.88
$hbox 0 "Bone083" -9.88 -3.64 -11.32 11.0 17.99 11.32
$hbox 0 "Bone084" -3.85 2.91 -10.34 10.38 13.41 10.34
$hbox 0 "Bone085" -4.02 -5.11 -10.34 9.95 17.6 10.33
$hbox 0 "Bone086" -4.49 -2.01 -16.52 6.12 26.17 16.51

$sequence Idle        "leviathan_idle" loop fps 30
$sequence AscendLong  "leviathan_ascendlong" fps 30
$sequence Ascend      "leviathan_ascend" fps 30
$sequence Descend     "leviathan_descend" fps 30
$sequence Bite        "leviathan_bite" fps 30
$sequence BiteParried "leviathan_biteparried" fps 30
$sequence BurstStart  "leviathan_burststart" fps 30
$sequence BurstLoop   "leviathan_burstloop" loop fps 30
$sequence BurstStop   "leviathan_burststop" fps 30
$sequence BeamStart   "leviathan_beamstart" fps 30
$sequence BeamLoop    "leviathan_beamloop" loop fps 30
$sequence BeamEnd     "leviathan_beamend" fps 30
$sequence Death       "leviathan_death" fps 30
$sequence TailWhip    "leviathan_tailwhip" fps 30
$sequence TailDeath   "leviathan_taildeath" fps 30
$sequence Ouroboros   "leviathan_ouroboros" loop fps 30

$collisionmodel "leviathan_phys.smd" {
}
