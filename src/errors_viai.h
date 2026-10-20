/* vi:set ts=8 sts=4 sw=4 et:
 *
 * Error messages of ViAI, numbered E8000 to E8999.
 */

#ifdef FEAT_EVAL
EXTERN char e_cannot_dry_run_script_already_loaded_str[]
    INIT(= N_("E8000: Cannot dry run a script that was already loaded: %s"));
EXTERN char e_not_allowed_in_dry_run[]
    INIT(= N_("E8001: Not allowed in a dry run"));
EXTERN char e_cannot_call_function_defined_by_dry_run_str[]
    INIT(= N_("E8002: Cannot call a function defined by a dry run: %s"));
EXTERN char e_cannot_replace_function_of_other_script_str[]
    INIT(= N_("E8003: A dry run cannot replace a function of another script: %s"));
#endif
