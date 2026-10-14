-- ============================================================
-- Resonance v4.0 — core/manifest.lua
-- List of all feature modules (275 files)
-- ============================================================

return {
    Combat = {
        "func_001_super_throw","func_002_massless_grab","func_003_freeze_grab","func_004_silent_aim",
        "func_005_aimbot","func_006_telekinesis","func_007_auto_throw","func_008_kill_aura",
        "func_009_hitbox_expander","func_010_wall_bang","func_011_rapid_fire","func_012_no_recoil",
        "func_013_fling_all","func_014_fling_random","func_015_fling_closest","func_016_kill_all",
        "func_017_kill_closest","func_018_kill_random","func_019_burn_all","func_020_burn_closest",
        "func_021_freeze_all","func_022_unfreeze_all","func_023_ragdoll_all","func_024_explode_all",
        "func_025_void_all","func_026_sky_all","func_027_shake_all","func_028_spin_all",
        "func_029_slow_all","func_030_speed_all","func_031_jump_all","func_032_reset_all",
        "func_033_anchor_all","func_034_unanchor_all","func_035_shirt_off_all","func_036_pants_off_all",
        "func_037_hats_off_all","func_038_drop_tools_all","func_039_forcefield_off_all","func_040_character_reset"
    },
    Auras = {
        "func_041_fling_aura","func_042_kill_aura","func_043_freeze_aura","func_044_fire_aura",
        "func_045_void_aura","func_046_attraction_aura","func_047_auto_counter","func_048_plot_kicker",
        "func_049_gravity_aura","func_050_spin_aura","func_051_damage_aura","func_052_slow_aura",
        "func_053_ragdoll_aura","func_054_teleport_aura","func_055_blind_aura","func_056_kick_aura",
        "func_057_confuse_aura","func_058_mute_aura","func_059_shrink_aura","func_060_grow_aura"
    },
    Protection = {
        "func_061_anti_grab","func_062_anti_fling","func_063_anti_freeze","func_064_anti_ragdoll",
        "func_065_anti_void","func_066_anti_vote_kick","func_067_anti_kick","func_068_anti_teleport",
        "func_069_anti_sit","func_070_anti_burn","func_071_anti_explosion","func_072_anti_damage",
        "func_073_anti_slow","func_074_anti_fire_touch","func_075_anti_gravity","func_076_anti_shrink",
        "func_077_noclip","func_078_infinite_yield","func_079_god_mode","func_080_rejoin_on_damage"
    },
    Targeting = {
        "func_081_loop_kill","func_082_loop_burn","func_083_loop_fling","func_084_loop_freeze",
        "func_085_loop_void","func_086_follow_target","func_087_view_target","func_088_tp_to_target",
        "func_089_tp_target_to_me","func_090_kill_target","func_091_fling_target","func_092_freeze_target",
        "func_093_void_target","func_094_sky_target","func_095_spin_target","func_096_orbit_target",
        "func_097_ragdoll_target","func_098_blind_target","func_099_steal_target_tools","func_100_copy_target_skin"
    },
    Movement = {
        "func_101_infinite_jump","func_102_noclip","func_103_fly","func_104_speed_boost",
        "func_105_high_jump","func_106_low_gravity","func_107_zero_gravity","func_108_auto_jump",
        "func_109_bunny_hop","func_110_slide","func_111_wall_run","func_112_crouch",
        "func_113_sprint","func_114_tp_spawn","func_115_tp_random_player","func_116_tp_forward",
        "func_117_tp_up","func_118_tp_down","func_119_tp_cursor","func_120_reset_speed"
    },
    Visuals = {
        "func_121_esp_boxes","func_122_esp_tracers","func_123_player_info","func_124_name_tags",
        "func_125_health_bars","func_126_distance_display","func_127_skeleton_esp","func_128_chams",
        "func_129_xray","func_130_fullbright","func_131_no_fog","func_132_remove_textures",
        "func_133_blue_sky","func_134_red_ambient","func_135_green_ambient","func_136_rainbow_light",
        "func_137_remove_baseplate","func_138_remove_lights","func_139_restore_lighting","func_140_disable_shadows"
    },
    Server = {
        "func_141_rejoin","func_142_server_hop","func_143_join_smallest","func_144_join_largest",
        "func_145_copy_jobid","func_146_copy_placeid","func_147_copy_server_link","func_148_show_server_info",
        "func_149_list_players","func_150_hop_until_empty","func_151_anti_afk","func_152_auto_rejoin_kick",
        "func_153_rejoin_delay","func_154_ping_display","func_155_fps_display","func_156_leave_game",
        "func_157_reset_character","func_158_character_respawn","func_159_unlock_fps","func_160_show_fps"
    },
    Utility = {
        "func_161_anti_afk","func_162_auto_claim_cash","func_163_cash_magnet","func_164_item_magnet",
        "func_165_bring_all_items","func_166_bring_all_players","func_167_clear_workspace","func_168_delete_grabbed",
        "func_169_unlock_mouse","func_170_full_screen","func_171_copy_position","func_172_copy_rotation",
        "func_173_show_position","func_174_print_character","func_175_clear_notifications","func_176_toggle_ui",
        "func_177_re_execute","func_178_reload_config","func_179_save_config","func_180_wipe_cache"
    },
    Trolling = {
        "func_181_music_play","func_182_reverse_controls","func_183_fling_random_aura","func_184_rainbow_all",
        "func_185_neon_all","func_186_shrink_all","func_187_grow_all","func_188_head_spin_all",
        "func_189_random_color_self","func_190_rainbow_self","func_191_neon_self","func_192_ghost_self",
        "func_193_invisible_self","func_194_visible_self","func_195_shake_screen_all","func_196_fake_death_all",
        "func_197_fire_trail","func_198_ice_trail","func_199_lightning_self","func_200_dance_all"
    },
    Animations = {
        "func_201_play_dance","func_202_play_wave","func_203_play_point","func_204_play_laugh",
        "func_205_play_cheer","func_206_play_floss","func_207_play_dab","func_208_play_russian",
        "func_209_play_karate","func_210_play_salsa","func_211_play_hiphop","func_212_play_breakdance",
        "func_213_play_robot","func_214_play_backflip","func_215_play_frontflip","func_216_play_sit",
        "func_217_play_lay","func_218_play_crawl","func_219_play_sprint_anim","func_220_play_swim",
        "func_221_play_climb","func_222_stop_all_anims","func_223_free_anims_off","func_224_anim_speed_up",
        "func_225_anim_slow_down"
    },
    Kick = {
        "func_226_kick_all","func_227_kick_closest","func_228_kick_random","func_229_kick_by_name",
        "func_230_kick_farthest","func_231_kick_lowest_hp","func_232_kick_highest_hp","func_233_kick_friend",
        "func_234_kick_non_friend","func_235_kick_team","func_236_kick_enemy_team","func_237_kick_afk",
        "func_238_kick_talking","func_239_kick_silent","func_240_kick_walking","func_241_kick_standing",
        "func_242_kick_jumping","func_243_kick_flying","func_244_kick_glitched","func_245_kick_invisible",
        "func_246_kick_visible","func_247_kick_high_ping","func_248_kick_low_ping","func_249_kick_mobile",
        "func_250_kick_pc","func_251_kick_console","func_252_kick_vr","func_253_kick_guest",
        "func_254_kick_premium","func_255_kick_non_premium","func_256_kick_verified","func_257_kick_non_verified",
        "func_258_kick_with_hats","func_259_kick_without_hats","func_260_kick_with_tools","func_261_kick_without_tools",
        "func_262_kick_rich","func_263_kick_poor","func_264_kick_high_level","func_265_kick_low_level",
        "func_266_kick_owner","func_267_kick_admin","func_268_kick_moderator","func_269_kick_staff",
        "func_270_kick_bots","func_271_kick_alts","func_272_kick_by_userid","func_273_kick_by_display_name",
        "func_274_kick_multiple","func_275_kick_blacklist"
    }
}