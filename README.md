# Grasp

Grasp 是一個免費、開源、local-first 的學測英文單字 App。它以單字為基礎，但不把「看過中文意思」誤當成學會：學生必須能在時間壓力下讀懂語境、判斷詞義與搭配，並把單字主動用在句子裡。

Grasp 不需要帳號，沒有訂閱、廣告、排行榜、社群 feed 或付費牆。下載後即可離線使用；AI 是完全選用的 enhancement，而不是學習流程的依賴。

## 為什麼建立 Grasp

一般 flashcard 常把單字簡化成 `English → 中文`，但學測真正要求的是在文章中快速提取意思、看懂前後邏輯，並在翻譯與作文中正確使用。Grasp 因此採用「字義辨認 → 主動回想 → 語境填空 → 搭配／詞義辨析 → 造句」的學習階梯。語言內容與記憶狀態分開儲存，再由 FSRS 自動決定下一次最適合的複習時間。

每天打開 App，只需要處理兩件事：

- 今天到期的複習
- 今天的新單字

## 核心功能

- FSRS spaced repetition（預設目標記憶率 90%）
- Recognition、Typed Recall、Cloze、Meaning in Context、Collocation 與 Active Use 題型
- 封閉題要求實際輸入答案；造句題以明確檢核表誠實自評
- 答錯後必須重新輸入正確答案，FSRS 一律依第一次作答記為 `Again`
- 最近 50 題應用正確率、平均反應時間、弱項與最近錯題
- 大考中心 Level 1–6 內建詞彙表
- 一字多義、例句、近義／易混淆字、搭配與 word family 模型
- Quizlet tab-separated export 與舊版 importer JSON 匯入
- Vocabulary、Learning State、Review History、Deck、Review Session 分離
- Hive local-first storage
- OpenAI / Gemini / Anthropic BYOK 安全儲存入口
- 無帳號、無 cloud backend、無商業 SDK

## Tech Stack

- Flutter / Dart
- Hive（本機資料）
- `fsrs`（複習排程）
- `flutter_secure_storage`（使用者自己的 AI key）
- `http`（選用的 BYOK provider adapter）

沒有 Supabase、Firebase、RevenueCat、Sentry、廣告 SDK 或 Grasp server。

## 開始執行

需求：Flutter stable、Dart 3.8 以上。

```bash
flutter pub get
flutter run
```

不需要 `.env` 或後端服務。`.env.example` 只用來明確記錄「核心 App 沒有必要的環境變數」。

## Build

```bash
flutter build apk
flutter build ios --no-codesign
flutter build web
```

Android release signing 請在本機建立 `android/key.properties`；它已被 `.gitignore` 排除。

## AI / BYOK

AI 沒有設定時，所有核心功能仍完整可用。

1. 開啟「設定 → AI · 選用」。
2. 輸入自己的 OpenAI、Gemini 或 Anthropic API key。
3. Key 只寫入平台 secure storage，不寫入 Hive、repository、log 或 Grasp server。

目前 OpenAI adapter 使用 Responses API 並設定 `store: false`。任何 client-side BYOK 都應視為使用者裝置上的高敏感資料；不要在共享或已 root / jailbreak 的裝置保存 key。

## Quizlet Import

在 Quizlet 匯出單字集，選擇 Tab 分隔單字與定義，然後貼到 Grasp 的 Import 頁面：

```text
substantial\t大量的；可觀的
respond\t回應
```

也支援包含 `cards`、`terms` 或 `words` 的 JSON。缺少例句、詞性或搭配時保持空白，不會自動呼叫 AI。

## Project Structure

```text
lib/
  main.dart
  src/
    ai/          optional BYOK and local-AI boundaries
    app/         composition root and app state
    data/        repository interface, Hive, GSAT seed loader
    domain/      vocabulary and learning models
    import/      Quizlet normalization
    learning/    FSRS adapter
    review/      question selection engine
    ui/          Today, Review, Library, Import, Settings
test/            tests for the rewritten app
```

應用內容獨立放在 `assets/exam/gsat_application_content.json`，不硬編進
Dart。內容 overlay 只補充例句、多義、搭配、近義／易混淆字與 word
family，不會改變單字 ID 或 FSRS 狀態。格式與品質規則見
[`docs/CONTENT_GUIDE.md`](docs/CONTENT_GUIDE.md)。

6,392 字的基礎字義與詞性已可離線使用；高品質語境資料會分批審核補入。
沒有可靠例句的字只出 Recall，不會用機械模板假造 Cloze 或造句範例。

資料流：

```text
UI → AppController → Review Engine / FSRS Scheduler → Repository → Hive
```

Review Engine 決定「用什麼方式測」，FSRS Scheduler 只決定「何時再出現」。兩者不能互相依賴。

## 開發原則

1. Local-first / offline-first
2. FSRS-first
3. 只做能提高學測單字長期記憶的功能
4. AI optional
5. Maintainability over cleverness
6. 不為尚未存在的 cloud、sync、會員或商業需求預先抽象

## Tests

```bash
flutter analyze
flutter test
```

## Contributing

請先閱讀 [CONTRIBUTING.md](CONTRIBUTING.md)。新增功能前，先回答：「它是否真的能幫助學生更有效記住學測需要的單字？」若不能，應避免增加產品複雜度。

## License

[MIT](LICENSE)
