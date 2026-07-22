// Big Johninator — secret boss of 7-1, V2 AI reskin (statue of Davy Oshry).
// SMD source: johninator_build_assets.py (prefab-skeleton bake, no Blender).
// Single 'Default' anim clip in canon => rest pose only; the boss glides.
// BigJohn node scale 1.5 => 1 model unit = 1.5 m = 60 su ($scale 60).
$modelname "ultrakill_prelude_test/johninator.mdl"
$upaxis Y
$scale 60.0

$body "body" "johninator_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/johninator/"
$surfaceprop "metal"
$contents "solid"
$illumposition 0 0 0

// canon points: minigun barrel tip (rocket/beam/mine origin), chest (enrage/
// bless anchors). "head" LAST: ukcoin ricochets target the last attachment.
$attachment "muzzle" "MiniGunBarrel_end" 0 0 0
$attachment "chest"  "Chest" 0 0 0
$attachment "head"   "Head" 0 0 0

// hull from the no-hbox donor pass ($hboxset kills auto bbox — Gutterman lesson)
// WARNING: studiomdl multiplies $hbox values by $scale (Gutterman lesson #2,
// 2026-07-07) — values below are PRE-scale: desired final units / 60.
$bbox -71.68 -40.44 0.00 106.17 40.44 230.85

$hbox 3 "Pelvis" -0.32535500 -0.49248167 -0.33787667 0.32551667 0.55851667 0.58484667
$hbox 3 "Spine" -0.31125667 -0.26342833 -0.23575500 0.32295333 0.48686333 0.33937000
$hbox 2 "Chest" -0.35290500 -0.39895667 -0.13625333 0.45038667 0.49846000 0.42450333
$hbox 2 "Neck" -0.21162833 0.00000000 -0.07698000 0.21162667 0.15115833 0.13134333
$hbox 1 "Head" -0.21498500 -0.13641500 -0.27236333 0.21520333 0.41765167 0.27309667
$hbox 4 "Shoulder.L" -0.13537833 -0.17386833 -0.16787333 0.38645333 0.50326667 0.27503667
$hbox 4 "UpperArm.L" -0.10320167 -0.12518833 -0.11207000 0.32048833 0.54226500 0.14573000
$hbox 4 "LowerArm.L" -0.06791500 -0.07421167 -0.07879000 0.12605833 0.64612167 0.10716833
$hbox 4 "Hand.L" -0.06073833 -0.34981667 -0.10027500 0.11358500 0.33167000 0.11236000
$hbox 5 "Shoulder.R" -0.38793167 -0.17386667 -0.19355667 0.13537833 0.40513000 0.27316500
$hbox 5 "UpperArm.R" -0.26598167 -0.13526333 -0.13781833 0.06121333 0.55819167 0.25901500
$hbox 5 "LowerArm.R" -0.09229833 -0.05815833 -0.06458000 0.19418833 0.56168167 0.10060833
$hbox 5 "Hand.R" -0.11446667 -0.25920167 -0.10905333 0.08200667 0.33166833 0.23794500
$hbox 6 "UpperLeg.L" -0.13173500 -0.18718500 -0.25703500 0.22425833 0.90574333 0.16042667
$hbox 6 "LowerLeg.L" -0.09797167 -0.24253000 -0.14321000 0.17470333 0.73182333 0.20005500
$hbox 6 "Foot.L" -0.10612000 -0.06471500 -0.18623000 0.13794833 0.45235500 0.43482333
$hbox 7 "UpperLeg.R" -0.24008333 -0.11144833 -0.25309667 0.18031000 0.81398833 0.17391333
$hbox 7 "LowerLeg.R" -0.16223833 -0.18645500 -0.18229667 0.09815000 0.72946833 0.21913667
$hbox 7 "Foot.R" -0.13913000 -0.06023667 -0.18427167 0.10511833 0.45235333 0.40382333
$sequence idle "johninator_idle" loop fps 30

$collisionmodel "johninator_phys.smd" {
}
