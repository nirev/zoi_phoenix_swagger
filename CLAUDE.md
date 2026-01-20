# Claude Code Instructions

## Commit Messages

- Do NOT include the "Generated with Claude Code" disclaimer
- Do NOT prefix with "Test X:" - just describe what the commit adds
- Only include the co-authored by line at the end:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Test Assertions

- All map/struct assertions in tests should use pattern matching or `==` operator on complete structures
- Do NOT assert individual keys one by one
- DO assert the entire map structure at once

**Bad:**
```elixir
assert swagger_schema.properties.tags.type == :array
assert swagger_schema.properties.tags.items.type == :string
assert swagger_schema.example.tags == ["tag1", "tag2"]
```

**Good:**
```elixir
assert %{
  properties: %{
    tags: %{
      type: :array,
      items: %{type: :string}
    }
  },
  example: %{
    tags: ["tag1", "tag2"]
  }
} == swagger_schema
```
