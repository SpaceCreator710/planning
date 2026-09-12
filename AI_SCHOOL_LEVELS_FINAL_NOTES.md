> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# AI School Levels — Final Add-on

This build preserves the previous `AI-SCHOOL-WIDGETS` feature set and expands only the School explanation-level system and its UI.

## Levels

1st grade, 2nd grade, 3rd grade, 4th grade, 5th grade, 6th grade, 7th grade, 8th grade, 9th grade, 10th grade, 11th grade, 12th grade, College, University, Professional.

The previous saved raw value `student` is intentionally preserved for College so existing users do not lose their selected level after updating.

## UI

The School-mode level selector is now a horizontally scrollable row of Liquid Glass chips so all levels remain usable on iPhone without compressing the labels. Settings continues to expose the same full set through the Explanation level picker.

## Server

The protected AI backend validates every new level and applies a distinct teaching instruction for each one. Professional assumes strong fundamentals and adds field-standard terminology, assumptions, edge cases and trade-offs.
