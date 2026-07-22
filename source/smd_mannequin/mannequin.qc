// Mannequin — rigged canon model (2026-07-03 full port, replaces deprecated MVP).
// SMD sources: mannequin_build_ref_mesh.py (mesh, exact bind skinning via UnityPy)
//              mannequin_bake_anims.py (skeleton + 12 gameplay clips + 11 statue poses, 30 fps)
// Scale: bone-space unit -> su. Calibration: 1 canon meter = 0.003057 bone units.
// 19 su/m (100 su + 15%)
// => $scale = 19 / 0.003057 = 6215.2, model ~115 su tall (player x1.6).
$modelname "ultrakill_prelude_test/mannequin.mdl"
$upaxis Y
// Clean prefab Animator export (not a scene instance) — no $origin needed
// (sentry pattern; '$origin 0 0 0 90' would leave the model side-on).
$scale 6215.2

$body "body" "mannequin_body_ref.smd"

$cdmaterials "models/ultrakill_prelude_test/mannequin/"

$surfaceprop "flesh"
$contents "solid"

// UnlitGeneric materials — lighting not sampled.
// NB: $illumposition is multiplied by $scale — never pass su values here.
$illumposition 0 0 0

// canon: Enemy.chest = Spine_03, shootPoint = child of Hand_R.
// "head" LAST: ukcoin ricochets target the last attachment (sentry lesson),
// and Head is the canon weakPoint.
$attachment "chest"      "Spine_03" 0 0 0
$attachment "shootpoint" "Hand_R"   0 0 0
$attachment "head"       "Head"     0 0 0

$sequence Idle                "idle"                loop fps 30
$sequence Walk                "walk"                loop fps 30
$sequence Skitter             "skitter"             loop fps 30
$sequence SkitterIdle         "skitteridle"         loop fps 30
$sequence Falling             "falling"             loop fps 30
$sequence FallingControlled   "fallingcontrolled"   loop fps 30
$sequence WallCling           "wallcling"           loop fps 30
$sequence MeleeAttack         "meleeattack"              fps 30
$sequence ProjectileAttack    "projectileattack"         fps 30
$sequence WallClingProjectile "wallclingprojectile"      fps 30
$sequence Jump                "jump"                     fps 30
$sequence Landing             "landing"                  fps 30
// statue poses (MannequinPoses.controller) — decorative/posing extras
$sequence DefaultPose         "defaultpose"         loop fps 30
$sequence Pose1               "pose1"               loop fps 30
$sequence Pose2               "pose2"               loop fps 30
$sequence Pose3               "pose3"               loop fps 30
$sequence Pose4               "pose4"               loop fps 30
$sequence Pose5               "pose5"               loop fps 30
$sequence Pose6               "pose6"               loop fps 30
$sequence Pose7               "pose7"               loop fps 30
$sequence Pose8               "pose8"               loop fps 30
$sequence Pose9               "pose9"               loop fps 30
$sequence AltarPose           "altarpose"           loop fps 30

// simple box 40x40x235 su; DrGBase uses its own bounds, corpse = PhysicsInitBox.
$collisionmodel "mannequin_phys.smd" {
}
