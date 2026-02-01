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

## 7. Flutter 初心者向けドキュメント（最小キャッチアップ）

### Flutter アプリの基本構造
- Flutter は「Widget のツリー」で UI を組み立てます。本アプリでも `MaterialApp` の `home` に `HomePage` を指定し、そこから画面が始まります。【F:lib/main.dart†L14-L27】
- 画面は `StatefulWidget` / `StatelessWidget` で構築され、`HomePage` は状態を持つ `StatefulWidget` です。【F:lib/views/home_page.dart†L12-L24】

### 依存関係の管理
- 依存関係は `pubspec.yaml` で管理します。GetX (`get`)、ネットワーク (`dio`) などもここで宣言されています。【F:pubspec.yaml†L19-L56】
- 画像などのアセットは `flutter.assets` で登録されています。【F:pubspec.yaml†L69-L76】

### 開発時の基本コマンド
- `flutter pub get` で依存関係を取得し、`flutter run` で実機/エミュレータへ起動します。【F:README.md†L13-L49】

### 状態管理の入口
- 本アプリは GetX を使っており、`EvenaiModelController` を `Get.put()` で注入してから使う構造です。【F:lib/main.dart†L8-L18】【F:lib/controllers/evenai_model_controller.dart†L1-L35】

## 8. Flutter アプリとしての全体像

Flutter 側は「UI 層」「状態管理」「サービス（BLE/AI）」の三層を意識して読むと理解が早いです。

- **UI 層**: `HomePage` が BLE 接続・機能画面への入口です。BLE のステータスを表示し、接続後は AI の履歴画面へ遷移します。【F:lib/views/home_page.dart†L21-L200】
- **状態管理**: EvenAI の履歴は `EvenaiModelController` が `Rx` で管理し、UI に即時反映します。【F:lib/controllers/evenai_model_controller.dart†L1-L35】
- **サービス層**: `BleManager` が BLE の送受信を抽象化し、`EvenAI` が録音〜回答送信までを制御します。【F:lib/ble_manager.dart†L1-L176】【F:lib/services/evenai.dart†L54-L200】

この構造は「UI → サービス → BLE/ネイティブ」へと責務が流れる設計になっています。【F:lib/views/home_page.dart†L21-L200】【F:lib/ble_manager.dart†L27-L176】

## 9. BLE のプロトコル詳細（Flutter 側）

### G2 プロトコル（テキスト転送）
- `G2Protocol` は G2 用のパケットフォーマット（ヘッダー/CRC/varint）を生成します。`buildPacket` が「ヘッダー + payload + CRC」を組み立てます。【F:lib/services/g2_protocol.dart†L1-L86】
- 認証は 7 パケットのシーケンスで、`buildAuthPackets()` が固定ペイロードの連続送信を行います。【F:lib/services/g2_protocol.dart†L88-L168】
- テキスト送信は `G2TextService` で実行され、**認証 → 表示設定 → テレプロンプタ初期化 → ページ送信 → 同期トリガー**の順で送信されます。【F:lib/services/g2_text_service.dart†L17-L190】

### EvenAI 向けプロトコル
- `Proto.sendEvenAIData()` は EvenAI の返信を BLE で送信するロジックで、`EvenaiProto` による分割パケット送信を行います。【F:lib/services/proto.dart†L28-L82】
- `Proto.sendHeartBeat()` は左右デバイスへ定期的な heartbeat を送り、接続維持を担います。【F:lib/services/proto.dart†L84-L131】

### BLE リクエストの統合入口
- BLE 送信は `BleManager.request()` / `requestList()` が窓口です。左右デバイスへの送信やタイムアウト管理をここで行っています。【F:lib/ble_manager.dart†L200-L360】

## 10. ネイティブ側の実装（Android/iOS）

### Android 側（Kotlin）
- MethodChannel / EventChannel の初期化は `BleChannelHelper.initChannel()` で行い、Flutter ↔ Android の双方向通信を構成します。【F:android/app/src/main/kotlin/com/example/demo_ai_even/bluetooth/BleChannelHelper.kt†L15-L57】
- `BleMethodChannel` が Flutter からの `startScan` / `connectToGlasses` / `send` などを受け取り、`BleManager` に委譲します。【F:android/app/src/main/kotlin/com/example/demo_ai_even/bluetooth/BleChannelHelper.kt†L69-L119】
- `BleManager` は G2 の BLE UUID を定義し、スキャン→ペアリング→接続→書き込みを行います。【F:android/app/src/main/kotlin/com/example/demo_ai_even/bluetooth/BleManager.kt†L26-L154】

### iOS 側（Swift）
- `AppDelegate` で `FlutterMethodChannel` を作成し、`startScan` / `connectToGlasses` / `send` などのメソッドを `BluetoothManager` に委譲します。【F:ios/Runner/AppDelegate.swift†L12-L63】
- `BluetoothManager` は `CBCentralManager` を使ってスキャン/接続を行い、左右デバイスが揃うと Flutter に `foundPairedGlasses` を通知します。【F:ios/Runner/BluetoothManager.swift†L28-L121】
- G2 の BLE UUID 定義は `ServiceIdentifiers` に集約されています。【F:ios/Runner/ServiceIdentifiers.swift†L9-L18】

---

必要に応じて、BLE のプロトコル詳細やネイティブ側の実装（Android/iOS のプラットフォームコード）は本ドキュメントに追記しつつ、チーム内で更新し続けると理解がさらに深まります。
