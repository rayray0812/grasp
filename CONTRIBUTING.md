# Contributing to Grasp

謝謝你願意改善 Grasp。

## Before opening a change

- 先確認功能直接改善學測單字的記憶、理解或使用。
- 不加入帳號、社群、訂閱、廣告、付費牆或必要的 cloud backend。
- AI 功能必須有非 AI fallback，且不得把 key 寫入 source 或一般 local storage。
- 語言內容與 `LearningState` 不可綁在一起。
- 排程規則留在 `learning/`；題型選擇留在 `review/`。

## Development

```bash
flutter pub get
dart format lib/src test
flutter analyze
flutter test
```

Pull request 請包含：問題、做法、驗證方式，以及任何資料模型或 FSRS 行為改變。

## Content contributions

學測內容應保持精簡並可追溯來源。例句需自然、程度適合高中生；近義字辨析與 collocation 只保留考試與實際使用價值。不要把 Grasp 變成完整字典。
