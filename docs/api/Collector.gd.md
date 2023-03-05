<!-- Auto-generated from JSON by GDScript docs maker. Do not edit this document directly. -->

# Collector.gd

**Extends:** [SceneTree](../SceneTree)

## Description

Finds and generates a code reference from gdscript files.

## Property Descriptions

### warnings\_regex

```gdscript
var warnings_regex: RegEx
```

## Method Descriptions

### find\_files

```gdscript
func find_files(dirpath: String = "", patterns: PoolStringArray = [], is_recursive: bool = false, do_skip_hidden: bool = true) -> PoolStringArray
```

### save\_text

```gdscript
func save_text(path: String = "", content: String = "") -> void
```

Saves text to a file.

### get\_reference

```gdscript
func get_reference(files: PoolStringArray = [], refresh_cache: bool = false) -> Dictionary
```

Parses a list of GDScript files and returns a list of dictionaries with the
code reference data.

If `refresh_cache` is true, will refresh Godot's cache and get fresh symbols.

### remove\_warning\_comments

```gdscript
func remove_warning_comments(symbols: Dictionary) -> void
```

Directly removes 'warning-ignore', 'warning-ignore-all', and 'warning-disable'
comments from all symbols in the `symbols` dictionary passed to the function.

### remove\_warnings\_from\_description

```gdscript
func remove_warnings_from_description(description: String) -> String
```

### print\_pretty\_json

```gdscript
func print_pretty_json(reference: Dictionary) -> String
```

