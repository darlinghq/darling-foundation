/*
 This file is part of Darling.

 Copyright (C) 2026 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

// defaults(1): reads and writes user defaults through CFPreferences, so a
// value written here is exactly what an application reading its domain with
// CFPreferences or NSUserDefaults gets.
//
// Command line syntax, messages and exit codes follow the macOS tool.
// Output of `read` uses the old-style property list text form that macOS
// prints. Behaviour that macOS documents only by example was established by
// running the macOS tool; tests/defaults-cli.sh and defaults-cli.expected
// hold those observations.

#include <CoreFoundation/CoreFoundation.h>
#include <ctype.h>
#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define EXIT_USAGE 255

// Seconds between the Unix epoch and the CFAbsoluteTime reference date.
#define UNIX_TO_CF_EPOCH 978307200.0

#define GLOBAL_DOMAIN_NAME "kCFPreferencesAnyApplication"
#define GLOBAL_DOMAIN_LISTING_NAME "Apple Global Domain"

struct domain {
	CFStringRef app;
	CFStringRef host;
	char *name; // as shown in messages
	bool global;
	bool path;
};

static void usage(void)
{
	fputs(
		"Command line interface to a user's defaults.\n"
		"Usage:\n"
		"\n"
		"defaults [-currentHost | -host <hostname>] <command> ...\n"
		"\n"
		"Commands:\n"
		"  read [<domain> [<key>]]          print all defaults, a domain or a key\n"
		"  read-type <domain> <key>         print the type of a key's value\n"
		"  write <domain> <domain_rep>      replace a domain with a dictionary\n"
		"  write <domain> <key> <value>     set a key\n"
		"  rename <domain> <old> <new>      rename a key\n"
		"  delete <domain> [<key>]          remove a domain or a key\n"
		"  delete-all <domain> [<key>]      same as delete\n"
		"  import <domain> <path | ->       merge a property list file into a domain\n"
		"  export <domain> <path>           save a domain as a binary property list\n"
		"  export <domain> -                print a domain as an XML property list\n"
		"  domains                          list the domains\n"
		"  find <word>                      print keys and values that contain word\n"
		"  help                             print this text\n"
		"\n"
		"<domain> is a domain name, -g, -globalDomain, NSGlobalDomain,\n"
		"-app <application name>, or a path to a property list file\n"
		"(the .plist extension may be left out).\n"
		"\n"
		"<value> is a property list in old-style text form, or one of:\n"
		"  -string <string>\n"
		"  -data <hex digits>\n"
		"  -int[eger] <integer>\n"
		"  -float <floating point number>\n"
		"  -bool[ean] (true | false | yes | no)\n"
		"  -date <date>\n"
		"  -array <value> ...\n"
		"  -array-add <value> ...\n"
		"  -dict <key> <value> ...\n"
		"  -dict-add <key> <value> ...\n",
		stdout);
}

static void fail_usage(void)
{
	usage();
	exit(EXIT_USAGE);
}

static char *copy_utf8(CFStringRef str)
{
	CFIndex len = CFStringGetLength(str);
	CFIndex max = CFStringGetMaximumSizeForEncoding(len, kCFStringEncodingUTF8) + 1;
	char *buf = malloc(max);
	if (!CFStringGetCString(str, buf, max, kCFStringEncodingUTF8))
		buf[0] = '\0';
	return buf;
}

static CFStringRef create_string(const char *s)
{
	CFStringRef str = CFStringCreateWithCString(NULL, s, kCFStringEncodingUTF8);
	if (!str)
		str = CFStringCreateWithCString(NULL, s, kCFStringEncodingISOLatin1);
	return str;
}

static void print_cf(FILE *f, CFStringRef str)
{
	char *buf = copy_utf8(str);
	fputs(buf, f);
	free(buf);
}

/* ---- Old-style property list text output ---- */

static void append_c(CFMutableStringRef out, const char *s)
{
	CFStringAppendCString(out, s, kCFStringEncodingUTF8);
}

static void append_indent(CFMutableStringRef out, int level)
{
	for (int i = 0; i < level; i++)
		append_c(out, "    ");
}

// Quote a string unless it is made only of ASCII letters and digits.
static void append_quoted_if_needed(CFMutableStringRef out, CFStringRef str)
{
	CFIndex len = CFStringGetLength(str);
	UniChar *chars = malloc(sizeof(UniChar) * (len ? len : 1));
	bool plain = len > 0;

	CFStringGetCharacters(str, CFRangeMake(0, len), chars);
	for (CFIndex i = 0; i < len && plain; i++) {
		UniChar c = chars[i];
		if (c >= 0x80 || !isalnum(c))
			plain = false;
	}

	if (plain) {
		CFStringAppend(out, str);
		free(chars);
		return;
	}

	CFStringAppendCString(out, "\"", kCFStringEncodingASCII);
	for (CFIndex i = 0; i < len; i++) {
		UniChar c = chars[i];
		char buf[8];

		switch (c) {
		case '"': append_c(out, "\\\""); break;
		case '\\': append_c(out, "\\\\"); break;
		case '\a': append_c(out, "\\a"); break;
		case '\b': append_c(out, "\\b"); break;
		case '\t': append_c(out, "\\t"); break;
		case '\n': append_c(out, "\\n"); break;
		case '\v': append_c(out, "\\v"); break;
		case '\f': append_c(out, "\\f"); break;
		default:
			if (c >= 0x80) {
				snprintf(buf, sizeof(buf), "\\U%04x", c);
				append_c(out, buf);
			} else {
				CFStringAppendCharacters(out, &c, 1);
			}
		}
	}
	CFStringAppendCString(out, "\"", kCFStringEncodingASCII);
	free(chars);
}

static void format_number(char *buf, size_t size, CFNumberRef num)
{
	if (CFNumberIsFloatType(num)) {
		CFNumberType type = CFNumberGetType(num);
		if (type == kCFNumberFloat32Type || type == kCFNumberFloatType) {
			float f;
			CFNumberGetValue(num, kCFNumberFloat32Type, &f);
			snprintf(buf, size, "%.7g", (double) f);
		} else {
			double d;
			CFNumberGetValue(num, kCFNumberFloat64Type, &d);
			snprintf(buf, size, "%.16g", d);
		}
	} else {
		long long v;
		CFNumberGetValue(num, kCFNumberLongLongType, &v);
		snprintf(buf, size, "%lld", v);
	}
}

static long long floor_div(long long a, long long b)
{
	long long q = a / b;
	if ((a % b) != 0 && ((a < 0) != (b < 0)))
		q--;
	return q;
}

// Days since 1970-01-01 of a proleptic Gregorian date.
static long long days_from_civil(long long y, int m, int d)
{
	y -= m <= 2;
	long long era = floor_div(y, 400);
	long long yoe = y - era * 400;
	long long doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
	long long doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
	return era * 146097 + doe - 719468;
}

static void civil_from_days(long long z, long long *y, int *m, int *d)
{
	z += 719468;
	long long era = floor_div(z, 146097);
	long long doe = z - era * 146097;
	long long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
	long long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
	long long mp = (5 * doy + 2) / 153;
	*d = (int) (doy - (153 * mp + 2) / 5 + 1);
	*m = (int) (mp < 10 ? mp + 3 : mp - 9);
	*y = yoe + era * 400 + (*m <= 2);
}

static void format_date(char *buf, size_t size, CFDateRef date)
{
	double t = floor(CFDateGetAbsoluteTime(date) + UNIX_TO_CF_EPOCH);
	long long secs = (long long) t;
	long long days = floor_div(secs, 86400);
	long long rem = secs - days * 86400;
	long long y;
	int m, d;

	civil_from_days(days, &y, &m, &d);
	snprintf(buf, size, "%04lld-%02d-%02d %02d:%02d:%02d +0000", y, m, d,
		(int) (rem / 3600), (int) (rem / 60 % 60), (int) (rem % 60));
}

static void append_data(CFMutableStringRef out, CFDataRef data)
{
	CFIndex len = CFDataGetLength(data);
	const UInt8 *bytes = CFDataGetBytePtr(data);
	char buf[64];

	snprintf(buf, sizeof(buf), "{length = %ld, bytes = 0x", (long) len);
	append_c(out, buf);

	if (len <= 24) {
		for (CFIndex i = 0; i < len; i++) {
			snprintf(buf, sizeof(buf), "%02x", bytes[i]);
			append_c(out, buf);
		}
		append_c(out, "}");
		return;
	}

	// Longer data: the first 16 and the last 8 bytes, in groups of four.
	for (CFIndex i = 0; i < 16; i++) {
		snprintf(buf, sizeof(buf), "%02x%s", bytes[i], (i % 4 == 3) ? " " : "");
		append_c(out, buf);
	}
	append_c(out, "...");
	for (CFIndex i = len - 8; i < len; i++) {
		snprintf(buf, sizeof(buf), "%s%02x", ((i - len) % 4 == 0) ? " " : "", bytes[i]);
		append_c(out, buf);
	}
	append_c(out, " }");
}

static CFComparisonResult compare_keys(const void *a, const void *b, void *ctx)
{
	(void) ctx;
	return CFStringCompare((CFStringRef) a, (CFStringRef) b, kCFCompareNonliteral);
}

static CFComparisonResult compare_names(const void *a, const void *b, void *ctx)
{
	(void) ctx;
	return CFStringCompare((CFStringRef) a, (CFStringRef) b, 0);
}

static CFArrayRef copy_sorted_keys(CFDictionaryRef dict)
{
	CFIndex count = CFDictionaryGetCount(dict);
	const void **keys = malloc(sizeof(void *) * (count ? count : 1));
	CFMutableArrayRef arr = CFArrayCreateMutable(NULL, count, &kCFTypeArrayCallBacks);

	CFDictionaryGetKeysAndValues(dict, keys, NULL);
	for (CFIndex i = 0; i < count; i++) {
		if (CFGetTypeID(keys[i]) == CFStringGetTypeID())
			CFArrayAppendValue(arr, keys[i]);
	}
	CFArraySortValues(arr, CFRangeMake(0, CFArrayGetCount(arr)), compare_keys, NULL);
	free(keys);
	return arr;
}

// Append the text form of a value. A collection starts with `level`
// indentation steps itself; its contents are one step deeper.
static void append_value(CFMutableStringRef out, CFTypeRef value, int level)
{
	CFTypeID type = CFGetTypeID(value);
	char buf[64];

	if (type == CFStringGetTypeID()) {
		append_quoted_if_needed(out, (CFStringRef) value);
	} else if (type == CFBooleanGetTypeID()) {
		append_c(out, CFBooleanGetValue((CFBooleanRef) value) ? "1" : "0");
	} else if (type == CFNumberGetTypeID() || type == CFDateGetTypeID()) {
		if (type == CFNumberGetTypeID())
			format_number(buf, sizeof(buf), (CFNumberRef) value);
		else
			format_date(buf, sizeof(buf), (CFDateRef) value);
		CFStringRef str = create_string(buf);
		append_quoted_if_needed(out, str);
		CFRelease(str);
	} else if (type == CFDataGetTypeID()) {
		append_data(out, (CFDataRef) value);
	} else if (type == CFArrayGetTypeID()) {
		CFArrayRef arr = (CFArrayRef) value;
		CFIndex count = CFArrayGetCount(arr);

		append_indent(out, level);
		append_c(out, "(\n");
		for (CFIndex i = 0; i < count; i++) {
			append_indent(out, level + 1);
			append_value(out, CFArrayGetValueAtIndex(arr, i), level + 1);
			append_c(out, (i + 1 < count) ? ",\n" : "\n");
		}
		append_indent(out, level);
		append_c(out, ")");
	} else if (type == CFDictionaryGetTypeID()) {
		CFDictionaryRef dict = (CFDictionaryRef) value;
		CFArrayRef keys = copy_sorted_keys(dict);

		append_indent(out, level);
		append_c(out, "{\n");
		for (CFIndex i = 0; i < CFArrayGetCount(keys); i++) {
			CFStringRef key = CFArrayGetValueAtIndex(keys, i);
			append_indent(out, level + 1);
			append_quoted_if_needed(out, key);
			append_c(out, " = ");
			append_value(out, CFDictionaryGetValue(dict, key), level + 1);
			append_c(out, ";\n");
		}
		append_indent(out, level);
		append_c(out, "}");
		CFRelease(keys);
	} else {
		CFStringRef desc = CFCopyDescription(value);
		CFStringAppend(out, desc);
		CFRelease(desc);
	}
}

static CFStringRef copy_value_text(CFTypeRef value)
{
	CFMutableStringRef out = CFStringCreateMutable(NULL, 0);
	append_value(out, value, 0);
	return out;
}

// What `read <domain> <key>` prints: scalars without quotes, collections in
// text form.
static void print_value(CFTypeRef value)
{
	CFTypeID type = CFGetTypeID(value);
	char buf[64];

	if (type == CFStringGetTypeID()) {
		print_cf(stdout, (CFStringRef) value);
	} else if (type == CFNumberGetTypeID()) {
		format_number(buf, sizeof(buf), (CFNumberRef) value);
		fputs(buf, stdout);
	} else if (type == CFDateGetTypeID()) {
		format_date(buf, sizeof(buf), (CFDateRef) value);
		fputs(buf, stdout);
	} else {
		CFStringRef text = copy_value_text(value);
		print_cf(stdout, text);
		CFRelease(text);
	}
	fputc('\n', stdout);
}

/* ---- Domains ---- */

static CFStringRef user(void)
{
	return kCFPreferencesCurrentUser;
}

static CFStringRef app_bundle_identifier(const char *path)
{
	struct stat st;
	CFStringRef ident = NULL;

	if (stat(path, &st) != 0 || !S_ISDIR(st.st_mode))
		return NULL;

	CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *) path, strlen(path), true);
	if (!url)
		return NULL;
	CFBundleRef bundle = CFBundleCreate(NULL, url);
	CFRelease(url);
	if (bundle) {
		ident = CFBundleGetIdentifier(bundle);
		if (ident)
			CFRetain(ident);
		CFRelease(bundle);
	}
	return ident;
}

// Find an application bundle by name in the standard application folders.
static CFStringRef copy_app_identifier(const char *name)
{
	static const char *const dirs[] = {
		"/Applications",
		"/Applications/Utilities",
		"/System/Applications",
		"/System/Applications/Utilities",
	};
	char path[PATH_MAX];
	CFStringRef ident;

	if (strchr(name, '/'))
		return app_bundle_identifier(name);

	const char *home = getenv("HOME");
	if (home) {
		snprintf(path, sizeof(path), "%s/Applications/%s.app", home, name);
		if ((ident = app_bundle_identifier(path)))
			return ident;
	}
	for (size_t i = 0; i < sizeof(dirs) / sizeof(dirs[0]); i++) {
		snprintf(path, sizeof(path), "%s/%s.app", dirs[i], name);
		if ((ident = app_bundle_identifier(path)))
			return ident;
	}
	return NULL;
}

static bool is_global_domain_name(const char *s)
{
	return strcmp(s, "-g") == 0 || strcmp(s, "-globalDomain") == 0 ||
		strcmp(s, "NSGlobalDomain") == 0 || strcmp(s, GLOBAL_DOMAIN_LISTING_NAME) == 0;
}

// Parse the domain argument(s) at argv[*idx]. Exits on errors.
static void parse_domain(int argc, char **argv, int *idx, CFStringRef host, struct domain *dom)
{
	const char *arg;

	if (*idx >= argc)
		fail_usage();
	arg = argv[*idx];
	dom->host = host;
	dom->global = false;
	dom->path = false;

	if (is_global_domain_name(arg)) {
		dom->app = kCFPreferencesAnyApplication;
		dom->name = strdup(GLOBAL_DOMAIN_NAME);
		dom->global = true;
		(*idx)++;
		return;
	}

	if (strcmp(arg, "-app") == 0) {
		if (*idx + 1 >= argc)
			fail_usage();
		const char *name = argv[*idx + 1];
		CFStringRef ident = copy_app_identifier(name);
		if (!ident) {
			fprintf(stderr, "Error: Couldn't find an application named \"%s\"; defaults unchanged\n", name);
			exit(1);
		}
		dom->app = ident;
		dom->name = copy_utf8(ident);
		*idx += 2;
		return;
	}

	if (strchr(arg, '/')) {
		// A property list file. CFPreferences takes an absolute path
		// without the extension as the application name.
		char path[PATH_MAX];
		size_t len;

		if (arg[0] == '/') {
			snprintf(path, sizeof(path), "%s", arg);
		} else {
			char cwd[PATH_MAX];
			if (!getcwd(cwd, sizeof(cwd)))
				cwd[0] = '\0';
			snprintf(path, sizeof(path), "%s/%s", cwd, arg);
		}
		len = strlen(path);
		if (len > 6 && strcmp(path + len - 6, ".plist") == 0)
			path[len - 6] = '\0';
		dom->app = create_string(path);
		dom->name = strdup(arg);
		dom->path = true;
		(*idx)++;
		return;
	}

	dom->app = create_string(arg);
	dom->name = strdup(arg);
	(*idx)++;
}

static CFDictionaryRef copy_domain(const struct domain *dom)
{
	return CFPreferencesCopyMultiple(NULL, dom->app, user(), dom->host);
}

// A domain exists while it has keys, and also after its last key was
// removed, as long as its file is still there.
static bool domain_exists(const struct domain *dom)
{
	if (dom->global)
		return true;

	CFArrayRef keys = CFPreferencesCopyKeyList(dom->app, user(), dom->host);
	if (keys) {
		bool has_keys = CFArrayGetCount(keys) > 0;
		CFRelease(keys);
		if (has_keys)
			return true;
	}

	if (dom->path) {
		char *base = copy_utf8(dom->app);
		char file[PATH_MAX];
		struct stat st;

		snprintf(file, sizeof(file), "%s.plist", base);
		free(base);
		return stat(file, &st) == 0;
	}

	CFArrayRef names = CFPreferencesCopyApplicationList(user(), dom->host);
	bool listed = names && CFArrayContainsValue(names, CFRangeMake(0, CFArrayGetCount(names)), dom->app);
	if (names)
		CFRelease(names);
	return listed;
}

static void sync_or_die(const struct domain *dom)
{
	if (!CFPreferencesSynchronize(dom->app, user(), dom->host)) {
		fprintf(stderr, "Error: Could not write domain %s; exiting\n", dom->name);
		exit(1);
	}
}

static void missing_domain(const struct domain *dom, bool changing)
{
	fprintf(stderr, "Error: Domain '%s' not found.\n", dom->name);
	if (changing)
		fputs("Defaults have not been changed.\n", stderr);
	exit(1);
}

static void missing_key(const struct domain *dom, const char *key, bool changing)
{
	fprintf(stderr, "Error: Could not find key '%s' in domain '%s'.\n", key, dom->name);
	if (changing)
		fputs("Defaults have not been changed.\n", stderr);
	exit(1);
}

/* ---- Value parsing ---- */

enum parse_result {
	PARSE_OK,
	PARSE_USAGE,
	PARSE_FAILED, // message already printed
};

// Characters that make a plain command-line value be parsed as a
// property list; any other value is taken as a string as it is.
//
// QUIRK: a value without any of these characters is stored as the literal
// string even if it would parse differently as a property list ("a = b;",
// "/* c */ x" and "123" stay strings). A value with one of them must parse,
// or the write fails with "Could not parse". Not documented beyond
// "<value_rep>". Evidence: black-box observation on macOS 27.0.1 (tier 2).
// Test: "plain values" section of tests/defaults-cli.sh.
static bool needs_plist_parse(const char *s)
{
	return strpbrk(s, "(){}<>[]\"") != NULL;
}

static enum parse_result parse_plain(const char *s, CFPropertyListRef *out)
{
	if (!needs_plist_parse(s)) {
		*out = create_string(s);
		return PARSE_OK;
	}

	CFDataRef data = CFDataCreate(NULL, (const UInt8 *) s, strlen(s));
	CFPropertyListRef plist = CFPropertyListCreateWithData(NULL, data, kCFPropertyListImmutable, NULL, NULL);
	CFRelease(data);
	if (!plist) {
		fprintf(stderr, "Error: Could not parse: %s.  Try single-quoting it.\n", s);
		return PARSE_FAILED;
	}
	*out = plist;
	return PARSE_OK;
}

// QUIRK: -int takes the leading decimal integer of its argument and ignores
// the rest; text without one gives 0 ("abc", "0x10" -> 0, "1.9" -> 1), and
// values out of range saturate. Not documented. Evidence: black-box
// observation on macOS 27.0.1 (tier 2). Test: "integers" section of
// tests/defaults-cli.sh.
static long long parse_integer(const char *s)
{
	bool neg = false;
	unsigned long long v = 0;
	bool overflow = false;

	while (isspace((unsigned char) *s))
		s++;
	if (*s == '+' || *s == '-')
		neg = *s++ == '-';
	for (; isdigit((unsigned char) *s); s++) {
		unsigned digit = *s - '0';
		if (v > (ULLONG_MAX - digit) / 10)
			overflow = true;
		else
			v = v * 10 + digit;
	}
	if (neg) {
		if (overflow || v > (unsigned long long) LLONG_MAX + 1)
			return LLONG_MIN;
		return (long long) (0 - v);
	}
	if (overflow || v > LLONG_MAX)
		return LLONG_MAX;
	return (long long) v;
}

// QUIRK: -float takes the leading decimal number of its argument (no hex,
// "inf" or "nan"; text without a number gives 0) and stores it as a 32-bit
// float. Not documented. Evidence: black-box observation on macOS 27.0.1
// (tier 2): "-float 0.1" exports as 0.10000000149011612, "-float abc" reads
// back as 0. Test: "floats" section of tests/defaults-cli.sh.
static float parse_float(const char *s)
{
	char buf[512];
	size_t n = 0;
	bool digits = false;

	while (isspace((unsigned char) *s))
		s++;
	if (*s == '+' || *s == '-')
		buf[n++] = *s++;
	while (isdigit((unsigned char) *s) && n < sizeof(buf) - 16) {
		buf[n++] = *s++;
		digits = true;
	}
	if (*s == '.') {
		buf[n++] = *s++;
		while (isdigit((unsigned char) *s) && n < sizeof(buf) - 16) {
			buf[n++] = *s++;
			digits = true;
		}
	}
	if (!digits)
		return 0;
	if (*s == 'e' || *s == 'E') {
		const char *e = s + 1;
		if (*e == '+' || *e == '-')
			e++;
		if (isdigit((unsigned char) *e)) {
			buf[n++] = *s++;
			if (*s == '+' || *s == '-')
				buf[n++] = *s++;
			while (isdigit((unsigned char) *s) && n < sizeof(buf) - 1)
				buf[n++] = *s++;
		}
	}
	buf[n] = '\0';
	return (float) strtod(buf, NULL);
}

static bool parse_bool(const char *s, bool *out)
{
	if (strcasecmp(s, "yes") == 0 || strcasecmp(s, "true") == 0) {
		*out = true;
		return true;
	}
	if (strcasecmp(s, "no") == 0 || strcasecmp(s, "false") == 0) {
		*out = false;
		return true;
	}
	return false;
}

static int hex_value(char c)
{
	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	return -1;
}

// QUIRK: an odd number of hex digits is read as if it had a leading zero
// ("abc" -> 0x0abc). Not documented. Evidence: black-box observation on
// macOS 27.0.1 (tier 2). Test: "data" section of tests/defaults-cli.sh.
static CFDataRef parse_hex(const char *s)
{
	size_t len = strlen(s);
	size_t nbytes = (len + 1) / 2;
	UInt8 *bytes = malloc(nbytes ? nbytes : 1);
	size_t pos = 0;

	for (size_t i = 0; i < len; i++) {
		if (hex_value(s[i]) < 0) {
			free(bytes);
			return NULL;
		}
	}
	if (len % 2) {
		bytes[pos++] = hex_value(s[0]);
		s++;
	}
	for (; *s; s += 2)
		bytes[pos++] = (hex_value(s[0]) << 4) | hex_value(s[1]);

	CFDataRef data = CFDataCreate(NULL, bytes, nbytes);
	free(bytes);
	return data;
}

static bool parse_digits(const char **p, int count, int *out)
{
	int v = 0;
	for (int i = 0; i < count; i++) {
		if (!isdigit((unsigned char) (*p)[i]))
			return false;
		v = v * 10 + ((*p)[i] - '0');
	}
	*p += count;
	*out = v;
	return true;
}

// Parse a UTC offset: Z, GMT, UTC, +HHMM, +HH:MM or +HH. Empty means UTC.
static bool parse_zone(const char *p, int *offset)
{
	int sign, hh, mm = 0;

	while (*p == ' ')
		p++;
	*offset = 0;
	if (*p == '\0')
		return true;
	if (strcmp(p, "Z") == 0 || strcmp(p, "GMT") == 0 || strcmp(p, "UTC") == 0)
		return true;
	if (*p != '+' && *p != '-')
		return false;
	sign = (*p++ == '-') ? -1 : 1;
	if (!parse_digits(&p, 2, &hh))
		return false;
	if (*p == ':')
		p++;
	if (*p && !parse_digits(&p, 2, &mm))
		return false;
	if (*p || hh > 23 || mm > 59)
		return false;
	*offset = sign * (hh * 3600 + mm * 60);
	return true;
}

static bool make_date(long long y, int mo, int d, int h, int mi, int s, int offset, CFDateRef *out)
{
	if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 60)
		return false;
	double secs = (double) days_from_civil(y, mo, d) * 86400.0 + h * 3600 + mi * 60 + s - offset;
	*out = CFDateCreate(NULL, secs - UNIX_TO_CF_EPOCH);
	return true;
}

// -date accepts "YYYY-MM-DD HH:MM:SS [zone]" (also with a T separator and
// no zone, which means UTC) and the RFC 822 form
// "[Www, ]DD Mon YYYY HH:MM:SS zone".
static bool parse_date(const char *s, CFDateRef *out)
{
	static const char *const months[] = {
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
	};
	const char *p = s;
	int y, mo, d, h, mi, sec, offset;

	while (*p == ' ')
		p++;

	if (parse_digits(&p, 4, &y) && *p == '-') {
		p++;
		if (!parse_digits(&p, 2, &mo) || *p++ != '-' || !parse_digits(&p, 2, &d))
			return false;
		if (*p != ' ' && *p != 'T')
			return false;
		p++;
		if (!parse_digits(&p, 2, &h) || *p++ != ':' || !parse_digits(&p, 2, &mi) ||
				*p++ != ':' || !parse_digits(&p, 2, &sec))
			return false;
		if (!parse_zone(p, &offset))
			return false;
		return make_date(y, mo, d, h, mi, sec, offset, out);
	}

	// RFC 822
	p = s;
	while (*p == ' ')
		p++;
	if (isalpha((unsigned char) p[0])) {
		const char *comma = strchr(p, ',');
		if (!comma)
			return false;
		p = comma + 1;
		while (*p == ' ')
			p++;
	}
	if (!isdigit((unsigned char) *p))
		return false;
	d = 0;
	while (isdigit((unsigned char) *p))
		d = d * 10 + (*p++ - '0');
	if (*p++ != ' ')
		return false;
	mo = 0;
	for (int i = 0; i < 12; i++) {
		if (strncasecmp(p, months[i], 3) == 0) {
			mo = i + 1;
			break;
		}
	}
	if (!mo)
		return false;
	p += 3;
	if (*p++ != ' ' || !parse_digits(&p, 4, &y) || *p++ != ' ')
		return false;
	if (!parse_digits(&p, 2, &h) || *p++ != ':' || !parse_digits(&p, 2, &mi) ||
			*p++ != ':' || !parse_digits(&p, 2, &sec))
		return false;
	if (!parse_zone(p, &offset))
		return false;
	return make_date(y, mo, d, h, mi, sec, offset, out);
}

static bool is_composite_flag(const char *s)
{
	return strcmp(s, "-array") == 0 || strcmp(s, "-array-add") == 0 ||
		strcmp(s, "-dict") == 0 || strcmp(s, "-dict-add") == 0;
}

// Parse one value at argv[*idx]: a type flag with its argument, or a plain
// value. Composite flags (-array, -dict, ...) are handled by the caller.
static enum parse_result parse_value(int argc, char **argv, int *idx, CFPropertyListRef *out)
{
	const char *flag = argv[*idx];
	const char *arg;

	if (is_composite_flag(flag)) {
		fputs("Error: Cannot nest composite types (arrays and dictionaries); exiting\n", stderr);
		return PARSE_FAILED;
	}

	if (strcmp(flag, "-string") != 0 && strcmp(flag, "-data") != 0 &&
			strcmp(flag, "-int") != 0 && strcmp(flag, "-integer") != 0 &&
			strcmp(flag, "-float") != 0 && strcmp(flag, "-bool") != 0 &&
			strcmp(flag, "-boolean") != 0 && strcmp(flag, "-date") != 0) {
		(*idx)++;
		return parse_plain(flag, out);
	}

	if (*idx + 1 >= argc)
		return PARSE_USAGE;
	arg = argv[*idx + 1];
	*idx += 2;

	if (strcmp(flag, "-string") == 0) {
		*out = create_string(arg);
	} else if (strcmp(flag, "-data") == 0) {
		*out = parse_hex(arg);
		if (!*out)
			return PARSE_USAGE;
	} else if (strcmp(flag, "-int") == 0 || strcmp(flag, "-integer") == 0) {
		long long v = parse_integer(arg);
		*out = CFNumberCreate(NULL, kCFNumberLongLongType, &v);
	} else if (strcmp(flag, "-float") == 0) {
		float f = parse_float(arg);
		*out = CFNumberCreate(NULL, kCFNumberFloat32Type, &f);
	} else if (strcmp(flag, "-bool") == 0 || strcmp(flag, "-boolean") == 0) {
		bool b;
		if (!parse_bool(arg, &b))
			return PARSE_USAGE;
		*out = CFRetain(b ? kCFBooleanTrue : kCFBooleanFalse);
	} else {
		CFDateRef date;
		if (!parse_date(arg, &date))
			return PARSE_USAGE;
		*out = date;
	}
	return PARSE_OK;
}

static void check_parse(enum parse_result r)
{
	if (r == PARSE_USAGE)
		fail_usage();
	if (r == PARSE_FAILED)
		exit(1);
}

/* ---- Commands ---- */

static int cmd_read_all(CFStringRef host)
{
	CFMutableDictionaryRef all = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFArrayRef names = CFPreferencesCopyApplicationList(user(), host);
	CFDictionaryRef dict;

	dict = CFPreferencesCopyMultiple(NULL, kCFPreferencesAnyApplication, user(), host);
	if (dict) {
		if (CFDictionaryGetCount(dict))
			CFDictionarySetValue(all, CFSTR(GLOBAL_DOMAIN_LISTING_NAME), dict);
		CFRelease(dict);
	}
	for (CFIndex i = 0; names && i < CFArrayGetCount(names); i++) {
		CFStringRef name = CFArrayGetValueAtIndex(names, i);
		if (CFEqual(name, kCFPreferencesAnyApplication))
			continue;
		dict = CFPreferencesCopyMultiple(NULL, name, user(), host);
		if (dict) {
			if (CFDictionaryGetCount(dict))
				CFDictionarySetValue(all, name, dict);
			CFRelease(dict);
		}
	}
	print_value(all);
	if (names)
		CFRelease(names);
	CFRelease(all);
	return 0;
}

static int cmd_read(int argc, char **argv, int idx, CFStringRef host)
{
	struct domain dom;

	if (idx >= argc)
		return cmd_read_all(host);
	parse_domain(argc, argv, &idx, host, &dom);
	if (!domain_exists(&dom))
		missing_domain(&dom, false);

	if (idx < argc) {
		CFStringRef key = create_string(argv[idx]);
		CFPropertyListRef value = CFPreferencesCopyValue(key, dom.app, user(), dom.host);
		if (!value)
			missing_key(&dom, argv[idx], false);
		print_value(value);
		return 0;
	}

	CFDictionaryRef dict = copy_domain(&dom);
	if (!dict)
		dict = CFDictionaryCreate(NULL, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	print_value(dict);
	return 0;
}

static const char *type_name(CFTypeRef value)
{
	CFTypeID type = CFGetTypeID(value);

	if (type == CFStringGetTypeID())
		return "string";
	if (type == CFBooleanGetTypeID())
		return "boolean";
	if (type == CFNumberGetTypeID())
		return CFNumberIsFloatType((CFNumberRef) value) ? "float" : "integer";
	if (type == CFDateGetTypeID())
		return "date";
	if (type == CFDataGetTypeID())
		return "data";
	if (type == CFArrayGetTypeID())
		return "array";
	if (type == CFDictionaryGetTypeID())
		return "dictionary";
	return "unknown";
}

static int cmd_read_type(int argc, char **argv, int idx, CFStringRef host)
{
	struct domain dom;

	parse_domain(argc, argv, &idx, host, &dom);
	if (idx >= argc)
		fail_usage();
	if (!domain_exists(&dom))
		missing_domain(&dom, false);

	CFStringRef key = create_string(argv[idx]);
	CFPropertyListRef value = CFPreferencesCopyValue(key, dom.app, user(), dom.host);
	if (!value)
		missing_key(&dom, argv[idx], false);
	printf("Type is %s\n", type_name(value));
	return 0;
}

// Replace the contents of a domain with dict.
static void replace_domain(const struct domain *dom, CFDictionaryRef dict)
{
	CFArrayRef old = CFPreferencesCopyKeyList(dom->app, user(), dom->host);
	CFMutableArrayRef remove = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);

	for (CFIndex i = 0; old && i < CFArrayGetCount(old); i++) {
		CFStringRef key = CFArrayGetValueAtIndex(old, i);
		if (!dict || !CFDictionaryContainsKey(dict, key))
			CFArrayAppendValue(remove, key);
	}
	CFPreferencesSetMultiple(dict, remove, dom->app, user(), dom->host);
	sync_or_die(dom);
	if (old)
		CFRelease(old);
	CFRelease(remove);
}

static int write_domain_rep(const struct domain *dom, const char *rep)
{
	CFPropertyListRef plist;

	check_parse(parse_plain(rep, &plist));
	if (CFGetTypeID(plist) != CFDictionaryGetTypeID()) {
		fputs("Error: Rep argument is not a dictionary\nDefaults have not been changed.\n", stderr);
		return 1;
	}
	replace_domain(dom, plist);
	CFRelease(plist);
	return 0;
}

static int cmd_write(int argc, char **argv, int idx, CFStringRef host)
{
	struct domain dom;
	CFPropertyListRef value = NULL;

	parse_domain(argc, argv, &idx, host, &dom);
	if (idx >= argc)
		fail_usage();
	if (idx + 1 == argc)
		return write_domain_rep(&dom, argv[idx]);

	const char *key_arg = argv[idx++];
	CFStringRef key = create_string(key_arg);
	const char *flag = argv[idx];

	if (strcmp(flag, "-array") == 0 || strcmp(flag, "-array-add") == 0) {
		bool add = strcmp(flag, "-array-add") == 0;
		CFMutableArrayRef arr = NULL;

		if (add) {
			CFPropertyListRef existing = CFPreferencesCopyValue(key, dom.app, user(), dom.host);
			if (existing) {
				if (CFGetTypeID(existing) != CFArrayGetTypeID()) {
					fprintf(stderr, "Error: Value for key %s is not an array; cannot append.  Leaving defaults unchanged.\n", key_arg);
					return 1;
				}
				arr = CFArrayCreateMutableCopy(NULL, 0, existing);
				CFRelease(existing);
			}
		}
		if (!arr)
			arr = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);

		for (idx++; idx < argc;) {
			CFPropertyListRef elem;
			check_parse(parse_value(argc, argv, &idx, &elem));
			CFArrayAppendValue(arr, elem);
			CFRelease(elem);
		}
		value = arr;
	} else if (strcmp(flag, "-dict") == 0 || strcmp(flag, "-dict-add") == 0) {
		bool add = strcmp(flag, "-dict-add") == 0;
		CFMutableDictionaryRef dict = NULL;

		if (add) {
			CFPropertyListRef existing = CFPreferencesCopyValue(key, dom.app, user(), dom.host);
			if (existing) {
				if (CFGetTypeID(existing) != CFDictionaryGetTypeID()) {
					fprintf(stderr, "Error: Value for key %s is not a dictionary; cannot append.  Leaving defaults unchanged.\n", key_arg);
					return 1;
				}
				dict = CFDictionaryCreateMutableCopy(NULL, 0, existing);
				CFRelease(existing);
			}
		}
		if (!dict)
			dict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

		for (idx++; idx < argc;) {
			CFPropertyListRef k, v;
			check_parse(parse_value(argc, argv, &idx, &k));
			if (CFGetTypeID(k) != CFStringGetTypeID()) {
				fputs("Error: Dictionary keys must be strings\n", stderr);
				return 1;
			}
			if (idx >= argc) {
				fputs("Error: Key ", stderr);
				print_cf(stderr, k);
				fputs(" lacks a corresponding value\n", stderr);
				return 1;
			}
			check_parse(parse_value(argc, argv, &idx, &v));
			CFDictionarySetValue(dict, k, v);
			CFRelease(k);
			CFRelease(v);
		}
		value = dict;
	} else {
		check_parse(parse_value(argc, argv, &idx, &value));
		if (idx < argc) {
			fprintf(stderr, "Error: Unexpected argument %s; leaving defaults unchanged.\n", argv[idx]);
			return 1;
		}
	}

	CFPreferencesSetValue(key, value, dom.app, user(), dom.host);
	sync_or_die(&dom);
	CFRelease(value);
	CFRelease(key);
	return 0;
}

static int cmd_rename(int argc, char **argv, int idx, CFStringRef host)
{
	struct domain dom;

	parse_domain(argc, argv, &idx, host, &dom);
	if (idx + 2 > argc)
		fail_usage();

	CFStringRef old_key = create_string(argv[idx]);
	CFStringRef new_key = create_string(argv[idx + 1]);
	CFPropertyListRef value = CFPreferencesCopyValue(old_key, dom.app, user(), dom.host);

	if (!value) {
		fprintf(stderr, "Error: Key %s does not exist in domain %s; leaving defaults unchanged\n", argv[idx], dom.name);
		return 1;
	}
	if (CFEqual(old_key, new_key))
		return 0;

	CFDictionaryRef set = CFDictionaryCreate(NULL, (const void **) &new_key, (const void **) &value, 1,
		&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFArrayRef remove = CFArrayCreate(NULL, (const void **) &old_key, 1, &kCFTypeArrayCallBacks);
	CFPreferencesSetMultiple(set, remove, dom.app, user(), dom.host);
	sync_or_die(&dom);
	CFRelease(set);
	CFRelease(remove);
	return 0;
}

static int cmd_delete(int argc, char **argv, int idx, CFStringRef host)
{
	struct domain dom;

	parse_domain(argc, argv, &idx, host, &dom);
	if (!domain_exists(&dom))
		missing_domain(&dom, true);

	if (idx < argc) {
		CFStringRef key = create_string(argv[idx]);
		CFPropertyListRef value = CFPreferencesCopyValue(key, dom.app, user(), dom.host);
		if (!value)
			missing_key(&dom, argv[idx], true);
		CFRelease(value);
		CFPreferencesSetValue(key, NULL, dom.app, user(), dom.host);
		sync_or_die(&dom);
		return 0;
	}

	replace_domain(&dom, NULL);
	return 0;
}

static CFDataRef read_input(const char *path)
{
	FILE *f = strcmp(path, "-") == 0 ? stdin : fopen(path, "rb");
	CFMutableDataRef data;
	UInt8 buf[16384];
	size_t n;

	if (!f)
		return NULL;
	data = CFDataCreateMutable(NULL, 0);
	while ((n = fread(buf, 1, sizeof(buf), f)) > 0)
		CFDataAppendBytes(data, buf, n);
	if (ferror(f)) {
		CFRelease(data);
		data = NULL;
	}
	if (f != stdin)
		fclose(f);
	return data;
}

static int cmd_import(int argc, char **argv, int idx, CFStringRef host)
{
	struct domain dom;
	CFErrorRef error = NULL;

	parse_domain(argc, argv, &idx, host, &dom);
	if (idx >= argc) {
		fputs("Error: Need a path to read from\n", stderr);
		return 1;
	}

	const char *path = argv[idx];
	CFDataRef data = read_input(path);
	if (!data) {
		fprintf(stderr, "Error: Could not read data from %s\n", path);
		return 1;
	}

	CFPropertyListRef plist = CFPropertyListCreateWithData(NULL, data, kCFPropertyListImmutable, NULL, &error);
	CFRelease(data);
	if (!plist) {
		fprintf(stderr, "Error: Could not parse property list from %s due to ", path);
		if (error) {
			CFStringRef desc = CFCopyDescription(error);
			print_cf(stderr, desc);
			CFRelease(desc);
			CFRelease(error);
		}
		fputc('\n', stderr);
		return 1;
	}
	if (CFGetTypeID(plist) != CFDictionaryGetTypeID()) {
		CFStringRef text = copy_value_text(plist);
		fputs("Error: Property list ", stderr);
		print_cf(stderr, text);
		fputs(" was not a dictionary\nDefaults have not been changed.\n", stderr);
		CFRelease(text);
		return 1;
	}

	// Keys that are already in the domain and not in the file are kept.
	CFPreferencesSetMultiple(plist, NULL, dom.app, user(), dom.host);
	sync_or_die(&dom);
	CFRelease(plist);
	return 0;
}

static int cmd_export(int argc, char **argv, int idx, CFStringRef host)
{
	struct domain dom;

	parse_domain(argc, argv, &idx, host, &dom);
	if (idx >= argc) {
		fputs("Error: Need a path to write to\n", stderr);
		return 1;
	}

	const char *path = argv[idx];
	bool to_stdout = strcmp(path, "-") == 0;
	CFDictionaryRef dict = copy_domain(&dom);
	if (!dict)
		dict = CFDictionaryCreate(NULL, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	CFDataRef data = CFPropertyListCreateData(NULL, dict,
		to_stdout ? kCFPropertyListXMLFormat_v1_0 : kCFPropertyListBinaryFormat_v1_0, 0, NULL);
	CFRelease(dict);
	if (!data) {
		fprintf(stderr, "Error: Could not write to %s\n", path);
		return 1;
	}

	FILE *f = to_stdout ? stdout : fopen(path, "wb");
	bool ok = f && fwrite(CFDataGetBytePtr(data), 1, CFDataGetLength(data), f) == (size_t) CFDataGetLength(data);
	if (f && f != stdout && fclose(f) != 0)
		ok = false;
	CFRelease(data);
	if (!ok) {
		fprintf(stderr, "Error: Could not write to %s\n", path);
		return 1;
	}
	return 0;
}

static CFArrayRef copy_domain_names(CFStringRef host)
{
	CFArrayRef list = CFPreferencesCopyApplicationList(user(), host);
	CFMutableArrayRef names = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);

	for (CFIndex i = 0; list && i < CFArrayGetCount(list); i++) {
		CFStringRef name = CFArrayGetValueAtIndex(list, i);
		if (!CFEqual(name, kCFPreferencesAnyApplication))
			CFArrayAppendValue(names, name);
	}
	CFArraySortValues(names, CFRangeMake(0, CFArrayGetCount(names)), compare_names, NULL);
	if (list)
		CFRelease(list);
	return names;
}

static int cmd_domains(CFStringRef host)
{
	CFArrayRef names = copy_domain_names(host);
	CFStringRef joined = CFStringCreateByCombiningStrings(NULL, names, CFSTR(", "));

	print_cf(stdout, joined);
	fputc('\n', stdout);
	CFRelease(joined);
	CFRelease(names);
	return 0;
}

static bool contains_word(CFStringRef str, CFStringRef word)
{
	return CFStringFind(str, word, kCFCompareCaseInsensitive).location != kCFNotFound;
}

static bool value_contains(CFTypeRef value, CFStringRef word)
{
	CFTypeID type = CFGetTypeID(value);

	if (type == CFStringGetTypeID())
		return contains_word(value, word);
	if (type == CFArrayGetTypeID()) {
		for (CFIndex i = 0; i < CFArrayGetCount(value); i++) {
			if (value_contains(CFArrayGetValueAtIndex(value, i), word))
				return true;
		}
		return false;
	}
	if (type == CFDictionaryGetTypeID()) {
		CFIndex count = CFDictionaryGetCount(value);
		const void **keys = malloc(sizeof(void *) * (count ? count : 1) * 2);
		const void **values = keys + (count ? count : 1);
		bool found = false;

		CFDictionaryGetKeysAndValues(value, keys, values);
		for (CFIndex i = 0; i < count && !found; i++)
			found = value_contains(keys[i], word) || value_contains(values[i], word);
		free(keys);
		return found;
	}
	return false;
}

// Print the matching keys of one domain; returns whether anything matched.
static bool find_in_domain(CFStringRef app, CFStringRef display, CFStringRef word, CFStringRef host)
{
	CFDictionaryRef dict = CFPreferencesCopyMultiple(NULL, app, user(), host);
	CFMutableDictionaryRef found;
	bool whole;

	if (!dict)
		return false;
	whole = contains_word(display, word);
	found = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	CFIndex count = CFDictionaryGetCount(dict);
	const void **keys = malloc(sizeof(void *) * (count ? count : 1) * 2);
	const void **values = keys + (count ? count : 1);
	CFDictionaryGetKeysAndValues(dict, keys, values);
	for (CFIndex i = 0; i < count; i++) {
		if (whole || value_contains(keys[i], word) || value_contains(values[i], word))
			CFDictionarySetValue(found, keys[i], values[i]);
	}
	free(keys);
	CFRelease(dict);

	bool any = CFDictionaryGetCount(found) > 0;
	if (any) {
		CFStringRef text = copy_value_text(found);
		printf("Found %ld keys in domain '", (long) CFDictionaryGetCount(found));
		print_cf(stdout, display);
		fputs("': ", stdout);
		print_cf(stdout, text);
		fputc('\n', stdout);
		CFRelease(text);
	}
	CFRelease(found);
	return any;
}

static int cmd_find(int argc, char **argv, int idx, CFStringRef host)
{
	if (idx >= argc)
		fail_usage();

	CFStringRef word = create_string(argv[idx]);
	CFArrayRef names = copy_domain_names(host);
	bool any = find_in_domain(kCFPreferencesAnyApplication, CFSTR(GLOBAL_DOMAIN_LISTING_NAME), word, host);

	for (CFIndex i = 0; i < CFArrayGetCount(names); i++) {
		CFStringRef name = CFArrayGetValueAtIndex(names, i);
		if (find_in_domain(name, name, word, host))
			any = true;
	}
	if (!any)
		fprintf(stderr, "Error: No domain, key, nor value containing '%s'\n", argv[idx]);
	CFRelease(names);
	CFRelease(word);
	return 0;
}

int main(int argc, char **argv)
{
	CFStringRef host = kCFPreferencesAnyHost;
	int idx = 1;

	// Options that come before the command.
	while (idx < argc) {
		if (strcmp(argv[idx], "-currentHost") == 0) {
			host = kCFPreferencesCurrentHost;
			idx++;
		} else if (strcmp(argv[idx], "-host") == 0) {
			if (idx + 1 >= argc)
				fail_usage();
			host = create_string(argv[idx + 1]);
			idx += 2;
		} else if (strcmp(argv[idx], "-verbose") == 0) {
			idx++;
		} else {
			break;
		}
	}

	if (idx >= argc)
		fail_usage();

	const char *cmd = argv[idx++];

	if (strcmp(cmd, "read") == 0)
		return cmd_read(argc, argv, idx, host);
	if (strcmp(cmd, "read-type") == 0)
		return cmd_read_type(argc, argv, idx, host);
	if (strcmp(cmd, "write") == 0)
		return cmd_write(argc, argv, idx, host);
	if (strcmp(cmd, "rename") == 0)
		return cmd_rename(argc, argv, idx, host);
	if (strcmp(cmd, "delete") == 0 || strcmp(cmd, "delete-all") == 0)
		return cmd_delete(argc, argv, idx, host);
	if (strcmp(cmd, "import") == 0)
		return cmd_import(argc, argv, idx, host);
	if (strcmp(cmd, "export") == 0)
		return cmd_export(argc, argv, idx, host);
	if (strcmp(cmd, "domains") == 0)
		return cmd_domains(host);
	if (strcmp(cmd, "find") == 0)
		return cmd_find(argc, argv, idx, host);
	if (strcmp(cmd, "help") == 0) {
		usage();
		return 0;
	}
	fail_usage();
	return EXIT_USAGE;
}
