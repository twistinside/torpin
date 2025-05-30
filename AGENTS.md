# Swift Guidance

## Unit Tests
- Test files shall be created with a 1:1 relationship to the files under test.
- Those files shall be created in a file structure that matches the file structure of the file under test.
- Test shall be located in the `Tests` folder at the same level as the `Sources` folder in the package.

## Ordering Properties
- Properties shall be listed in an orderly fashion, static first, private first, let first... So static private let comes before public let, etc...
- Properties shall be ordered alphabetically within the above ordering.
