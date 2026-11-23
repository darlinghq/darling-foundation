# NSCalendar calendarWithIdentifier:

Build nscalendar-calendarwithidentifier.m against Foundation/CoreFoundation and run it under Darling. It checks `+[NSCalendar calendarWithIdentifier:]` against the public documentation: the result is a new calendar for the identifier (gregorian, ISO 8601, Hebrew, Buddhist and Japanese are checked), it defaults to the default time zone and (as observed on macOS 10.14.4 and 26.7.3, unlike the documentation) the system locale, an unrecognized identifier gives nil, and a gregorian calendar in UTC gives 2001-01-01 00:00:00 for the reference date and builds the reference date back from 2001-01-01. It also checks that `-initWithCalendarIdentifier:` still behaves.

Baseline: against the base commit the header has no `+calendarWithIdentifier:` declaration and the first call raises `unrecognized selector`; candidate: zero failures.

The identifier round trip through `-calendarIdentifier`, `isEqual:` between two calendars made the same way, and nil for the empty string are not stated on the documentation page; they are marked GUESS in the source.
