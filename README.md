# ガンマン・ジャンケン道 (Godot Prototype)
<img width="794" height="446" alt="image" src="https://github.com/user-attachments/assets/3635e025-9b2f-496e-9e9c-01bab97ce5f9" />

遊べます↓
https://itch.io/jam/gmtk-jam-2026/rate/4825702


Slay the Spire 風のカードバトル×じゃんけんゲーム。Godot 4.3 で動作確認。

## 開くには
Godot 4.x で `project.godot` を開き、F5 (メインシーン実行)。

## カードを自作する
1. FileSystemドックで `res://resources/cards/` を右クリック → 新規リソース
2. `CardData` を選択（検索欄に入力すると出ます）
3. インスペクタで以下を設定して保存（例: `my_card.tres`）
   - **Card Name**: カード名
   - **Image**: カード絵（Slay the Spire風の縦長イラスト推奨、任意）
   - **Janken Hands**: じゃんけん属性の配列。複数追加すると複合属性カードになる
   - **Rarity**: Common / Uncommon / Rare（枠の色に反映）
   - **Card Type**: Attack(攻撃) / Skill(防御などの単発効果) / Power(継続・回復系)
   - **Value**: 効果量（ダメージ/ブロック/回復量など）
   - **Description**: 説明文。`{value}` は自動的に Value の数値に置換される
4. 保存先が `res://resources/cards/` 内なら、次回起動時に自動でデッキ構築プールに登録されます（コード変更不要）

## イベントを自作する
1. `res://resources/events/` に `EventChoiceData` を必要な数だけ作成
   - `label`: 選択肢ボタンの文言
   - `gold_cost`: 選ぶために必要な所持金（0なら無条件）
   - `gold_delta` / `hp_delta` / `max_hp_delta`: 増減値
   - `add_card`: 選択時にデッキへ加えるカード（CardDataリソースを指定可）
2. `EventData` リソースを作成し、`choices` 配列に上記の EventChoiceData を入れる
3. `res://resources/events/` に保存すれば、バトル後のイベント抽選に自動で追加されます

`campfire.tres` / `merchant.tres` がサンプルなので、コピーして改造すると早いです。

## 敵を自作する
`res://resources/enemies/` に `EnemyData` を作成（名前・HP・攻撃力・ボスフラグ）。
`is_boss = true` にすると 7バトル毎のボス戦にのみ出現します。

## 現状の仕様
- 準備フェーズ: 5枚ドロー→3枚選んでスロットに並べる。7秒以内にセット
- 勝負フェーズ: スロット順に敵と1手ずつ比較。共通する手は相殺し、残った手のじゃんけんで行動権を決定。あいこなら両者行動
- 21バトル（7の倍数がボス）を突破でクリア
- バトル後にランダムイベント（休憩/ショップ等）
