# 開発オンボーディング（初めて関わる方向け）

この資料は、Even G2 Demo App の全体像とアーキテクチャを短時間で把握できるようにまとめたものです。主な目的は「どのレイヤーに何が置かれているか」「どのように BLE や AI 機能と連携しているか」を理解することです。

## 1. アプリの全体像（ざっくり構成）

### エントリポイントと初期化
- `lib/main.dart` がアプリのエントリポイントです。起動時に `BleManager` を初期化し、GetX の `EvenaiModelController` を DI した上で `MyApp` を起動します。UI のルートは `HomePage` です。【F:lib/main.dart†L1-L27】
- `lib/app.dart` にはアプリ全体で共有する `App` シングルトンがあり、BLE から「終了通知」を受けた際に EvenAI 機能を停止させる役割を持っています。【F:lib/app.dart†L1-L15】

### 画面（Views）
- `HomePage` は BLE の接続状態を表示し、スキャンや接続、AI の画面遷移の入口になっています。BLE 接続状態の変化を `BleManager` から受け取り、UI を再描画します。【F:lib/views/home_page.dart†L21-L200】

### 状態管理（Controllers）
- EvenAI の Q&A 履歴は `EvenaiModelController` が GetX の `Rx` で管理します。履歴の追加・削除・選択などを集中管理して UI へ反映します。【F:lib/controllers/evenai_model_controller.dart†L1-L35】

### サービス（Services）
- BLE 通信の低レイヤは `BleManager` が担当します。MethodChannel でネイティブ BLE を呼び出し、EventChannel で受信イベントを購読します。【F:lib/ble_manager.dart†L1-L67】
- G2 向けのプロトコル実装は `Proto`（従来の EvenAI 向け BLE コマンド）と `G2TextService`（テレプロンプター向けの文字送信）に分かれています。【F:lib/services/proto.dart†L1-L120】【F:lib/services/g2_text_service.dart†L1-L200】
- EvenAI の録音開始・音声認識イベントの受信・API への問い合わせ・グラスへの返信送信は `EvenAI` サービスが担います。【F:lib/services/evenai.dart†L1-L200】

## 2. BLE と UI のデータフロー

以下は「アプリ起動〜G2 に接続してテキスト送信をする」までの代表的な流れです。

1. **起動**
   - `main.dart` で `BleManager.get()` が呼ばれ、BLE のイベントチャネルが初期化されます。【F:lib/main.dart†L1-L18】【F:lib/ble_manager.dart†L12-L67】
2. **スキャン/接続**
   - `HomePage` の UI から `BleManager.startScan()` / `connectToGlasses()` を呼び出し、ネイティブ BLE を起動します。【F:lib/views/home_page.dart†L36-L115】【F:lib/ble_manager.dart†L40-L76】
3. **BLE 受信イベント**
   - `BleManager` の `EventChannel` がイベントを受け取り、接続状態の更新や EvenAI の開始指示などを処理します。【F:lib/ble_manager.dart†L27-L176】
4. **EvenAI の開始/終了**
   - 受信イベントが「EvenAI 開始」または「録音終了」の場合、`EvenAI` サービスが録音や API 呼び出し、返信送信を制御します。【F:lib/ble_manager.dart†L132-L176】【F:lib/services/evenai.dart†L54-L200】
5. **テキスト送信**
   - G2 向けのテキスト送信は `G2TextService` が専用のプロトコルでパケットを生成して両眼に送ります。【F:lib/services/g2_text_service.dart†L1-L200】

## 3. フォルダ構成ガイド

```
lib/
  controllers/   # 状態管理（GetX）
  models/        # データモデル
  services/      # BLE/AI/プロトコルなどのビジネスロジック
  utils/         # 共通ユーティリティ
  views/         # 画面（UI）
```

- 上記構成は `HomePage` や `EvenaiModelController` などの実装から読み取れる責務分離に沿っています。【F:lib/views/home_page.dart†L1-L200】【F:lib/controllers/evenai_model_controller.dart†L1-L35】

## 4. 主要な責務まとめ

| レイヤー | 主なファイル | 役割 |
| --- | --- | --- |
| UI | `lib/views/home_page.dart` | BLE 接続・画面遷移の入口 |【F:lib/views/home_page.dart†L21-L200】|
| 状態管理 | `lib/controllers/evenai_model_controller.dart` | EvenAI Q&A 履歴を管理 |【F:lib/controllers/evenai_model_controller.dart†L1-L35】|
| BLE 管理 | `lib/ble_manager.dart` | MethodChannel / EventChannel 経由で BLE を制御 |【F:lib/ble_manager.dart†L1-L176】|
| EvenAI | `lib/services/evenai.dart` | 録音・認識・API 呼び出し・テキスト送信 |【F:lib/services/evenai.dart†L1-L200】|
| プロトコル | `lib/services/proto.dart`, `lib/services/g2_text_service.dart` | BLE コマンドや G2 テキスト転送 |【F:lib/services/proto.dart†L1-L120】【F:lib/services/g2_text_service.dart†L1-L200】|

## 5. 開発を始めるときの最小手順

> 詳細は `README.md` を参照してください。

1. 依存関係の取得
   ```bash
   flutter pub get
   ```
2. 実機を接続して起動
   ```bash
   flutter run
   ```

上記コマンドは README に記載の手順と同じです。【F:README.md†L13-L49】

## 6. 新しく触るときの理解ポイント

- BLE を経由したイベントは `BleManager` で一元処理されています。イベント種別によって `EvenAI` の起動・ページ送りなどを制御するため、BLE イベント追加時はここを最初に読むと全体像が掴めます。【F:lib/ble_manager.dart†L120-L176】
- EvenAI の処理は「音声認識イベント受信 → API への問い合わせ → 結果をテキスト送信」という流れです。`EvenAI.recordOverByOS()` の中に処理が集約されています。【F:lib/services/evenai.dart†L108-L186】
- G2 へのテキスト転送は `G2TextService` に閉じ込められているため、新しい UI から送信したい場合は `G2TextService.instance.sendText()` を呼ぶ設計になっています。【F:lib/services/g2_text_service.dart†L17-L120】

---

必要に応じて、BLE のプロトコル詳細やネイティブ側の実装（Android/iOS のプラットフォームコード）も別ドキュメントとして追加していくと理解がさらに深まります。
