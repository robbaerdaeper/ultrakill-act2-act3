$modelname "ultrakill_prelude_test/gutterman_diag_formula_idle.mdl"
$scale 2500.0
$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"
$body "body" "gutterman_diag_raw_weighted.smd"
$sequence RefLoop "idle_ref_loop_probe" loop fps 30
$sequence Abs "formula_abs" loop fps 30
$sequence Formula_A "formula_a_rest_baseinv_pose" loop fps 30
$sequence Formula_B "formula_b_rest_pose_baseinv" loop fps 30
$sequence Formula_C "formula_c_baseinv_pose_rest" loop fps 30
$sequence Formula_D "formula_d_pose_baseinv_rest" loop fps 30
$sequence Formula_E "formula_e_base_restinv_pose" loop fps 30
$sequence Formula_F "formula_f_pose_restinv_base" loop fps 30
