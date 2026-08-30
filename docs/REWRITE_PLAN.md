# Grasp v2 Rewrite Plan

## Keep

- Flutter as the cross-platform UI runtime.
- Hive as the local persistence mechanism, with new v2 boxes and no account namespace.
- The `fsrs` package and stable FNV-1a card identifier idea.
- The built-in GSAT Level 1–6 vocabulary asset.
- Quizlet term/definition normalization as a product capability.

## Rewrite

- Vocabulary content as senses, examples, lexical relations, collocations and word family.
- FSRS integration behind one adapter with persisted learning steps.
- Today queue from due reviews plus a bounded number of unseen words.
- Review UI around a small, extensible application ladder: recognition,
  typed recall, cloze, meaning discrimination, collocation and sentence use.
- Quizlet import as offline pasted export / JSON rather than a fragile general WebView.
- AI as optional local/BYOK interfaces with secrets in platform secure storage.

## Remove

- Authentication, profiles and account namespaces.
- Supabase, cloud sync and backend migrations/functions.
- RevenueCat, subscriptions, premium gates, quotas and redemption.
- Community, followers, posts, inbox, realtime presence and classrooms.
- Admin surfaces and commercial analytics.
- Firebase push, Sentry and home-screen engagement widgets.
- Conversation, matching, revenge, achievements, coins and other non-core modes.

## New Architecture

```text
UI
 └─ AppController
     ├─ ReviewEngine (how to test)
     ├─ FsrsScheduler (when to review)
     ├─ QuizletImporter
     └─ GraspRepository
         └─ HiveGraspRepository
```

Persisted entities are independent: `VocabularyEntry`, `LearningState`, `ReviewRecord`, `Deck`, and `ReviewSession`. No entity contains account, premium, sync or analytics fields.

基礎學測字表與人工審核的應用內容採兩層資產：前者提供穩定 ID、字義與
Level，後者以 lemma overlay 補充語境。更新內容不會重設學習狀態。

FSRS answers **when** a word should return. `ReviewEngine` answers **how** the
student must retrieve and use it. A word is not treated as mastered merely
because its Chinese translation looks familiar.

This repository contains only the rewritten architecture. Legacy product code,
credentials, backend functions and commercial dependencies are intentionally
not carried forward.
