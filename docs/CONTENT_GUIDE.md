# Application Content Guide

Grasp 的內容目標不是做完整字典，而是提供足以讓學生在學測語境中理解、
辨析與使用單字的最小可靠資訊。

## Two-layer catalog

- `gsat_builtin_words_seed.json`：穩定的單字 ID、lemma、Level、基礎字義與詞性。
- `gsat_application_content.json`：人工審核的例句、多義、搭配、近義／易混淆字與 word family。

應用內容以 `lemma` 合併，因此修正文句不會重設 `LearningState` 或 FSRS
歷史。`schemaVersion` 目前為 `1`。

## Minimal entry

```json
{
  "lemma": "accomplish",
  "examples": [
    {
      "sentence": "He accomplished the task ahead of schedule.",
      "source": "Grasp editorial"
    }
  ],
  "collocations": ["accomplish a task", "accomplish a goal"]
}
```

需要覆蓋多義時可提供完整 `senses`；每個 sense 必須有 `definitionZh`，例句
應放在它實際表達的 sense 下。

不規則變化無法由 lemma 推導時，在例句加入 `targetText`，例如
`{"sentence": "She went home early.", "targetText": "went"}`。Cloze 會要求
學生輸入句中真正需要的形式，而不是一律輸入原形。

## Quality bar

1. 例句至少四個詞，必須實際包含 lemma 或合理的屈折變化。
2. 句子要自然、短、程度適合高中生，並提供足以推斷意思的語境。
3. Collocation 必須包含該字，只收錄學測閱讀、翻譯或作文有價值的搭配。
4. 多義、近義與易混淆說明要指出真正影響選字的差異。
5. 不複製商業字典例句；外部內容必須確認授權並標示來源。
6. 無法確認品質時保持欄位空白，Review Engine 會安全退回 Typed Recall。

Loader 會拒絕重複 lemma、不存在於基礎字表的 lemma、過短例句，以及沒有
使用目標字的例句或搭配。所有內容修改都必須通過 `flutter test`。
