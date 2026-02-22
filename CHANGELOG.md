# Changelog

All notable changes to Lazyflow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.10.0](https://github.com/connectwithprakash/lazyflow/compare/v1.9.0...v1.10.0) (2026-02-22)


### Features

* **calendar:** add scheduled start/end time to tasks ([#224](https://github.com/connectwithprakash/lazyflow/issues/224)) ([257dee4](https://github.com/connectwithprakash/lazyflow/commit/257dee459358cc486911e6843228d0ad39db9577)), closes [#213](https://github.com/connectwithprakash/lazyflow/issues/213)
* **calendar:** add two-way sync between tasks and calendar events ([#225](https://github.com/connectwithprakash/lazyflow/issues/225)) ([7a7c870](https://github.com/connectwithprakash/lazyflow/commit/7a7c870874ad2122c3bb5a42fe4f087d49e6c9ab))
* **calendar:** sync recurring tasks as recurring calendar events ([#227](https://github.com/connectwithprakash/lazyflow/issues/227)) ([1f49136](https://github.com/connectwithprakash/lazyflow/commit/1f491368ff501f407382481416d23324adee60bd))


### Bug Fixes

* **calendar:** default to Day on iPhone and persist last-used view mode ([#223](https://github.com/connectwithprakash/lazyflow/issues/223)) ([d504f42](https://github.com/connectwithprakash/lazyflow/commit/d504f424013344808a16301b5d4d77bf08d46443)), closes [#206](https://github.com/connectwithprakash/lazyflow/issues/206)

## [1.9.0](https://github.com/connectwithprakash/lazyflow/compare/v1.8.0...v1.9.0) (2026-02-21)


### Features

* **addtask:** redesign AddTaskView and unify TaskDetailView layout ([#140](https://github.com/connectwithprakash/lazyflow/issues/140)) ([44819d7](https://github.com/connectwithprakash/lazyflow/commit/44819d747cf2759b62a434129807a27a57533bdc))
* **ai:** feedback-conditioned LLM reranking for task suggestions ([#214](https://github.com/connectwithprakash/lazyflow/issues/214)) ([82d77f8](https://github.com/connectwithprakash/lazyflow/commit/82d77f8aaf1607e0341020d5fe51c6cda5260939))
* **focus:** add Focus Mode v1 with immersive single-task experience ([#215](https://github.com/connectwithprakash/lazyflow/issues/215)) ([8b1658b](https://github.com/connectwithprakash/lazyflow/commit/8b1658b68d51e6ea72629455371889cc6a8b4010))
* **history:** move search bar to bottom for better reachability ([#187](https://github.com/connectwithprakash/lazyflow/issues/187)) ([#201](https://github.com/connectwithprakash/lazyflow/issues/201)) ([bcfc2ed](https://github.com/connectwithprakash/lazyflow/commit/bcfc2ed5252d28289a7b6c7e96004e3de9801585))
* **nextup:** replace multi-card suggestions with single focused Next Up card ([#220](https://github.com/connectwithprakash/lazyflow/issues/220)) ([417ad4c](https://github.com/connectwithprakash/lazyflow/commit/417ad4c1b4dfa56f0e702a5e93970b78c9438a18))
* **nextup:** revamp Next Up suggestion with top 3, feedback, and snooze/skip ([#212](https://github.com/connectwithprakash/lazyflow/issues/212)) ([d974298](https://github.com/connectwithprakash/lazyflow/commit/d974298809a35fd8bcf621a5d3a3e66cbd5743b0))
* **summary:** add carryover section to Daily Summary ([#171](https://github.com/connectwithprakash/lazyflow/issues/171)) ([#200](https://github.com/connectwithprakash/lazyflow/issues/200)) ([096ee11](https://github.com/connectwithprakash/lazyflow/commit/096ee11ed3f65dc54025d03cd96ca7a87353e2ec))


### Bug Fixes

* **history:** polish search bar design and add cancel button ([#203](https://github.com/connectwithprakash/lazyflow/issues/203)) ([cd95b83](https://github.com/connectwithprakash/lazyflow/commit/cd95b83427443d681f937e7b5d8e73ac1ad2a8d8))
* **timer:** prevent accumulated time loss on pause→resume ([#221](https://github.com/connectwithprakash/lazyflow/issues/221)) ([0ef58c1](https://github.com/connectwithprakash/lazyflow/commit/0ef58c1574fefbd9914ef11af78bed9bd01b59ed))
* **ui:** add adaptive background to Calendar tab ([#193](https://github.com/connectwithprakash/lazyflow/issues/193)) ([#199](https://github.com/connectwithprakash/lazyflow/issues/199)) ([9d35d92](https://github.com/connectwithprakash/lazyflow/commit/9d35d92768910e05263859cf409d8496234f76de))

## [1.8.0](https://github.com/connectwithprakash/lazyflow/compare/v1.7.0...v1.8.0) (2026-02-08)


### Features

* **ai:** add personalization to Morning Briefing and Daily Summary ([#195](https://github.com/connectwithprakash/lazyflow/issues/195)) ([9cc14c2](https://github.com/connectwithprakash/lazyflow/commit/9cc14c278852edab98806689b6e6df6aa58e18ad))
* **ai:** show AI correction/refinement rates in Insights ([#196](https://github.com/connectwithprakash/lazyflow/issues/196)) ([0a13749](https://github.com/connectwithprakash/lazyflow/commit/0a137498917d1e647564173dd9027cc1ed15e7a8))
* **analytics:** add category and list analytics dashboard ([#186](https://github.com/connectwithprakash/lazyflow/issues/186)) ([19cd902](https://github.com/connectwithprakash/lazyflow/commit/19cd902ce591e970eca814e6fe220f76f7f4d798))
* **nav:** restructure navigation from 6 tabs to 5 tabs ([#184](https://github.com/connectwithprakash/lazyflow/issues/184)) ([344d7ca](https://github.com/connectwithprakash/lazyflow/commit/344d7ca8535b561360e9a9bd97429839755caa83))
* **plan:** add Plan Your Day morning planning flow ([#41](https://github.com/connectwithprakash/lazyflow/issues/41)) ([3e35112](https://github.com/connectwithprakash/lazyflow/commit/3e35112758de3b89df26529406d96c98ca8af27f))
* **plan:** smart learning for event-to-task preferences ([#192](https://github.com/connectwithprakash/lazyflow/issues/192)) ([c6e17bc](https://github.com/connectwithprakash/lazyflow/commit/c6e17bc552022f51317a1bbd6fcf7b4bd9ef3a0a))


### Bug Fixes

* **ci:** update simulator destination and fix LiveActivity group warning ([#191](https://github.com/connectwithprakash/lazyflow/issues/191)) ([00d1789](https://github.com/connectwithprakash/lazyflow/commit/00d1789e5b94f628ff9967285e9d6dc24b43174e))

## [1.7.0](https://github.com/connectwithprakash/lazyflow/compare/v1.6.1...v1.7.0) (2026-02-06)


### Features

* add calendar context to Morning Briefing ([#174](https://github.com/connectwithprakash/lazyflow/issues/174)) ([e64ddca](https://github.com/connectwithprakash/lazyflow/commit/e64ddca17aa095b7ce3fe291102550de9ac35b34))
* add Morning Briefing prompt toggle ([#173](https://github.com/connectwithprakash/lazyflow/issues/173)) ([d012de7](https://github.com/connectwithprakash/lazyflow/commit/d012de74d85d139d8dfad5cc2733051c77956107))
* add Regenerate AI actions for Morning Briefing and Daily Summary ([#177](https://github.com/connectwithprakash/lazyflow/issues/177)) ([69e6cfc](https://github.com/connectwithprakash/lazyflow/commit/69e6cfcd0095d23596a60ba4bacdf1afb5a377b9))
* Handle Morning Briefing + Daily Summary notification actions ([#179](https://github.com/connectwithprakash/lazyflow/issues/179)) ([5c0520e](https://github.com/connectwithprakash/lazyflow/commit/5c0520e399ccfb11acd57cf30b0813a301172d93))
* Improve AI-generated Morning Briefing and Daily Summary quality ([#182](https://github.com/connectwithprakash/lazyflow/issues/182)) ([ad92aaf](https://github.com/connectwithprakash/lazyflow/commit/ad92aaf182b8fefd2b842478501fc466514322b8))
* inject AI learning context into prompts ([#175](https://github.com/connectwithprakash/lazyflow/issues/175)) ([da42ae4](https://github.com/connectwithprakash/lazyflow/commit/da42ae49f667b79503e5b35d1bd9ad0ff82ec40d))
* track AI impressions for Morning Briefing and Daily Summary ([#176](https://github.com/connectwithprakash/lazyflow/issues/176)) ([f60144b](https://github.com/connectwithprakash/lazyflow/commit/f60144b91e816651a9c6bb3542e4c6b3d82d38b4))


### Bug Fixes

* correct path for excluded_territories.json in fastlane ([6365ae8](https://github.com/connectwithprakash/lazyflow/commit/6365ae8f930ec6680e7930adebfc83d9d4a5183b))
* prevent preload from suppressing Daily Summary prompt ([#172](https://github.com/connectwithprakash/lazyflow/issues/172)) ([dbe69ad](https://github.com/connectwithprakash/lazyflow/commit/dbe69ad8bdd5e8e86ef56bf824f7fc7a253f1a49))
* use api_key helper for Spaceship token in set_territories ([fdc20f2](https://github.com/connectwithprakash/lazyflow/commit/fdc20f219ff28c0783e86f61ea686a198fe0a21a))

## [1.6.1](https://github.com/connectwithprakash/lazyflow/compare/v1.6.0...v1.6.1) (2026-02-02)


### Bug Fixes

* Address App Store review feedback ([#159](https://github.com/connectwithprakash/lazyflow/issues/159)) ([73532c4](https://github.com/connectwithprakash/lazyflow/commit/73532c49f13ddd4eb2610327df8979b8aeb3e7d5))

## [1.6.0](https://github.com/connectwithprakash/lazyflow/compare/v1.5.0...v1.6.0) (2026-02-01)


### Features

* Add AI suggestion impression tracking for correction rate metric ([#155](https://github.com/connectwithprakash/lazyflow/issues/155)) ([4f2fe3a](https://github.com/connectwithprakash/lazyflow/commit/4f2fe3ad8ca1e4778e899b2d236f51f6ace5c8d2))
* **ai:** AI suggestion refinement UI with Try Again button ([#157](https://github.com/connectwithprakash/lazyflow/issues/157)) ([4fc261c](https://github.com/connectwithprakash/lazyflow/commit/4fc261c2b7806b9b23b6cceca0107991b0119a1b))
* **ai:** Configurable LLM via Open Responses API ([#125](https://github.com/connectwithprakash/lazyflow/issues/125)) ([d23cdd7](https://github.com/connectwithprakash/lazyflow/commit/d23cdd72280f854f01817922c914a01cc9ad2269))
* **ai:** Context engineering for smarter AI suggestions ([#151](https://github.com/connectwithprakash/lazyflow/issues/151)) ([68b8970](https://github.com/connectwithprakash/lazyflow/commit/68b8970c14573a3d2eaa624ad7c4f5b50264ee04))
* **ai:** Prompt engineering for Apple Intelligence ([#149](https://github.com/connectwithprakash/lazyflow/issues/149)) ([a43df44](https://github.com/connectwithprakash/lazyflow/commit/a43df4414b168bc8a8074e14c4d6acb5db033d3a))
* Allow AI to propose new category creation ([#156](https://github.com/connectwithprakash/lazyflow/issues/156)) ([c099f5a](https://github.com/connectwithprakash/lazyflow/commit/c099f5a24b55dd9abdba2dbefa1659db720438cb))
* Wire up implicit AI feedback mechanism ([#154](https://github.com/connectwithprakash/lazyflow/issues/154)) ([464b9c0](https://github.com/connectwithprakash/lazyflow/commit/464b9c09d30c2927d66fc4a48584bb6e26772f06))


### Bug Fixes

* Only deploy when docs/site changes to save Netlify build minutes ([958d27f](https://github.com/connectwithprakash/lazyflow/commit/958d27fbee41162e74dba37373880760a9e9183f))

## [1.5.0](https://github.com/connectwithprakash/lazyflow/compare/v1.4.0...v1.5.0) (2026-01-28)


### Features

* Add intraday recurring tasks (hourly reminders) ([#145](https://github.com/connectwithprakash/lazyflow/issues/145)) ([2a45637](https://github.com/connectwithprakash/lazyflow/commit/2a45637b2ee08f4ff35858cd1d1a91ae55f98dd0))
* **add-task:** Add duration, recurring, and improved reminder options ([#141](https://github.com/connectwithprakash/lazyflow/issues/141)) ([5bc2642](https://github.com/connectwithprakash/lazyflow/commit/5bc2642da6e05d073ceda34edacfffc64ff36c97))


### Bug Fixes

* Reduce verbose logging in InboxCleanup function ([b7d81e9](https://github.com/connectwithprakash/lazyflow/commit/b7d81e9e4021356472e627a47227aa34f09eea9b))
* **ui:** Enable scrolling in AddTaskView when keyboard is visible ([#147](https://github.com/connectwithprakash/lazyflow/issues/147)) ([8cf6d3e](https://github.com/connectwithprakash/lazyflow/commit/8cf6d3ee9114e92650e11776a762350cedf89385))

## [1.4.0](https://github.com/connectwithprakash/lazyflow/compare/v1.3.3...v1.4.0) (2026-01-26)


### Features

* Add Categories top-level view with UI test fixes ([#66](https://github.com/connectwithprakash/lazyflow/issues/66)) ([#138](https://github.com/connectwithprakash/lazyflow/issues/138)) ([8079f4c](https://github.com/connectwithprakash/lazyflow/commit/8079f4c3aaaf53eb0e3adea15fee81b3332f03d4))
* Add category and list pickers to task views ([#129](https://github.com/connectwithprakash/lazyflow/issues/129)) ([7f7da15](https://github.com/connectwithprakash/lazyflow/commit/7f7da15724a100f9686d57c03e118af4a9a49986)), closes [#131](https://github.com/connectwithprakash/lazyflow/issues/131)

## [1.3.3](https://github.com/connectwithprakash/lazyflow/compare/v1.3.2...v1.3.3) (2026-01-22)


### Bug Fixes

* China App Store compliance - Remove external LLM providers ([#126](https://github.com/connectwithprakash/lazyflow/issues/126)) ([c63975b](https://github.com/connectwithprakash/lazyflow/commit/c63975bf9662f1dc8d77a44125463a73817fe2fc))

## [1.3.2](https://github.com/connectwithprakash/lazyflow/compare/v1.3.1...v1.3.2) (2026-01-21)


### Bug Fixes

* Timer flickering and inaccurate time tracking ([#118](https://github.com/connectwithprakash/lazyflow/issues/118)) ([12f52fc](https://github.com/connectwithprakash/lazyflow/commit/12f52fc6007ba260e6983365a2a8f30a1ed19400))

## [1.3.1](https://github.com/connectwithprakash/lazyflow/compare/v1.3.0...v1.3.1) (2026-01-20)


### Bug Fixes

* add iPad onboarding safeguards to prevent blank screen ([31174bb](https://github.com/connectwithprakash/lazyflow/commit/31174bbf02963082479c038b797ed379b688227e))

## [1.3.0](https://github.com/connectwithprakash/lazyflow/compare/v1.2.2...v1.3.0) (2026-01-19)


### Features

* Add task history view with date filtering ([#8](https://github.com/connectwithprakash/lazyflow/issues/8)) ([#111](https://github.com/connectwithprakash/lazyflow/issues/111)) ([62f8940](https://github.com/connectwithprakash/lazyflow/commit/62f89407a97718022259648b72726dce97b89df2))
* Add time tracking with startedAt timestamp ([#105](https://github.com/connectwithprakash/lazyflow/issues/105)) ([#106](https://github.com/connectwithprakash/lazyflow/issues/106)) ([d41d2b2](https://github.com/connectwithprakash/lazyflow/commit/d41d2b2e7b537a9b5a784d3418e81b580e719be9))


### Bug Fixes

* add reject_if_possible to cancel pending submissions ([328e782](https://github.com/connectwithprakash/lazyflow/commit/328e7829225893f9067e95e9bdfa32f0986e22ca))
* improve UI test reliability with paste workaround and button targeting ([113105b](https://github.com/connectwithprakash/lazyflow/commit/113105b5efecb867561ed7a2e312ed03c1a2b421))
* replace auto-generated release notes with validation ([b7d5cdf](https://github.com/connectwithprakash/lazyflow/commit/b7d5cdfcda0a192b28d0b4b248c8f14f861e8db4))

## [1.2.2](https://github.com/connectwithprakash/lazyflow/compare/v1.2.1...v1.2.2) (2026-01-18)


### Bug Fixes

* add App Store metadata and update deployment docs ([468e924](https://github.com/connectwithprakash/lazyflow/commit/468e9246885831a98f3eb0f8e12cb2d5516ae6ae))
* add iPad and Watch screenshots for App Store submission ([f1f1dcc](https://github.com/connectwithprakash/lazyflow/commit/f1f1dcc759b7a42b304657a202a3e393630c3cde))
* correct netlify.toml ignore syntax to use command string ([b00e6e2](https://github.com/connectwithprakash/lazyflow/commit/b00e6e2db22dd016dce952fe07c26b83cca4a924))
* resolve swipe actions conflict on tasks with subtasks ([#108](https://github.com/connectwithprakash/lazyflow/issues/108)) ([5fb55a3](https://github.com/connectwithprakash/lazyflow/commit/5fb55a348a53833e5e5c225d53d4667fddb896d3))

## [1.2.1](https://github.com/connectwithprakash/lazyflow/compare/v1.2.0...v1.2.1) (2026-01-18)


### Bug Fixes

* add App Store submission workflow and screenshots ([#103](https://github.com/connectwithprakash/lazyflow/issues/103)) ([293c537](https://github.com/connectwithprakash/lazyflow/commit/293c53738bbbd6d33a3c1a87f87481a91d10699e))

## [1.2.0](https://github.com/connectwithprakash/lazyflow/compare/v1.1.0...v1.2.0) (2026-01-18)


### Features

* add subtask support with auto-completion ([#13](https://github.com/connectwithprakash/lazyflow/issues/13)) ([#100](https://github.com/connectwithprakash/lazyflow/issues/100)) ([490a25b](https://github.com/connectwithprakash/lazyflow/commit/490a25b8426d0126b552ca3963a1a76fb0f9d4b1))
* **ci:** add automated TestFlight deployment on release ([d4df9da](https://github.com/connectwithprakash/lazyflow/commit/d4df9da27028df8414a18721454ed95e85cc0471))

## [1.1.0](https://github.com/connectwithprakash/lazyflow/compare/v1.0.1...v1.1.0) (2026-01-07)


### Features

* **data-management:** Add robust iCloud data management ([5e3d1b3](https://github.com/connectwithprakash/lazyflow/commit/5e3d1b311442935886afa13b693e5e8cf4f606a7))
* **data-management:** Add robust iCloud data management ([8438ab8](https://github.com/connectwithprakash/lazyflow/commit/8438ab8c2b43d5b8e1d3bbb7e314eb82aa5c1ab9))

## [1.0.1](https://github.com/connectwithprakash/lazyflow/compare/v1.0.0...v1.0.1) (2026-01-07)


### Bug Fixes

* resolve UI crashes and improve stability ([#93](https://github.com/connectwithprakash/lazyflow/issues/93)) ([424d044](https://github.com/connectwithprakash/lazyflow/commit/424d044249bc659434e3b218106eedebcd538fb8))

## [1.0.0](https://github.com/connectwithprakash/lazyflow/compare/v0.27.0...v1.0.0) (2026-01-06)


### ⚠ BREAKING CHANGES

* release v1.0.0 - first stable release

### Features

* **ci:** Add Fastlane for automated deployments ([99916a1](https://github.com/connectwithprakash/lazyflow/commit/99916a17ae65dc98da5a8300706a576d13331978))
* **ci:** Add Fastlane for automated deployments ([98f06fd](https://github.com/connectwithprakash/lazyflow/commit/98f06fd4799a2372f51afe11e52ff62d27abdd92))
* release v1.0.0 - first stable release ([c4b6046](https://github.com/connectwithprakash/lazyflow/commit/c4b604655f7a8780ecf80cd0f1c13beac9b07e13))
* rename app from Taskweave to Lazyflow ([#90](https://github.com/connectwithprakash/lazyflow/issues/90)) ([18d5765](https://github.com/connectwithprakash/lazyflow/commit/18d576534293f31d8fef70febe16662b6491fa92))


### Bug Fixes

* display conflicting task info in conflict resolution card ([1ce96c7](https://github.com/connectwithprakash/lazyflow/commit/1ce96c7efeb4fa80315763c9f595c08633e1ae99))
* fastlane code signing and export compliance ([#92](https://github.com/connectwithprakash/lazyflow/issues/92)) ([78026ce](https://github.com/connectwithprakash/lazyflow/commit/78026ce225a031a727b09a44a2a5c402635a32d5))

## [0.27.0](https://github.com/connectwithprakash/lazyflow/compare/v0.26.1...v0.27.0) (2026-01-06)


### Features

* **docs:** Add theme-aware screenshots that switch with dark/light mode ([#85](https://github.com/connectwithprakash/lazyflow/issues/85)) ([266ed2f](https://github.com/connectwithprakash/lazyflow/commit/266ed2f1204828196e10d3e362d702d5cc0655c4))

## [0.26.1](https://github.com/connectwithprakash/lazyflow/compare/v0.26.0...v0.26.1) (2026-01-06)


### Bug Fixes

* **launch:** Eliminate black screen flash on physical devices ([#82](https://github.com/connectwithprakash/lazyflow/issues/82)) ([659b092](https://github.com/connectwithprakash/lazyflow/commit/659b0928de4648c1d7ecce9c016ec0bed6c72577))

## [0.26.0](https://github.com/connectwithprakash/lazyflow/compare/v0.25.0...v0.26.0) (2026-01-05)


### Features

* **icon:** Redesign app icon with Liquid Glass design ([#77](https://github.com/connectwithprakash/lazyflow/issues/77)) ([417a73f](https://github.com/connectwithprakash/lazyflow/commit/417a73f95d3a054239c17414116131cb8597aabc)), closes [#73](https://github.com/connectwithprakash/lazyflow/issues/73)
* **launch:** Redesign launch screen with fullscreen gradient ([#79](https://github.com/connectwithprakash/lazyflow/issues/79)) ([1dd598d](https://github.com/connectwithprakash/lazyflow/commit/1dd598dd0be100d37aba432edd2430421b358d11))


### Performance Improvements

* Remove artificial delays from app loading ([#80](https://github.com/connectwithprakash/lazyflow/issues/80)) ([d5f87d1](https://github.com/connectwithprakash/lazyflow/commit/d5f87d1e776cf50ec0e2251e60281852e542e773))

## [0.25.0](https://github.com/connectwithprakash/lazyflow/compare/v0.24.0...v0.25.0) (2026-01-05)


### Features

* Add morning briefing notification with yesterday recap and today's plan ([#74](https://github.com/connectwithprakash/lazyflow/issues/74)) ([9d029d9](https://github.com/connectwithprakash/lazyflow/commit/9d029d9cf7d81a3fd7874c16d56e36f6a04bf8a4))

## [0.24.0](https://github.com/connectwithprakash/lazyflow/compare/v0.23.1...v0.24.0) (2026-01-05)


### Features

* Add daily summary with streak tracking and AI recap ([bfd0f3f](https://github.com/connectwithprakash/lazyflow/commit/bfd0f3f82d408d88a51001efe47a6df191942b8d))

## [0.23.1](https://github.com/connectwithprakash/lazyflow/compare/v0.23.0...v0.23.1) (2026-01-04)


### Bug Fixes

* Update README image paths and reduce Netlify builds ([0a22bcb](https://github.com/connectwithprakash/lazyflow/commit/0a22bcbf5512301c841cf15d9d1482f8c8741e81))

## [0.23.0](https://github.com/connectwithprakash/lazyflow/compare/v0.22.0...v0.23.0) (2026-01-04)


### Features

* Simplify AI architecture - remove ML model, enhance LLM integration ([c74ce19](https://github.com/connectwithprakash/lazyflow/commit/c74ce19b9168223bb095ea90c7ba1e8a329a0066))

## [0.22.0](https://github.com/connectwithprakash/lazyflow/compare/v0.21.0...v0.22.0) (2026-01-04)


### Features

* **docs:** Improve docs site with dark mode, SEO, and Netlify URLs ([#64](https://github.com/connectwithprakash/lazyflow/issues/64)) ([ab698fb](https://github.com/connectwithprakash/lazyflow/commit/ab698fbdb456b40ccec668f0271f59400394296f))

## [0.21.0](https://github.com/connectwithprakash/lazyflow/compare/v0.20.0...v0.21.0) (2026-01-04)


### Features

* **calendar:** Add double-tap to create task from events ([#61](https://github.com/connectwithprakash/lazyflow/issues/61)) ([5df941c](https://github.com/connectwithprakash/lazyflow/commit/5df941c35b31420f8f81975d108197afdf6d7d7b))

## [0.20.0](https://github.com/connectwithprakash/lazyflow/compare/v0.19.0...v0.20.0) (2026-01-04)


### Features

* **calendar:** Improve event rendering in Day and Week views ([#59](https://github.com/connectwithprakash/lazyflow/issues/59)) ([36252e9](https://github.com/connectwithprakash/lazyflow/commit/36252e98345960b851561c5bb9a88f4084a4571f))

## [0.19.0](https://github.com/connectwithprakash/lazyflow/compare/v0.18.0...v0.19.0) (2026-01-03)


### Features

* **onboarding:** Add tutorial carousel for first-time users ([#57](https://github.com/connectwithprakash/lazyflow/issues/57)) ([ec7a338](https://github.com/connectwithprakash/lazyflow/commit/ec7a33869cd7d3ceaf427ec4b08581cdc5429d8b)), closes [#21](https://github.com/connectwithprakash/lazyflow/issues/21)

## [0.18.0](https://github.com/connectwithprakash/lazyflow/compare/v0.17.0...v0.18.0) (2026-01-03)


### Features

* **accessibility:** Add VoiceOver support for task rows and Watch app ([#55](https://github.com/connectwithprakash/lazyflow/issues/55)) ([cfac79f](https://github.com/connectwithprakash/lazyflow/commit/cfac79fb474e70b724b521f80eb5dbaa7312d2ff)), closes [#6](https://github.com/connectwithprakash/lazyflow/issues/6)

## [0.17.0](https://github.com/connectwithprakash/lazyflow/compare/v0.16.0...v0.17.0) (2026-01-03)


### Features

* **live-activity:** Add in-progress task state with timer and priority colors ([#53](https://github.com/connectwithprakash/lazyflow/issues/53)) ([c0361d0](https://github.com/connectwithprakash/lazyflow/commit/c0361d048c530914914bd03b05ce98b4db590a12)), closes [#16](https://github.com/connectwithprakash/lazyflow/issues/16)

## [0.16.0](https://github.com/connectwithprakash/lazyflow/compare/v0.15.0...v0.16.0) (2026-01-03)


### Features

* **sync:** add iCloud sync with CloudKit ([#50](https://github.com/connectwithprakash/lazyflow/issues/50)) ([9b32d6c](https://github.com/connectwithprakash/lazyflow/commit/9b32d6c8ca9e1a8911ef9a28024c4632d474c082)), closes [#30](https://github.com/connectwithprakash/lazyflow/issues/30)


### Bug Fixes

* **sync:** improve CloudKit sync reliability and UI refresh ([#52](https://github.com/connectwithprakash/lazyflow/issues/52)) ([6929210](https://github.com/connectwithprakash/lazyflow/commit/692921084184cd16bafc718a1b762917776724e2))

## [0.15.0](https://github.com/connectwithprakash/lazyflow/compare/v0.14.1...v0.15.0) (2026-01-03)


### Features

* **calendar:** Add error toast for calendar sync failures ([933996f](https://github.com/connectwithprakash/lazyflow/commit/933996fbee002beec3373e0247de4657ca459205))
* **calendar:** Add error toast for calendar sync failures ([4eba7f2](https://github.com/connectwithprakash/lazyflow/commit/4eba7f2c25bff1fac7e35b8cd6fe1ff6bb33d4f6)), closes [#5](https://github.com/connectwithprakash/lazyflow/issues/5)
* **calendar:** Add swipe navigation for Day and Week views ([#44](https://github.com/connectwithprakash/lazyflow/issues/44)) ([613e55f](https://github.com/connectwithprakash/lazyflow/commit/613e55f784b58667067e881f1ea1d6cff67ab763)), closes [#39](https://github.com/connectwithprakash/lazyflow/issues/39)
* **widget:** Add deep linking for widget tap navigation ([#47](https://github.com/connectwithprakash/lazyflow/issues/47)) ([2abfda2](https://github.com/connectwithprakash/lazyflow/commit/2abfda2c00fdd22f44093e81004654f721f29f08)), closes [#20](https://github.com/connectwithprakash/lazyflow/issues/20)

## [0.14.1](https://github.com/connectwithprakash/lazyflow/compare/v0.14.0...v0.14.1) (2026-01-03)


### Bug Fixes

* **calendar:** Fix blank Create Task from Event sheet ([#40](https://github.com/connectwithprakash/lazyflow/issues/40)) ([2ead489](https://github.com/connectwithprakash/lazyflow/commit/2ead4896095912d6305b5c0c060ae93d46c59670)), closes [#38](https://github.com/connectwithprakash/lazyflow/issues/38)
* **notifications:** Request permission before scheduling reminders ([#34](https://github.com/connectwithprakash/lazyflow/issues/34)) ([847f672](https://github.com/connectwithprakash/lazyflow/commit/847f672a9ecbaf608b0ba5f960c10fe66ba50ab4)), closes [#31](https://github.com/connectwithprakash/lazyflow/issues/31)
* **upcoming:** Add Schedule swipe action to Upcoming tab ([#37](https://github.com/connectwithprakash/lazyflow/issues/37)) ([0855689](https://github.com/connectwithprakash/lazyflow/commit/085568960c5c45bcd7f3f37fc666373b6898d996)), closes [#36](https://github.com/connectwithprakash/lazyflow/issues/36)

## [0.14.0](https://github.com/connectwithprakash/lazyflow/compare/v0.13.2...v0.14.0) (2026-01-03)


### Features

* **tasks:** Add 'In Progress' task state and improve repeat frequency display ([#32](https://github.com/connectwithprakash/lazyflow/issues/32)) ([8ad9fa9](https://github.com/connectwithprakash/lazyflow/commit/8ad9fa9165bf4a5b497519b61aed9732e6ab6e3b)), closes [#17](https://github.com/connectwithprakash/lazyflow/issues/17)

## [0.13.2](https://github.com/connectwithprakash/lazyflow/compare/v0.13.1...v0.13.2) (2026-01-02)


### Bug Fixes

* **ui:** Restore swipe actions while keeping checkbox tappable ([#28](https://github.com/connectwithprakash/lazyflow/issues/28)) ([690b0c2](https://github.com/connectwithprakash/lazyflow/commit/690b0c22dfeca9a919c111cb0c602f36f0203730))

## [0.13.1](https://github.com/connectwithprakash/lazyflow/compare/v0.13.0...v0.13.1) (2026-01-02)


### Bug Fixes

* Enable Calendar Access button not responding ([#18](https://github.com/connectwithprakash/lazyflow/issues/18)) ([#26](https://github.com/connectwithprakash/lazyflow/issues/26)) ([a08323f](https://github.com/connectwithprakash/lazyflow/commit/a08323f804facd36c85b3a52159ff19df1c5934a))
* **launch:** Replace black screen with elegant branded launch experience ([#23](https://github.com/connectwithprakash/lazyflow/issues/23)) ([983667c](https://github.com/connectwithprakash/lazyflow/commit/983667c2d20a8096db0c549eecc069486a301925)), closes [#22](https://github.com/connectwithprakash/lazyflow/issues/22)
* **suggestions:** Show content immediately on suggestion card tap ([#25](https://github.com/connectwithprakash/lazyflow/issues/25)) ([b482332](https://github.com/connectwithprakash/lazyflow/commit/b4823321f71c31a448d25ce9f3f333889e1b6a69)), closes [#19](https://github.com/connectwithprakash/lazyflow/issues/19)
* **ui:** Make task checkbox independently tappable ([#27](https://github.com/connectwithprakash/lazyflow/issues/27)) ([8d7bdd1](https://github.com/connectwithprakash/lazyflow/commit/8d7bdd17354b2c16d2315bf71b0927d4a4360893)), closes [#15](https://github.com/connectwithprakash/lazyflow/issues/15)

## [0.13.0](https://github.com/connectwithprakash/lazyflow/compare/v0.12.0...v0.13.0) (2026-01-01)


### Features

* **launch:** Add async Core Data loading and release automation ([c20f1d6](https://github.com/connectwithprakash/lazyflow/commit/c20f1d6973223801c8e36ed821415ff0fe41cd27))

## [0.12.0] - 2026-01-01

### Added
- Branded launch screen with app background color for smoother visual transition
- VoiceOver accessibility labels on task rows (status, title, priority, due date, category)
- UTType declaration for task drag & drop support

### Changed
- UpcomingView converted from ScrollView to List for native swipe action support
- ListDetailView converted from ScrollView to List for native swipe action support
- Defer heavy initialization to after UI appears for faster perceived startup

### Fixed
- Remove fatalError in PersistenceController (graceful error handling instead)
- Fix force unwraps in TaskService date calculations
- Fix force unwraps in CalendarView week/hour calculations
- Fix force unwraps in SmartRescheduleService tomorrow calculation
- Fix force unwraps in Date+Extensions (isWithinNextWeek, endOfDay, currentWeekDates)

## [0.11.0] - 2026-01-01

### Added
- Native swipe actions on task rows
  - Swipe left: Delete, Move to Today, Push to Tomorrow (contextual)
  - Swipe right: Complete/Undo (full swipe), Schedule to Calendar
- Haptic feedback on swipe actions
- Undo toast notification for task actions (complete, delete, reschedule)
- Move to Today action for overdue and upcoming tasks

### Changed
- TodayView converted from ScrollView to List for native swipe support
- List styled with plain style and hidden separators to match existing design

## [0.10.0] - 2025-12-31

### Changed
- Replace priority badges with left edge color strips for cleaner visual hierarchy
- Priority colors: Urgent (red), High (orange), Medium (yellow), Low (blue)
- Keep checkbox ring color as secondary priority signal

### Fixed
- Wire up context menu actions for priority, due date, and delete
- Fix badge text wrapping with lineLimit and fixedSize
- Clip task rows with RoundedRectangle for proper corner radius

## [0.9.0] - 2025-12-31

### Added
- iPad-optimized UI with NavigationSplitView sidebar navigation
- Adaptive layout: Sidebar for iPad (regular size class), TabView for iPhone (compact)
- Keyboard shortcuts for iPad: Cmd+N (new task), Cmd+F (search), Cmd+1-5 (navigate tabs)
- Proper iOS List selection binding for sidebar navigation
- Size class detection across all views (TodayView, CalendarView, UpcomingView, ListsView, SettingsView)
- Conditional NavigationStack wrapping based on device type

### Changed
- ContentView refactored to support both NavigationSplitView and TabView
- Views now detect horizontalSizeClass to adapt layout

## [0.8.0] - 2025-12-31

### Added
- Apple Watch app with SwiftUI for watchOS 10+
- Today's task list view with progress ring header
- Tap-to-complete task interaction
- WatchConnectivity for real-time iPhone ↔ Watch sync
- Watch complications (circular, corner, inline, rectangular)
- WatchDataStore for offline task caching via App Groups

## [0.7.0] - 2025-12-31

### Added
- Lock Screen Live Activity with centered progress ring and task hierarchy
- Dynamic Island compact view with progress ring and subtle progress bar
- Dynamic Island expanded view showing current task with upcoming breadcrumb
- Dynamic Island minimal view for multi-activity mode
- Settings toggle to enable/disable Live Activity tracking
- LiveActivityManager for activity lifecycle management

## [0.6.0] - 2025-12-31

### Added
- iOS Home Screen Widgets via WidgetKit
- Small widget showing task count and completion progress
- Medium widget displaying today's task list with priorities
- Large widget with overdue, today, and upcoming sections
- App Groups for shared data between app and widgets
- Widget refresh on task changes

## [0.5.0] - 2025-12-31

### Added
- Siri Shortcuts integration via App Intents
- "Create Task" shortcut for hands-free task creation
- "Complete Next Task" shortcut to mark tasks done
- "Get Today's Tasks" shortcut to hear your agenda
- Shortcuts appear automatically in the Shortcuts app

## [0.4.0] - 2025-12-31

### Added
- Smart rescheduling when meetings conflict
- Conflict detection service for task-calendar conflicts
- "What should I do next?" AI-powered prioritization
- Time protection for focused work blocks
- Push-to-tomorrow swipe action for tasks
- Unit and UI tests for smart rescheduling

## [0.3.0] - 2025-12-30

### Added
- Multi-provider LLM support (Apple Intelligence, Anthropic Claude, OpenAI)
- AI-powered task analysis and suggestions
- ML-based automatic task categorization using Create ML
- Color-coded category badges (Work, Personal, Health, Finance, etc.)
- Provider selection in Settings with API key configuration

## [0.2.0] - 2025-12-30

### Added
- Native Apple Calendar integration via EventKit
- Day and week calendar views
- Calendar view with events display
- Schedule tasks as time blocks
- CalendarService for event management
- CalendarViewModel for calendar state

## [0.1.0] - 2025-12-29

### Added
- Core task management with CRUD operations
- Task lists for organization
- Due dates and time-based reminders
- Recurring tasks (daily, weekly, monthly, yearly)
- Priority levels (urgent, high, medium, low, none)
- Core Data persistence for offline-first experience
- CloudKit sync for iCloud backup
- Today view with overdue and today's tasks
- Upcoming view for future tasks
- Lists view for task organization
- Settings view with appearance options
- Light and dark mode support
- Tab bar navigation
- SwiftUI native interface
- VoiceOver accessibility support
