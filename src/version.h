/* vi:set ts=8 sts=4 sw=4 noet:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

/*
 * Define the version number, name, etc.
 * The patchlevel is in included_patches[], in version.c.
 */

// Trick to turn a number into a string.
#define VIM_TOSTR_(a)			#a
#define VIM_TOSTR(a)			VIM_TOSTR_(a)

// Values that change for a new release.
#define VIM_VERSION_MAJOR		9
#define VIM_VERSION_MINOR		2
#define VIM_VERSION_BUILD		286
#define VIM_VERSION_BUILD_BCD		0x11e
#define VIM_VERSION_DATE_ONLY		"2026 Feb 14"

// Values based on the above
#define VIM_VERSION_MAJOR_STR		VIM_TOSTR(VIM_VERSION_MAJOR)
#define VIM_VERSION_MINOR_STR		VIM_TOSTR(VIM_VERSION_MINOR)
#define VIM_VERSION_100	    (VIM_VERSION_MAJOR * 100 + VIM_VERSION_MINOR)

// ViAI version.
#define VIAI_VERSION_MAJOR		1
#define VIAI_VERSION_MINOR		0
#define VIAI_VERSION_DATE_ONLY		"2026 Oct 14"
#define VIAI_VERSION_100	    (VIAI_VERSION_MAJOR * 100 + VIAI_VERSION_MINOR)

#define VIAI_VERSION_MAJOR_STR		VIM_TOSTR(VIAI_VERSION_MAJOR)
#define VIAI_VERSION_MINOR_STR		VIM_TOSTR(VIAI_VERSION_MINOR)
#ifndef VIAI_VERSION_PATCHLEVEL
# define VIAI_VERSION_PATCHLEVEL	0
#endif

// ViAI patchlevel with leading zeros, e.g. "0003"
#if VIAI_VERSION_PATCHLEVEL < 10
# define VIAI_LEADZERO	000
#elif VIAI_VERSION_PATCHLEVEL < 100
# define VIAI_LEADZERO	00
#elif VIAI_VERSION_PATCHLEVEL < 1000
# define VIAI_LEADZERO	0
#else
# define VIAI_LEADZERO
#endif
// Expand the arguments before pasting them.
#define VIAI_PASTE_(a, b)	a ## b
#define VIAI_PASTE(a, b)	VIAI_PASTE_(a, b)
#define VIAI_VERSION_PATCHLEVEL_STR \
	    VIM_TOSTR(VIAI_PASTE(VIAI_LEADZERO, VIAI_VERSION_PATCHLEVEL))

#define VIM_VERSION_BUILD_STR		VIM_TOSTR(VIM_VERSION_BUILD)
#ifndef VIM_VERSION_PATCHLEVEL
# define VIM_VERSION_PATCHLEVEL		0
#endif

// Patchlevel with leading zeros
// For compatibility with the installer from "vim-win32-installer" and WinGet.
// For details see https://github.com/vim/vim-win32-installer/pull/277
// and https://github.com/vim/vim-win32-installer/pull/285
#if VIM_VERSION_PATCHLEVEL < 10
# define LEADZERO(x) 000 ## x
#elif VIM_VERSION_PATCHLEVEL < 100
# define LEADZERO(x) 00 ## x
#elif VIM_VERSION_PATCHLEVEL < 1000
# define LEADZERO(x) 0 ## x
#else
# define LEADZERO(x) x
#endif

#define VIM_VERSION_PATCHLEVEL_STR	VIM_TOSTR(LEADZERO(VIM_VERSION_PATCHLEVEL))
// Used by MacOS port; should be one of: development, alpha, beta, final
#define VIM_VERSION_RELEASE		final

/*
 * VIM_VERSION_NODOT is used for the runtime directory name.
 * VIM_VERSION_SHORT is copied into the swap file (max. length is 6 chars).
 * VIAI_VERSION_SHORT is used for the startup-screen.
 * VIM_VERSION_LONG is used for the ":version" command and "Vim -h".
 */
#define VIM_VERSION_NODOT \
		"viai" VIAI_VERSION_MAJOR_STR VIAI_VERSION_MINOR_STR
#define VIM_VERSION_SHORT     VIM_VERSION_MAJOR_STR "." VIM_VERSION_MINOR_STR
#define VIM_VERSION_MEDIUM    VIM_VERSION_SHORT
#define VIAI_VERSION_SHORT    VIAI_VERSION_MAJOR_STR "." VIAI_VERSION_MINOR_STR
#define VIM_VERSION_LONG_ONLY \
		"ViAI - Vim Advanced Integrated " VIAI_VERSION_SHORT
#define VIM_VERSION_LONG_HEAD VIM_VERSION_LONG_ONLY " (" VIAI_VERSION_DATE_ONLY
#define VIM_VERSION_LONG      VIM_VERSION_LONG_HEAD ")"
#define VIM_VERSION_LONG_DATE VIM_VERSION_LONG_HEAD ", compiled "
