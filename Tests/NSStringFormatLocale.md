# NSString format with a locale

Build NSStringFormatLocale.m against Foundation/CoreFoundation and run it under Darling. It formats numbers through `-[NSString initWithFormat:locale:arguments:]` (immutable and mutable) with fr_FR, de_DE and a nil locale, and expects the locale's decimal and grouping separators (`1,5`, `1.234.567 / 1.234,50`) and plain `1.5` for nil (#889).

Baseline: every locale case prints the unlocalized value (`1.5`, `1234567 / 1234.50`) and fails; candidate: zero failures.
