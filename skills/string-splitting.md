---
name: String splitting in EasyCoder
description: How to split strings by delimiter using position/left/from
---

# String splitting by delimiter

EasyCoder has no `split` or `before`/`after` syntax. To split a string on a delimiter (e.g. `|`):

```text
variable Pos
variable Left
variable Right

put position of `|` in MyString into Pos
put left Pos of MyString into Left
add 1 to Pos
put from Pos of MyString into Right
```

## Available string slicing commands

- `left N of Value` — first N characters
- `right N of Value` — last N characters  
- `from N of Value` — everything from position N onwards
- `from N to M of Value` — substring from position N to M
- `position of Needle in Haystack` — 0-based index of first occurrence
- `position of the last Needle in Haystack` — index of last occurrence

There is **no** `left Value before Delimiter` or `right Value after Delimiter` syntax.
