import Foundation

/// Self-contained prompt the user copies into any AI chat to generate a routine JSON.
public enum AIRoutinePrompt {
    public static let text: String = """
    You are designing a routine for the HabitTracker iOS app. \
    Reply with ONE JSON object (no commentary, no markdown fences) matching the schema below.

    Top-level object:
    {
      "name": "<short routine title, required>",
      "description": "<one-sentence summary, optional>",
      "color": "<#RRGGBB hex, optional, defaults to #34C759>",
      "habits": [ /* 1..100 habits, order is preserved */ ]
    }

    Each habit object:
    {
      "name": "<short title, required>",
      "type": "task" | "timer" | "tracking" | "guidedSequence" | "website" | "shortcut",
      "isOptional": false,                  // optional, default false
      "notes": "<extra context, optional>",
      "color": "<#RRGGBB hex, optional>"
      // plus the fields for the chosen type, listed below
    }

    Per-type fields:

    1. "task" — a checklist item, with optional subtasks.
       "subtasks": [
         "Plain item",                              // string form (required by default)
         { "name": "Stretch left",  "isOptional": false },
         { "name": "Stretch right", "isOptional": true } // object form, lets you mark optional
       ],
       "minRequired": 2,                            // optional; when set, ANY N of M is sufficient
                                                    // (overrides individual isOptional flags)
       "estimatedSeconds": 120                      // optional, overrides default duration

    2. "timer" — a timer of one of three styles.
       "timer": {
         "style": "down" | "up" | "multiple",
         "durationSeconds": 300,           // required for "down"
         "targetSeconds": 600,             // optional, only meaningful for "up"
         "steps": [                        // required for "multiple"
           { "name": "Inhale",  "durationSeconds": 4 },
           { "name": "Hold",    "durationSeconds": 4 },
           { "name": "Exhale",  "durationSeconds": 4 },
           { "name": "Hold",    "durationSeconds": 4 }
         ],
         "repeatCount": 4                  // optional, only meaningful for "multiple"
       }

    3. "tracking" — log a count or a measurement.
       "tracking": {
         "kind": "counter",                // either "counter"...
         "items": ["Vitamin D", "Magnesium"]
       }
       // or
       "tracking": {
         "kind": "measurement",
         "unit": "kg",                     // required for measurement
         "targetValue": 75.0               // optional
       }

    4. "guidedSequence" — narrated multi-step routine.
       "steps": [
         { "name": "Hamstring stretch", "durationSeconds": 60, "instructions": "Hold and breathe" }
       ]

    5. "website" — opens a URL.
       "url": "https://www.example.com",
       "displayName": "Example"            // optional, defaults to the URL host

    6. "shortcut" — runs an Apple Shortcut by name.
       "shortcutName": "Wind Down",
       "displayName": "Wind Down"          // optional

    Rules:
    - Output JSON only, starting with `{` and ending with `}`. No prose, no code fences.
    - Use UTF-8. Use double quotes around all strings. No trailing commas.
    - Durations are always in seconds (Doubles), never minutes.
    - Do NOT include "id", "createdAt", or other internal IDs — the app generates them.
    - Do NOT include habit types other than the six above (no conditional/branching).
    - Keep names short (≤ 40 chars). Keep the whole document under 256 KB.

    Now generate a routine for: <DESCRIBE THE ROUTINE YOU WANT HERE>
    """
}
