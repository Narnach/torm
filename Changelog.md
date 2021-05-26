# Changelog

## Version 0.3.0 (dev)

- Update minitest requirement from ~> 4.0 to ~> 5.12 (905e9f7)
- Refactor: replace accessor with writer (24f4594)
- Refactor: fixed minitest deprecation warnings (aa1c586)

## Version 0.2.1

This version was in "development" between 2014 and 2021.
It works until Ruby 2.7 (with some keyword argument warnings).
The next version will have stricter (read: more modern) version requirements.

- Setup integration with CodeShip and CodeClimate (8121572)
- Test improvement for CI: use an absolute file path for tmp (4b6a602)
- Another CI fix: don't create a tmp dir if it already exists (ff4fcf5)
- CI fix 3: create the tmp dir if missing, but don't remove it (91ac06b)
- Out with CodeClimate (422ff63)
- Update rake requirement from ~> 10.0 to ~> 12.3 (9fab297)
- Merge pull request #2 from Narnach/dependabot/bundler/rake-tw-12.3 (66f0cf2)
- Upgrade to GitHub-native Dependabot (ae0c433)
- Merge pull request #4 from Narnach/dependabot/add-v2-config-file (6902616)
- Refactor: pinned version restrictions (69bc23f)
- Updated readme (7efca80)
- Release: version increased to 0.2.1 (c4c9421)

## Version 0.2.0

- More YARDoc for RulesEngine#add_rule and #add_rules (3431075)
- Added a block syntax to define common conditions for adding rules (0319794)
- Nesting conditions blocks merges conditions as expected (393c4c9)
- Readme update with conditions syntax (6413852)
- Version bump to 0.2.0 (a1a1421)

## Version 0.1.0

- Added a note on semantic versioning (a106391)
- Added YARDoc method signatures, did more cleaning up of Torm::RulesEngine (f47b802)
- Updated readme example to showcase Torm.set_defaults and Torm.instance (5eb0b4e)
- Introduced RulesEngine#add_rules syntax with a block (5345f3c)
- Version 0.1.0 (a4a5127)
