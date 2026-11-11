# Nil values in a KVC dictionary

Build `kvc-nil-values.m` as an Objective-C executable linked to Foundation and
run it with the candidate framework. Assertions remain enabled with NDEBUG.
It checks present/nil values, empty and repeated key lists, and propagation of
an undefined-key exception. Expected marker:

`PASS: KVC dictionary nil substitution and undefined-key behavior`

[Apple's documented contract](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/dictionarywithvalues%28forkeys%3A%29)
requires returned nil property values to be represented by NSNull. Merely
allowing nil dictionary subscript assignments to remove keys does not satisfy
this contract: requested nil-valued keys must remain in the result.
